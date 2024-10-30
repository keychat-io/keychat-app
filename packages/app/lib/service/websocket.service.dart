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
import 'package:app/nostr-core/subscribe_event_status.dart';
import 'package:app/nostr-core/relay_websocket.dart';
import 'package:app/nostr-core/subscribe_result.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:queue/queue.dart';
import 'package:web_socket_channel/io.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/keychat_ecash.dart';

import '../utils.dart' as utils;

const int failedTimesLimit = 3;

class WebsocketService extends GetxService {
  RelayService rs = RelayService();
  NostrAPI nostrAPI = NostrAPI();
  RxString relayStatusInt = RelayStatusEnum.init.name.obs;
  final RxMap<String, RelayWebsocket> channels = <String, RelayWebsocket>{}.obs;
  final RxMap<String, RelayMessageFee> relayMessageFeeModels =
      <String, RelayMessageFee>{}.obs;
  Map<String, RelayFileFee> relayFileFeeModels = {};
  Map<String, Set<String>> failedEventsMap = {};

  DateTime initAt = DateTime.now();

  @override
  void onReady() {
    super.onReady();
    localFeesConfigFromLocalStorage();
    RelayService().initRelayFeeInfo();
  }

  int activitySocketCount() {
    return channels.values
        .where((element) => element.channelStatus == RelayStatusEnum.success)
        .length;
  }

  // new a websocket channel for this relay
  Future addChannel(Relay relay, [List<String> pubkeys = const []]) async {
    WebsocketService ws = this;
    RelayWebsocket rw = RelayWebsocket(relay, ws);
    channels[relay.url] = rw;
    if (!relay.active) {
      return;
    }

    rw = await _startConnectRelay(rw);
    if (pubkeys.isNotEmpty) {
      DateTime since = await MessageService().getNostrListenStartAt(relay.url);
      rw.listenPubkeys(pubkeys, since);
    }
  }

  Future checkOnlineAndConnect() async {
    // fix ConcurrentModificationError
    for (RelayWebsocket rw in List.from(channels.values)) {
      if (rw.relay.active == false) continue;
      rw.checkOnlineStatus().then((relayStatus) {
        if (!relayStatus) {
          rw.channel?.sink.close();
          _startConnectRelay(rw);
        }
      });
    }
  }

  deleteRelay(Relay value) {
    if (channels[value.url] != null) {
      channels[value.url]!.channel?.sink.close();
    }
    channels.remove(value.url);
  }

