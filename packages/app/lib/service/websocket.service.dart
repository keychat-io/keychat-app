import 'dart:async';
import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat/constants.dart';
import 'package:keychat/models/db_provider.dart';
import 'package:keychat/models/embedded/cashu_info.dart';
import 'package:keychat/models/embedded/relay_file_fee.dart';
import 'package:keychat/models/embedded/relay_message_fee.dart';
import 'package:keychat/models/nostr_event_status.dart';
import 'package:keychat/models/relay.dart';
import 'package:keychat/nostr-core/nostr.dart';
import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat/nostr-core/nostr_nip4_req.dart';
import 'package:keychat/nostr-core/relay_websocket.dart';
import 'package:keychat/nostr-core/subscribe_result.dart';
import 'package:keychat/service/message_retry.service.dart';
import 'package:keychat/service/relay.service.dart';
import 'package:keychat/service/storage.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:web_socket_client/web_socket_client.dart';

class WebsocketService extends GetxService {
  WebsocketService(List<Relay> relays) {
    logger.i('start init websocket service');
    mainRelayStatus.value = RelayStatusEnum.connecting.name;
    unawaited(start(relays));
    final activeCount = relays.where((element) => element.active).length;
    if (activeCount == 0) {
      mainRelayStatus.value = RelayStatusEnum.noAcitveRelay.name;
    }
  }

  NostrAPI nostrAPI = NostrAPI.instance;
  RxString mainRelayStatus = RelayStatusEnum.init.name.obs;
  RxInt relayConnectedCount = 0.obs;
  RxMap<String, RelayWebsocket> channels = <String, RelayWebsocket>{}.obs;
  RxMap<String, RelayMessageFee> relayMessageFeeModels =
      <String, RelayMessageFee>{}.obs;
  Map<String, RelayFileFee> relayFileFeeModels = {};

  DateTime initAt = DateTime.now();

  bool startLock = false;

  int activitySocketCount() {
    return channels.values.where((element) => element.isConnected()).length;
  }

  RelayFileFee? getRelayFileFeeModel(String url) {
    final uri = Uri.parse(url);
    return relayFileFeeModels[uri.host];
  }

  void setRelayFileFeeModel(String url, RelayFileFee fuc) {
    final uri = Uri.parse(url);
    relayFileFeeModels[uri.host] = fuc;
  }

  Future<NostrEventStatus> addCashuToMessage(
    int roomId,
    NostrEventStatus eventSendStatus,
    int totalBalanceSat,
  ) async {
    final payInfoModel = relayMessageFeeModels[eventSendStatus.relay];
    if (payInfoModel == null) return eventSendStatus;
    if (payInfoModel.amount == 0) return eventSendStatus;
    if (totalBalanceSat == 0) {
      throw Exception(ErrorMessages.noFunds);
    }
    CashuInfoModel? cashuA;
    try {
      cashuA = await EcashUtils.getStamp(
        amount: payInfoModel.amount,
        token: payInfoModel.unit.name,
        mints: payInfoModel.mints,
      );
      eventSendStatus
        ..ecashName = payInfoModel.unit.name
        ..ecashAmount = payInfoModel.amount.toDouble()
        ..ecashToken = cashuA.token
        ..ecashMint = cashuA.mint;
    } catch (e) {
      final msg = Utils.getErrorMessage(e);
      if (msg.startsWith('Insufficant')) throw Exception(ErrorMessages.noFunds);
      loggerNoLine.e('${eventSendStatus.relay} getStamp failed: $msg');
      throw Exception(msg);
    }
    var message = eventSendStatus.rawEvent!;
    message = message.substring(0, message.length - 1);
    message += ',"${cashuA.token}"]';
    eventSendStatus.rawEvent = message;
    return eventSendStatus;
  }

  // new a websocket channel for this relay
  Future<void> addChannel(Relay relay, {Function? connectedCallback}) async {
    final ws = this;
    final rw = RelayWebsocket(relay, ws);
    channels[relay.url] = rw;
    if (!relay.active) {
      return;
    }

    await _startConnectRelay(
      rw,
      connectedCallback: () async {
        logger.i('relay: ${relay.url} connected, callback');
        if (connectedCallback != null) {
          connectedCallback();
        }
      },
    );
  }

