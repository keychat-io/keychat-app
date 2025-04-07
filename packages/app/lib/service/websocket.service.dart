import 'dart:convert' show jsonDecode;

import 'package:app/constants.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/embedded/cashu_info.dart';
import 'package:app/models/embedded/relay_file_fee.dart';
import 'package:app/models/embedded/relay_message_fee.dart';
import 'package:app/models/nostr_event_status.dart';
import 'package:app/models/relay.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/nostr-core/nostr_nip4_req.dart';
import 'package:app/nostr-core/relay_websocket.dart';
import 'package:app/nostr-core/subscribe_event_status.dart';
import 'package:app/nostr-core/subscribe_result.dart';
import 'package:app/page/setting/RelaySetting.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/cupertino.dart' hide ConnectionState;
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
import 'package:queue/queue.dart';
import 'package:web_socket_client/web_socket_client.dart';

class WebsocketService extends GetxService {
  RelayService rs = RelayService.instance;
  NostrAPI nostrAPI = NostrAPI.instance;
  RxString relayStatusInt = RelayStatusEnum.init.name.obs;
  final RxMap<String, RelayWebsocket> channels = <String, RelayWebsocket>{}.obs;
  final RxMap<String, RelayMessageFee> relayMessageFeeModels =
      <String, RelayMessageFee>{}.obs;
  Map<String, RelayFileFee> relayFileFeeModels = {};
  Map<String, Set<String>> failedEventsMap = {};

  DateTime initAt = DateTime.now();

  String? lastRelayStatus;

  bool startLock = false;

  int activitySocketCount() {
    return channels.values.where((element) => element.isConnected()).length;
  }

  Future<NostrEventStatus> addCashuToMessage(
      int roomId, NostrEventStatus eventSendStatus) async {
    RelayMessageFee? payInfoModel =
        relayMessageFeeModels[eventSendStatus.relay];
    if (payInfoModel == null) return eventSendStatus;
    if (payInfoModel.amount == 0) return eventSendStatus;
    CashuInfoModel? cashuA;
    try {
      cashuA = await CashuUtil.getStamp(
          amount: payInfoModel.amount,
          token: payInfoModel.unit.name,
          mints: payInfoModel.mints);
      eventSendStatus.ecashName = payInfoModel.unit.name;
      double amount = (payInfoModel.amount).toDouble();
      eventSendStatus.ecashAmount = amount;
      eventSendStatus.ecashToken = cashuA.token;
      eventSendStatus.ecashMint = cashuA.mint;
    } catch (e) {
      String msg = Utils.getErrorMessage(e);
      if (msg.startsWith('Insufficant')) throw Exception(ErrorMessages.noFunds);
      loggerNoLine.e('${eventSendStatus.relay} getStamp failed: $msg');
      throw Exception(msg);
    }
    String message = eventSendStatus.rawEvent!;
    message = message.substring(0, message.length - 1);
    message += ',"${cashuA.token}"]';
    eventSendStatus.rawEvent = message;
    return eventSendStatus;
  }

  // new a websocket channel for this relay
  Future addChannel(Relay relay, {Function? connectedCallback}) async {
    WebsocketService ws = this;
    RelayWebsocket rw = RelayWebsocket(relay, ws);
    channels[relay.url] = rw;
    if (!relay.active) {
      return;
    }

    await _startConnectRelay(rw, connectedCallback: () async {
      logger.d('relay: ${relay.url} connected, callback');
      if (connectedCallback != null) {
        connectedCallback();
      }
    });
  }

  addFaiedEvents(String relay, String raw) {
    if (failedEventsMap[relay] == null) {
      failedEventsMap[relay] = {};
    }
    failedEventsMap[relay]!.add(raw);
  }

  Future checkOnlineAndConnect([List<RelayWebsocket>? list]) async {
    initAt = DateTime.now();
    refreshMainRelayStatus();
    // fix ConcurrentModificationError List.from([list??channels.values])
    await Future.wait((list ?? channels.values).map((rw) async {
      if (rw.relay.active == false) return;
      bool relayStatus = await rw.checkOnlineStatus();
      if (!relayStatus) {
        rw.channel?.close();
        _startConnectRelay(rw);
      }
    }));
  }

  clearFailedEvents(String relay) {
    failedEventsMap.remove(relay);
  }