  List<RelayWebsocket> getConnectedRelay() {
    return channels.values
        .where((element) =>
            element.channelStatus == RelayStatusEnum.success &&
            element.channel != null)
        .toList();
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

  List<String> getOnlineRelayString() {
    List<String> res = [];
    for (RelayWebsocket rw in channels.values) {
      if (rw.channel != null && rw.channelStatus == RelayStatusEnum.success) {
        res.add(rw.relay.url);
      }
    }
    return res;
  }

  Future<WebsocketService> init() async {
    relayStatusInt.value = RelayStatusEnum.connecting.name;
    List<Relay> list = await rs.initRelay();
    start(list);
    return this;
  }

  listenPubkey(List<String> pubkeys,
      {DateTime? since, String? relay, int? limit}) {
    if (pubkeys.isEmpty) return;

    since ??= DateTime.now().subtract(const Duration(days: 7));
    String subId = utils.generate64RandomHexChars(16);

    NostrNip4Req req = NostrNip4Req(
        reqId: subId, pubkeys: pubkeys, since: since, limit: limit);

    Get.find<WebsocketService>().sendReq(req, relay);
  }

  listenPubkeyNip17(List<String> pubkeys,
      {DateTime? since, String? relay, int? limit}) async {
    if (pubkeys.isEmpty) return;

    since ??= DateTime.now().subtract(const Duration(days: 2));
    String subId = utils.generate64RandomHexChars(16);

    NostrNip4Req req = NostrNip4Req(
        reqId: subId,
        pubkeys: pubkeys,
        since: since,
        limit: limit,
        kinds: [EventKinds.nip17]);

    Get.find<WebsocketService>().sendReq(req, relay);
  }

  sendRawReq(String msg) {
    List<RelayWebsocket> list = getConnectedRelay();

    for (RelayWebsocket rw in list) {
      rw.sendRawREQ(msg);
    }
  }

  // fetch info and wait for response data
  Future<NostrEventModel?> fetchInfoFromRelay(
      String subId, String eventString) async {
    List<RelayWebsocket> list = getConnectedRelay();
    if (list.isEmpty) throw Exception('Not connected with relay server');
    for (RelayWebsocket rw in list) {
      rw.sendRawREQ(eventString);
    }
    return await SubscribeResult.instance
        .registerSubscripton(subId, list.length, const Duration(seconds: 2));
  }

  sendReq(NostrNip4Req nostrReq, [String? relay]) {
    if (relay != null && channels[relay] != null) {
      return channels[relay]!.sendREQ(nostrReq);
    }
    int sent = 0;
    for (RelayWebsocket rw in channels.values) {
      if (rw.channelStatus != RelayStatusEnum.success || rw.channel == null) {
        continue;
      }
      sent++;
      rw.sendREQ(nostrReq);
    }
    if (sent == 0) throw Exception('Not connected with relay server');
  }

  setChannelStatus(String relay, RelayStatusEnum status,
      [String? errorMessage]) {
    channels[relay]?.channelStatus = status;
    if (channels[relay] != null) {
      channels[relay]!.relay.errorMessage = errorMessage;
    }

    int success = channels.values
        .where((RelayWebsocket element) =>
            element.channelStatus == RelayStatusEnum.success)
        .length;

    if (success > 0) return setRelayStatusInt(RelayStatusEnum.success.name);

    if (success == 0) {
      int diff =
          DateTime.now().millisecondsSinceEpoch - initAt.millisecondsSinceEpoch;
      if (diff > 2000) {
        return setRelayStatusInt(RelayStatusEnum.allFailed.name);
      }
    }
    setRelayStatusInt(RelayStatusEnum.connecting.name);
  }

  String? lastRelayStatus;
  Future setRelayStatusInt(String name) async {
    lastRelayStatus = name;
    EasyDebounce.debounce(
        'setRelayStatusInt', const Duration(milliseconds: 100), () {
      relayStatusInt.value = lastRelayStatus ?? name;
    });
  }

  bool startLock = false;
  Future start([List<Relay>? list]) async {
    if (startLock) return;
    try {
      startLock = true;
      NostrAPI().processedEventIds.clear();
      initAt = DateTime.now();
      SubscribeEventStatus.clear();
      await stopListening();
      list ??= await RelayService().list();
      await createChannels(list);
    } finally {
      startLock = false;
    }
  }

  Future stopListening() async {
    for (RelayWebsocket rw in channels.values) {
      rw.channel?.sink.close();
      rw.channel = null;
    }
    channels.clear();
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

  void updateRelayWidget(Relay value) {
    if (channels[value.url] != null) {
      if (!value.active) {
        channels[value.url]!.channelStatus = RelayStatusEnum.noAcitveRelay;
      }
      channels[value.url]!.relay = value;
      channels.refresh();
    } else {
      addChannel(value);
    }
  }

  Future<List<String>> writeNostrEvent(
      {required NostrEventModel event,
      required String eventString,
      required int roomId,
      List<String> toRelays = const []}) async {
    List<String> activeRelays = _getTargetRelays(toRelays);

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

        if (rw.channelStatus == RelayStatusEnum.success) {
          try {
            ess = await addCashuToMessage(roomId, ess);
          } catch (e) {
            ess.sendStatus = EventSendEnum.cashuError;
            ess.error = e.toString();
            results.add(ess);
            return;
          }
          logger.i(
              'to:[${rw.relay.url}]: ${ess.rawEvent} }'); // ${eventRaw.length > 200 ? eventRaw.substring(0, 400) : eventRaw}');
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
        ess.sendStatus = getSendStatusByRelayStatus(rw.channelStatus);
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
        Get.snackbar('Message Send Failed', messages,
            icon: const Icon(Icons.error));
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
    if (toRelays.isNotEmpty) {
      List<String> activeTargetRelays =
          activeRelays.where((element) => toRelays.contains(element)).toList();
      if (activeTargetRelays.isNotEmpty) {
        activeRelays = activeTargetRelays;
      }
    }
    return activeRelays;
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

  Future createChannels([List<Relay> list = const []]) async {
    WebsocketService ws = this;
    await Future.wait(list.map((Relay relay) async {
      RelayWebsocket rw = RelayWebsocket(relay, ws);
      channels[relay.url] = rw;
      await _startConnectRelay(rw);
    }));
  }

  Future<RelayWebsocket> _startConnectRelay(RelayWebsocket rw,
      [bool skipCheck = false]) async {
    if (skipCheck == false) {
      if (!rw.relay.active) {
        return rw;
      }

      if (rw.failedTimes > failedTimesLimit) {
        rw.channelStatus = RelayStatusEnum.failed;
        rw.channel?.sink.close();
        clearFailedEvents(rw.relay.url);
        return rw;
      }
    }

    loggerNoLine
        .i('start onnect ${rw.relay.url}, failedTimes: ${rw.failedTimes}');

    final channel = IOWebSocketChannel.connect(Uri.parse(rw.relay.url),
        pingInterval: const Duration(seconds: 10),
        connectTimeout: const Duration(seconds: 8));

    rw.connecting();
    rw.channel = channel;

    String? errorMessage;
    channel.stream.listen((message) {
      nostrAPI.addNostrEventToQueue(rw.relay, message);
    }, onDone: () {
      logger.d('${rw.relay.url} websocket onDone');
      onErrorProcess(rw.relay.url, errorMessage);
    }, onError: (e) {
      errorMessage = e.toString();
      logger.e('${rw.relay.url} onError ${e.toString()}');
      onErrorProcess(rw.relay.url, errorMessage);
    });

    try {
      await channel.ready;
      rw.connectSuccess(channel);
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
      onErrorProcess(rw.relay.url, e.toString());
      return rw;
    }

    return rw;
  }

  bool existFreeRelay() {
    for (var channel in channels.entries) {
      if (channel.value.channelStatus == RelayStatusEnum.success) {
        if (relayMessageFeeModels[channel.key]?.amount == 0) {
          return true;
        }
      }
    }
    return false;
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

  void onErrorProcess(String relay, [String? errorMessage]) {
    EasyDebounce.debounce(
        '_startConnectRelay_$relay', const Duration(milliseconds: 1000),
        () async {
      if (channels[relay] == null) return;
      channels[relay]?.disconnected(errorMessage);
      logger.d(
          '$relay onErrorProcess _reconnectTimes: ${channels[relay]?.failedTimes}');
      await _startConnectRelay(channels[relay]!);
    });
  }

  EventSendEnum getSendStatusByRelayStatus(RelayStatusEnum channelStatus) {
    switch (channelStatus) {
      case RelayStatusEnum.init:
        return EventSendEnum.init;
      case RelayStatusEnum.noAcitveRelay:
        return EventSendEnum.noAcitveRelay;
      case RelayStatusEnum.connecting:
        return EventSendEnum.relayConnecting;
      case RelayStatusEnum.failed:
        return EventSendEnum.relayDisconnected;
      default:
        return EventSendEnum.init;
    }
  }

  Set<String> getFailedEvents(String relay) {
    return failedEventsMap[relay] ?? {};
  }

  addFaiedEvents(String relay, String raw) {
    if (failedEventsMap[relay] == null) {
      failedEventsMap[relay] = {};
    }
    failedEventsMap[relay]!.add(raw);
  }

  clearFailedEvents(String relay) {
    failedEventsMap.remove(relay);
  }
}