  Future<void> checkOnlineAndConnect({
    List<RelayWebsocket>? list,
    bool forceReconnect = false,
  }) async {
    initAt = DateTime.now();
    await refreshMainRelayStatus();
    // fix ConcurrentModificationError List.from([list??channels.values])
    await Future.wait(
      (list ?? channels.values).map((rw) async {
        logger.i(
          'checkOnlineAndConnect: ${rw.relay.url}, forceReconnect: $forceReconnect',
        );
        if (!rw.relay.active) return;
        if (forceReconnect) {
          rw.channel?.close();
          await _startConnectRelay(rw);
          return;
        }
        final relayStatus = await rw.checkOnlineStatus();
        if (!relayStatus) {
          rw.channel?.close();
          await _startConnectRelay(rw);
        }
      }),
    );
  }

  Future<void> createChannels([List<Relay> list = const []]) async {
    final ws = this;
    await Future.wait(
      list.map((Relay relay) async {
        final rw = RelayWebsocket(relay, ws);
        channels[relay.url] = rw;
        await _startConnectRelay(rw);
      }),
    );
  }

  Future<void> disableRelay(Relay relay) async {
    relay.active = false;
    relay.errorMessage = null;
    await RelayService.instance.update(relay);
    if (channels[relay.url] != null) {
      channels[relay.url]!.channel?.close();
      channels[relay.url]!.relay = relay;
      channels.refresh();
    }
  }

  bool existFreeRelay() {
    for (final channel in channels.entries) {
      if (channel.value.isConnected()) {
        if (relayMessageFeeModels[channel.key]?.amount == 0) {
          return true;
        }
      }
    }
    return false;
  }

  // fetch info and wait for response data
  Future<List<NostrEventModel>> fetchInfoFromRelay(
    String subId,
    String eventString, {
    Duration wait = const Duration(seconds: 2),
    bool waitTimeToFill = false,
    List<RelayWebsocket>? sockets,
  }) async {
    sockets ??= getOnlineSocket();
    if (sockets.isEmpty) {
      logger.i('Not connected, or the relay not support nips');
      return [];
    }
    for (final rw in sockets) {
      rw.sendRawREQ(eventString);
    }
    return SubscribeResult.instance.registerSubscripton(
      subId,
      sockets.length,
      wait: wait,
      waitTimeToFill: waitTimeToFill,
    );
  }

  List<String> getActiveRelayString() {
    final res = <String>{};
    for (final rw in List<RelayWebsocket>.from(channels.values)) {
      if (rw.relay.active) {
        res.add(rw.relay.url);
      }
    }
    return res.toList();
  }