  Future createChannels([List<Relay> list = const []]) async {
    WebsocketService ws = this;
    await Future.wait(list.map((Relay relay) async {
      RelayWebsocket rw = RelayWebsocket(relay, ws);
      channels[relay.url] = rw;
      await _startConnectRelay(rw);
    }));
  }

  Future disableRelay(Relay relay) async {
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
    for (var channel in channels.entries) {
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
      String subId, String eventString,
      {Duration wait = const Duration(seconds: 2),
      bool waitTimeToFill = false,
      List<RelayWebsocket>? sockets}) async {
    sockets ??= getOnlineSocket();
    if (sockets.isEmpty) {
      logger.d('Not connected, or the relay not support nips');
      return [];
    }
    for (RelayWebsocket rw in sockets) {
      rw.sendRawREQ(eventString);
    }
    return await SubscribeResult.instance.registerSubscripton(
        subId, sockets.length,
        wait: wait, waitTimeToFill: waitTimeToFill);
  }

  List<String> getActiveRelayString() {
    List<String> res = [];
    for (RelayWebsocket rw in channels.values) {
      if (rw.relay.active) {
        res.add(rw.relay.url);
      }
    }
    return res;
  }

  getColorByState(ConnectionState? state) {
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

  Set<String> getFailedEvents(String relay) {
    return failedEventsMap[relay] ?? {};
  }

  List<RelayWebsocket> getOnlineSocket() {
    return channels.values.where((element) => element.isConnected()).toList();
  }

  List<String> getOnlineSocketString() {
    List<String> res = [];
    for (RelayWebsocket rw in channels.values) {
      if (rw.channel != null && rw.isConnected()) {
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
      default:
        return EventSendEnum.init;
    }
  }

  Future<WebsocketService> init() async {
    logger.d('start init websocket service');
    relayStatusInt.value = RelayStatusEnum.connecting.name;
    List<Relay> list = await rs.initRelay();
    start(list);
    int activeCount = list.where((element) => element.active).length;
    if (activeCount == 0) {
      relayStatusInt.value = RelayStatusEnum.noAcitveRelay.name;
    }
    return this;
  }

  listenPubkey(List<String> pubkeys,
      {DateTime? since, String? relay, int? limit, required List<int> kinds}) {
    if (pubkeys.isEmpty) return;

    since ??= DateTime.now().subtract(const Duration(days: 7));
    String subId = generate64RandomHexChars(16);

    NostrReqModel req = NostrReqModel(
        reqId: subId,
        pubkeys: pubkeys,
        since: since,
        limit: limit,
        kinds: kinds);
    try {
      sendReq(req, relay: relay);
    } catch (e) {
      if (e.toString().contains('RelayDisconnected')) {
        EasyLoading.showToast('Disconnected, Please check your relay server');
        return;
      }
      logger.e('listenPubkey error: $e');
    }
  }

  listenPubkeyNip17(List<String> pubkeys,
      {DateTime? since, String? relay, int? limit}) async {
    if (pubkeys.isEmpty) return;

    since ??= DateTime.now().subtract(const Duration(days: 2));
    String subId = generate64RandomHexChars(16);

    NostrReqModel req = NostrReqModel(
        reqId: subId,
        pubkeys: pubkeys,
        since: since,
        limit: limit,
        kinds: [EventKinds.nip17]);

    Get.find<WebsocketService>().sendReq(req, relay: relay);
  }

  Future localFeesConfigFromLocalStorage() async {
    Map map1 = await Storage.getLocalStorageMap(
        StorageKeyString.relayMessageFeeConfig);
    for (var entry in map1.entries) {
      if (entry.value.keys.length > 0) {
        relayMessageFeeModels[entry.key] =
            RelayMessageFee.fromJson(entry.value);
      }
    }

    Map map2 =
        await Storage.getLocalStorageMap(StorageKeyString.relayFileFeeConfig);
    for (var entry in map2.entries) {
      if (entry.value.keys.length > 0) {
        relayFileFeeModels[entry.key] = RelayFileFee.fromJson(entry.value);
      }
    }
  }

  @override
  void onReady() {
    super.onReady();
    localFeesConfigFromLocalStorage();
    RelayService.instance.initRelayFeeInfo();
  }

  refreshMainRelayStatus() async {
    int success = getOnlineSocket().length;
    loggerNoLine.d('refreshMainRelayStatus, online: $success');
    if (success > 0) {
      return await setRelayStatusInt(RelayStatusEnum.connected.name);
    }

    if (success == 0) {
      int diff =
          DateTime.now().millisecondsSinceEpoch - initAt.millisecondsSinceEpoch;
      if (diff > 4000) {
        return await setRelayStatusInt(RelayStatusEnum.allFailed.name);
      }
    }
    await setRelayStatusInt(RelayStatusEnum.connecting.name);
  }

  removePubkeyFromSubscription(String pubkey) {
    for (RelayWebsocket rw in channels.values) {
      for (var entry in rw.subscriptions.entries) {
        if (entry.value.contains(pubkey)) {
          rw.subscriptions[entry.key]?.remove(pubkey);
        }
      }
    }
  }

  removePubkeysFromSubscription(List<String> keys) {
    for (RelayWebsocket rw in channels.values) {
      for (var entry in rw.subscriptions.entries) {
        rw.subscriptions[entry.key]?.removeAll(keys);
        break;
      }
    }
  }

  int sendMessage(String content, [List<String>? relays]) {
    if (relays != null && relays.isNotEmpty) {
      int sent = 0;
      for (String relay in relays) {
        if (channels[relay] != null &&
            channels[relay]!.isConnected() &&
            channels[relay]!.channel != null) {
          channels[relay]!.sendRawREQ(content);
          sent++;
        }
      }
      if (sent > 0) return sent;
    }

    int sent = 0;
    for (RelayWebsocket rw in channels.values) {
      if (rw.isConnecting() || rw.isDisConnected()) {
        continue;
      }
      sent++;
      rw.sendRawREQ(content);
    }
    if (sent == 0) {
      throw Exception(
          'Not connected any relay server, please check your network');
    }

    return sent;
  }

  /// * content: nostr event model json string
  sendMessageWithCallback(String content,
      {List<String>? relays,
      Function(
              {required String relay,
              required String eventId,
              required bool status,
              String? errorMessage})?
          callback}) {
    if (callback != null) {
      try {
        var map = jsonDecode(content);
        if (map['id'] != null) {
          NostrAPI.instance.setOKCallback(map['id'], callback);
        }
        // ignore: empty_catches
      } catch (e) {}
    }
    if (relays != null && relays.isNotEmpty) {
      int sent = 0;
      for (String relay in relays) {
        if (channels[relay] != null &&
            channels[relay]!.isConnected() &&
            channels[relay]!.channel != null) {
          channels[relay]!.sendRawREQ("[\"EVENT\",$content]");
          sent++;
        }
      }
      if (sent > 0) return;
    }

    int sent = 0;
    for (RelayWebsocket rw in channels.values) {
      if (rw.isConnecting() || rw.isDisConnected()) {
        continue;
      }
      sent++;
      rw.sendRawREQ("[\"EVENT\",$content]");
    }
    if (sent == 0) {
      throw Exception(
          'Not connected any relay server, please check your network');
    }
  }

  sendRawReq(String msg) {
    List<RelayWebsocket> list = getOnlineSocket();

    for (RelayWebsocket rw in list) {
      rw.sendRawREQ(msg);
    }
  }

  sendReq(NostrReqModel nostrReq,
      {String? relay, Function(String relay)? callback}) {
    if (relay != null && channels[relay] != null) {
      return channels[relay]!.sendREQ(nostrReq);
    }
    int sent = 0;
    for (RelayWebsocket rw in channels.values) {
      if (rw.isDisConnected() || rw.isConnecting()) {
        continue;
      }
      sent++;
      rw.sendREQ(nostrReq);
      if (callback != null) {
        callback(rw.relay.url);
      }
    }
    if (sent == 0) throw Exception('RelayDisconnected');
  }

  Future setRelayStatusInt(String name) async {
    lastRelayStatus = name;
    EasyDebounce.debounce(
        'setRelayStatusInt', const Duration(milliseconds: 100), () {
      relayStatusInt.value = lastRelayStatus ?? name;
      channels.refresh();
    });
  }

  Future start([List<Relay>? list]) async {
    if (startLock) return;
    try {
      startLock = true;
      NostrAPI.instance.processedEventIds.clear();
      initAt = DateTime.now();
      SubscribeEventStatus.clear();
      await stopListening();
      list ??= await RelayService.instance.list();
      await createChannels(list);
    } finally {
      startLock = false;
    }
  }

  Future stopListening() async {
    for (RelayWebsocket rw in channels.values) {
      rw.channel?.close();
    }
    channels.clear();
  }

  Future<List<String>> writeNostrEvent(
      {required NostrEventModel event,
      required String eventString,
      required int roomId,
      List<String> toRelays = const []}) async {
    List<String> activeRelays = _getTargetRelays(toRelays);
    if (activeRelays.isEmpty) {
      if (toRelays.isNotEmpty) {
        throw Exception('${toRelays.join(',')} not connected');
      }
      throw Exception('No active relay');
    }
    SubscribeEventStatus.addSubscripton(event.id, activeRelays.length);

    String rawEvent = "[\"EVENT\",$eventString]";
    int success = 0;
    List<NostrEventStatus> results = [];
    Queue tasks = Queue(parallel: channels.keys.length);
    for (String relay in activeRelays) {
      RelayWebsocket? rw = channels[relay];
      if (rw == null) continue;

      tasks.add(() async {
        NostrEventStatus ess = NostrEventStatus(
            relay: rw.relay.url,
            eventId: event.id,
            roomId: roomId,
            sendStatus: EventSendEnum.init)
          ..rawEvent = rawEvent;

        if (rw.channel == null || rw.relay.active == false) {
          ess.sendStatus = EventSendEnum.noAcitveRelay;
          results.add(ess);
          return;
        }

        if (rw.isConnected()) {
          try {
            ess = await addCashuToMessage(roomId, ess);
          } catch (e) {
            ess.sendStatus = EventSendEnum.cashuError;
            ess.error = e.toString();
            results.add(ess);
            return;
          }
          try {
            rw.sendRawREQ(ess.rawEvent!, retry: true);
            success++;
            ess.sendStatus = EventSendEnum.success;
          } catch (e) {
            ess.sendStatus = EventSendEnum.relayDisconnected;
            ess.error = e.toString();
          }
          results.add(ess);
          return;
        }
        ess.sendStatus = getSendStatusByState(rw.channel?.connection.state);
        results.add(ess);
      });
    }

    tasks.onComplete.then((c) async {
      if (success == 0) {
        String messages = results
            .map((item) =>
                '${item.relay}: ${item.error ?? item.sendStatus.name}')
            .toList()
            .join('\n');
        if (Get.isDialogOpen != null && Get.isDialogOpen == false) {
          Get.dialog(CupertinoAlertDialog(
            title: const Text('Message Sent Failed'),
            content: Text(messages, textAlign: TextAlign.left),
            actions: <Widget>[
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () {
                  Get.back();
                },
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('Relay Server >'),
                onPressed: () {
                  Get.back();
                  Get.to(() => const RelaySetting());
                },
              ),
            ],
          ));
        }
      }
      // save send status to db
      await DBProvider.database.writeTxn(() async {
        for (NostrEventStatus item in results) {
          await DBProvider.database.nostrEventStatus.put(item);
        }
      });
    });
    return activeRelays;
  }

  List<String> _getTargetRelays(List<String> toRelays) {
    List<String> activeRelays = getActiveRelayString();
    if (activeRelays.isEmpty) {
      throw Exception('No active relay');
    }
    if (toRelays.isEmpty) return activeRelays;
    return activeRelays.where((element) => toRelays.contains(element)).toList();
  }

  Future<RelayWebsocket> _startConnectRelay(RelayWebsocket rw,
      {Function? connectedCallback}) async {
    if (rw.relay.active == false) {
      return rw;
    }

    loggerNoLine.i('start connect ${rw.relay.url}');

    rw.channel = WebSocket(Uri.parse(rw.relay.url),
        pingInterval: const Duration(seconds: 10),
        timeout: const Duration(seconds: 8),
        backoff: LinearBackoff(
          initial: Duration(seconds: 0),
          increment: Duration(seconds: 2),
          maximum: Duration(seconds: 16),
        ));

    rw.channel!.messages.listen((message) {
      nostrAPI.addNostrEventToQueue(rw.relay, message);
    });
    rw.channel!.connection.listen((ConnectionState state) {
      if (state is Connected || state is Reconnected) {
        rw.connectSuccess();
        if (connectedCallback != null) {
          connectedCallback();
        }
      }

      // update the main page status
      refreshMainRelayStatus();
    });

    return rw;
  }
}