  Color getColorByState(ConnectionState? state) {
    switch (state) {
      case Connecting _:
      case Reconnecting _:
        return Colors.yellow;
      case Connected _:
      case Reconnected _:
        return Colors.green;
      case Disconnected _:
      case Disconnecting _:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<RelayWebsocket> getOnlineSocket() {
    return channels.values.where((element) => element.isConnected()).toList();
  }

  List<String> getOnlineSocketString() {
    final res = <String>[];
    for (final rw in List.from(channels.values)) {
      if (rw.channel != null && rw.isConnected() == true) {
        res.add(rw.relay.url);
      }
    }
    return res;
  }

  EventSendEnum getSendStatusByState(ConnectionState? state) {
    if (state == null) {
      return EventSendEnum.noAcitveRelay;
    }
    switch (state) {
      case Connecting _:
      case Reconnecting _:
        return EventSendEnum.relayConnecting;
      case Connected _:
      case Reconnected _:
        return EventSendEnum.success;
      case Disconnected _:
      case Disconnecting _:
        return EventSendEnum.relayDisconnected;
    }
  }

  void listenPubkey(
    List<String> pubkeys, {
    required List<int> kinds,
    DateTime? since,
    List<String>? relays,
    int? limit,
  }) {
    if (pubkeys.isEmpty) return;

    since ??= DateTime.now().subtract(const Duration(days: 7));
    final subId = generate64RandomHexChars(16);

    final req = NostrReqModel(
      reqId: subId,
      pubkeys: pubkeys,
      since: since,
      limit: limit,
      kinds: kinds,
    );
    try {
      sendReq(req, relays: relays);
    } catch (e) {
      if (e.toString().contains('RelayDisconnected')) {
        EasyLoading.showToast('Disconnected, Please check your relay server');
        return;
      }
      logger.e('error: $e');
    }
  }

  NostrReqModel? listenPubkeyNip17(
    List<String> pubkeys, {
    DateTime? since,
    List<String>? relays,
    int? limit,
  }) {
    if (pubkeys.isEmpty) return null;

    since ??= DateTime.now().subtract(const Duration(days: 2));
    final subId = generate64RandomHexChars(16);

    final req = NostrReqModel(
      reqId: subId,
      pubkeys: pubkeys,
      since: since,
      limit: limit,
      kinds: [EventKinds.nip17],
    );
    try {
      sendReq(req, relays: relays);
    } catch (e) {
      if (e.toString().contains('RelayDisconnected')) {
        EasyLoading.showToast('Disconnected, Please check your relay server');
      }
      logger.e('error: $e');
    }
    return req;
  }

  Future<void> localFeesConfigFromLocalStorage() async {
    final map1 = await Storage.getLocalStorageMap(
      StorageKeyString.relayMessageFeeConfig,
    );
    for (final entry in map1.entries) {
      if (entry.value is Map && (entry.value as Map).isNotEmpty) {
        var host = entry.key as String;
        if (host.startsWith('wss://')) {
          final uri = Uri.parse(host);
          host = uri.host;
        }
        relayMessageFeeModels[host] = RelayMessageFee.fromJson(entry.value);
      }
    }

    final map2 = await Storage.getLocalStorageMap(
      StorageKeyString.relayFileFeeConfig,
    );
    for (final entry in map2.entries) {
      if (entry.value is Map && (entry.value as Map).isNotEmpty) {
        var host = entry.key as String;
        if (host.startsWith('wss://')) {
          final uri = Uri.parse(host);
          host = uri.host;
        }
        relayFileFeeModels[host] = RelayFileFee.fromJson(entry.value);
      }
    }
  }

  @override
  void onReady() {
    super.onReady();
    localFeesConfigFromLocalStorage();
    RelayService.instance.initRelayFeeInfo();
  }

  Future<void> refreshMainRelayStatus() async {
    final success = getOnlineSocket().length;
    relayConnectedCount.value = success;
    if (success > 0) {
      return _setMainRelayStatus(RelayStatusEnum.connected);
    }

    if (success == 0) {
      final diff =
          DateTime.now().millisecondsSinceEpoch - initAt.millisecondsSinceEpoch;
      if (diff > 4000) {
        return _setMainRelayStatus(RelayStatusEnum.allFailed);
      }
    }
    await _setMainRelayStatus(RelayStatusEnum.connecting);
  }

  void removePubkeyFromSubscription(String pubkey) {
    for (final rw in channels.values) {
      final subs = rw.subscriptions;
      for (final entry in subs.entries) {
        if (entry.value.contains(pubkey)) {
          subs[entry.key]?.remove(pubkey);
        }
      }
    }
  }

  void removePubkeysFromSubscription(List<String> keys) {
    for (final rw in channels.values) {
      final subs = rw.subscriptions;
      for (final entry in subs.entries) {
        subs[entry.key]?.removeAll(keys);
        break;
      }
    }
  }

  String? getSubscriptionIdsByPubkey(String pubkey) {
    for (final rw in List<RelayWebsocket>.from(channels.values)) {
      final subs = rw.subscriptions;
      for (final entry in subs.entries) {
        if (entry.value.contains(pubkey)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  int sendReqToRelays(String content, [List<String>? relays]) {
    final targetRelays = _getTargetRelaysForSending(relays);
    var sent = 0;

    for (final relay in targetRelays) {
      final rw = channels[relay];
      if (rw != null && rw.isConnected() && rw.channel != null) {
        rw.sendRawREQ(content);
        sent++;
      }
    }

    if (sent == 0) {
      throw Exception(
        'Not connected any relay server, please check your network',
      );
    }

    return sent;
  }

  Iterable<String> _getTargetRelaysForSending(List<String>? relays) {
    if (relays != null && relays.isNotEmpty) {
      return relays.where((relay) => channels[relay] != null);
    }
    return channels.keys.where((relay) {
      final rw = channels[relay];
      return rw != null && !rw.isConnecting() && !rw.isDisConnected();
    });
  }

  void sendMessageWithCallback(
    String content, {
    List<String>? relays,
    void Function({
      required String relay,
      required String eventId,
      required bool status,
      String? errorMessage,
    })?
    callback,
  }) {
    if (callback != null) {
      try {
        final list = jsonDecode(content) as List<dynamic>;
        if (list.length > 1 && list[1] != null) {
          NostrAPI.instance.setOKCallback(list[1]['id'], callback);
        }
        // ignore: empty_catches
      } catch (e) {}
    }
    if (relays != null && relays.isNotEmpty) {
      var sent = 0;
      for (final relay in relays) {
        if (channels[relay] != null &&
            channels[relay]!.isConnected() &&
            channels[relay]!.channel != null) {
          channels[relay]!.sendRawREQ(content);
          sent++;
        }
      }
      if (sent > 0) return;
    }

    var sent = 0;
    for (final rw in channels.values) {
      if (rw.isConnecting() || rw.isDisConnected()) {
        continue;
      }
      sent++;
      rw.sendRawREQ(content);
    }
    if (sent == 0) {
      throw Exception(
        'Not connected any relay server, please check your network',
      );
    }
  }

  void sendReq(
    NostrReqModel nostrReq, {
    List<String>? relays,
    void Function(String relay)? callback,
  }) {
    if (relays != null && relays.isNotEmpty) {
      var sent = 0;
      for (final relayUrl in relays) {
        if (channels[relayUrl] != null && channels[relayUrl]!.isConnected()) {
          try {
            channels[relayUrl]!.sendREQ(nostrReq);
            sent++;
            if (callback != null) {
              callback(relayUrl);
            }
          } catch (e) {
            logger.e(e.toString());
          }
        }
      }
      if (sent > 0) return;
    }

    var sent = 0;
    for (final rw in channels.values) {
      if (rw.isDisConnected() || rw.isConnecting()) {
        continue;
      }
      try {
        rw.sendREQ(nostrReq);
        sent++;
        if (callback != null) {
          callback(rw.relay.url);
        }
      } catch (e) {
        logger.e(e.toString());
      }
    }
    if (sent == 0) throw Exception('RelayDisconnected');
  }

  Future<void> _setMainRelayStatus(RelayStatusEnum status) async {
    if (mainRelayStatus.value != status.name) {
      mainRelayStatus.value = status.name;
      loggerNoLine.d('setMainRelayStatus: ${mainRelayStatus.value}');
      channels.refresh();
    }
  }

  Future<void> start([List<Relay>? list]) async {
    if (startLock) return;
    try {
      startLock = true;
      NostrAPI.instance.handledEventIds.clear();
      NostrAPI.instance.subscriptionIdEose.clear();
      NostrAPI.instance.subscriptionLastEvent.clear();
      initAt = DateTime.now();
      await stopListening();
      list ??= await RelayService.instance.list();
      await createChannels(list);
    } finally {
      startLock = false;
    }
  }

  Future<void> stopListening() async {
    for (final rw in channels.values) {
      rw.channel?.close();
    }
    channels.clear();
  }

  Future<Set<String>> writeNostrEvent({
    required NostrEventModel event,
    required String eventString,
    required int roomId,
    List<String> toRelays = const [],
  }) async {
    final targetRelays = _getTargetRelays(toRelays);
    if (targetRelays.isEmpty) {
      if (toRelays.isNotEmpty) {
        throw Exception('${toRelays.join(',')} not connected');
      }
      throw Exception('No active relay');
    }
    final connectedRelays = targetRelays.where((relay) {
      final rw = channels[relay];
      return rw != null && rw.isConnected();
    }).toList();
    if (connectedRelays.isEmpty) {
      throw Exception('No connected relay');
    }

    unawaited(
      _proccessWriteNostrEvent(
        event,
        eventString,
        connectedRelays,
        roomId,
      ),
    );

    return connectedRelays.toSet();
  }

  Future<void> _proccessWriteNostrEvent(
    NostrEventModel event,
    String eventString,
    List<String> targetRelays,
    int roomId,
  ) async {
    final rawEvent = '["EVENT",$eventString]';
    final totalBalanceSat = Get.find<EcashController>().totalSats.value;

    // Process all relays concurrently
    await Future.wait(
      targetRelays.map((relay) async {
        final rw = channels[relay];
        if (rw == null) return;

        var ess = NostrEventStatus(
          relay: rw.relay.url,
          eventId: event.id,
          roomId: roomId,
          sendStatus: EventSendEnum.init,
        )..rawEvent = rawEvent;

        if (rw.channel == null || !rw.relay.active) {
          ess.sendStatus = EventSendEnum.noAcitveRelay;
          await _saveEventStatusToDB(ess);
          return;
        }
        // not connected
        if (!rw.isConnected()) {
          ess.sendStatus = getSendStatusByState(rw.channel?.connection.state);
          await _saveEventStatusToDB(ess);
          return;
        }

        try {
          ess = await addCashuToMessage(roomId, ess, totalBalanceSat);
        } catch (e) {
          ess
            ..sendStatus = EventSendEnum.cashuError
            ..error = e.toString();
          await _saveEventStatusToDB(ess);
          return;
        }
        try {
          rw.channel!.send(ess.rawEvent);

          // Add to retry queue
          MessageRetryService.instance.addMessage(
            eventId: event.id,
            relay: relay,
            rawEvent: ess.rawEvent!,
            roomId: roomId,
          );
        } catch (e) {
          ess
            ..sendStatus = EventSendEnum.relayDisconnected
            ..error = e.toString();
        }
        await _saveEventStatusToDB(ess);
      }),
    );
  }

  Future<void> _saveEventStatusToDB(NostrEventStatus item) async {
    await DBProvider.database.writeTxn(() async {
      final id = await DBProvider.database.nostrEventStatus.put(item);
      item.id = id;
    });
    MessageRetryService.instance.addNostrEventStatus(item);
  }

  Set<String> _getTargetRelays(List<String> toRelays) {
    final activeRelays = getActiveRelayString();
    if (activeRelays.isEmpty) {
      throw Exception('No active relay');
    }
    if (toRelays.isEmpty) return Set.from(activeRelays);
    return activeRelays.where((element) => toRelays.contains(element)).toSet();
  }

  Future<RelayWebsocket> _startConnectRelay(
    RelayWebsocket rw, {
    Function? connectedCallback,
  }) async {
    if (!rw.relay.active) {
      return rw;
    }

    loggerNoLine.i('start connect ${rw.relay.url}');

    rw.channel = WebSocket(
      Uri.parse(rw.relay.url),
      pingInterval: const Duration(seconds: 10),
      timeout: const Duration(seconds: 8),
      backoff: LinearBackoff(
        initial: const Duration(),
        increment: const Duration(seconds: 2),
        maximum: const Duration(seconds: 16),
      ),
    );

    rw.channel!.messages.listen((message) {
      nostrAPI.addNostrEventToQueue(rw.relay, message);
    });
    rw.channel!.connection.listen((ConnectionState state) {
      if (state is Connected || state is Reconnected) {
        rw.connectSuccess();
        if (connectedCallback != null) {
          connectedCallback();
        }
        // Retry pending messages for this relay
        unawaited(
          MessageRetryService.instance.retryPendingMessages(rw.relay.url),
        );
      }

      // update the main page status
      unawaited(refreshMainRelayStatus());
    });

    return rw;
  }

  void updateRelayPong(String relay) {
    if (channels[relay] != null) {
      channels[relay]!.pong = true;
    }
  }

  Future<void> reinit() async {
    final relays = await RelayService.instance.initRelay();
    logger.i('start init websocket service');
    mainRelayStatus.value = RelayStatusEnum.connecting.name;
    unawaited(start(relays));
    final activeCount = relays.where((element) => element.active).length;
    if (activeCount == 0) {
      mainRelayStatus.value = RelayStatusEnum.noAcitveRelay.name;
    }
  }
}
