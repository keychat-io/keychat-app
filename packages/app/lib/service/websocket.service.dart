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
import 'package:app/nostr-core/subscribe_event_status.dart';
import 'package:app/nostr-core/relay_websocket.dart';
import 'package:app/nostr-core/subscribe_result.dart';
import 'package:app/page/setting/RelaySetting.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/cupertino.dart' hide ConnectionState;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:queue/queue.dart';

import 'package:get/get.dart';
import 'package:keychat_ecash/keychat_ecash.dart';
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

  @override
  void onReady() {
    super.onReady();
    localFeesConfigFromLocalStorage();
    RelayService.instance.initRelayFeeInfo();
  }

  int activitySocketCount() {
    return channels.values
        .where((element) => element.channelStatus == RelayStatusEnum.connected)
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
      DateTime since =
          await MessageService.instance.getNostrListenStartAt(relay.url);
      rw.listenPubkeys(pubkeys, since);
    }
  }

  Future checkOnlineAndConnect([List<RelayWebsocket>? list]) async {
    loggerNoLine.d('checkOnlineAndConnect all relays');
    // fix ConcurrentModificationError
    for (RelayWebsocket rw in List.from(list ?? channels.values)) {
      if (rw.relay.active == false) continue;
      rw.checkOnlineStatus().then((relayStatus) {
        if (!relayStatus) {
          rw.channel?.close();
          _startConnectRelay(rw, true);
        }
      });
    }
  }

  deleteRelay(Relay value) {
    if (channels[value.url] != null) {
      channels[value.url]!.channel?.close();
    }
    channels.remove(value.url);
  }

  List<RelayWebsocket> getConnectedRelay() {
    return channels.values
        .where((element) =>
            element.channelStatus == RelayStatusEnum.connected &&
            element.channel != null)
        .toList();
  }

  List<RelayWebsocket> getConnectedNip104Relay() {
    var list = channels.values
        .where((element) =>
            element.channelStatus == RelayStatusEnum.connected &&
            element.channel != null)
        .toList();
    var nip104Enable = list.where((element) => element.relay.isEnableNip104);
    return nip104Enable.toList();
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
      if (rw.channel != null && rw.channelStatus == RelayStatusEnum.connected) {
        res.add(rw.relay.url);
      }
    }
    return res;
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
      {DateTime? since,
      String? relay,
      int? limit,
      List<int> kinds = const [EventKinds.nip04]}) {
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
      Get.find<WebsocketService>().sendReq(req, relay: relay);
    } catch (e) {
      if (e.toString().contains('RelayDisconnected')) {
        EasyLoading.showToast('Disconnected, Please check your relay server');
      }
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

  sendRawReq(String msg) {
    List<RelayWebsocket> list = getConnectedRelay();

    for (RelayWebsocket rw in list) {
      rw.sendRawREQ(msg);
    }
  }

  // fetch info and wait for response data
  Future<List<NostrEventModel>> fetchInfoFromRelay(
      String subId, String eventString,
      {Duration wait = const Duration(seconds: 2),
      bool waitTimeToFill = false,
      List<RelayWebsocket>? sockets}) async {
    sockets ??= getConnectedRelay();
    if (sockets.isEmpty) {
      throw Exception('Not connected, or the relay not support nips');
    }
    for (RelayWebsocket rw in sockets) {
      rw.sendRawREQ(eventString);
    }
    return await SubscribeResult.instance.registerSubscripton(
        subId, sockets.length,
        wait: wait, waitTimeToFill: waitTimeToFill);
  }

  sendReq(NostrReqModel nostrReq,
      {String? relay, Function(String relay)? callback}) {
    if (relay != null && channels[relay] != null) {
      return channels[relay]!.sendREQ(nostrReq);
    }
    int sent = 0;
    for (RelayWebsocket rw in channels.values) {
      if (rw.channelStatus != RelayStatusEnum.connected || rw.channel == null) {
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

  sendMessage(String content, [List<String>? relays]) {
    if (relays != null && relays.isNotEmpty) {
      int sent = 0;
      for (String relay in relays) {
        if (channels[relay] != null &&
            channels[relay]!.channelStatus == RelayStatusEnum.connected &&
            channels[relay]!.channel != null) {
          channels[relay]!.sendRawREQ(content);
          sent++;
        }
      }
      if (sent > 0) return;
    }

    int sent = 0;
    for (RelayWebsocket rw in channels.values) {
      if (rw.channelStatus != RelayStatusEnum.connected || rw.channel == null) {
        continue;
      }
      sent++;
      rw.sendRawREQ(content);
    }
    if (sent == 0) {
      throw Exception(
          'Not connected any relay server, please check your network');
    }
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
      } catch (e) {}
    }
    if (relays != null && relays.isNotEmpty) {
      int sent = 0;
      for (String relay in relays) {
        if (channels[relay] != null &&
            channels[relay]!.channelStatus == RelayStatusEnum.connected &&
            channels[relay]!.channel != null) {
          channels[relay]!.sendRawREQ("[\"EVENT\",$content]");
          sent++;
        }
      }
      if (sent > 0) return;
    }

    int sent = 0;
    for (RelayWebsocket rw in channels.values) {
      if (rw.channelStatus != RelayStatusEnum.connected || rw.channel == null) {
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

  List<RelayWebsocket> getOnlineWebsocket() {
    return channels.values.where((RelayWebsocket element) {
      if (element.channel?.connection.state is Connected ||
          element.channel?.connection.state is Reconnected) {
        return true;
      }
      return false;
    }).toList();
  }

  refreshMainRelayStatus() {
    EasyDebounce.debounce('refreshMainRelayStatus', Duration(seconds: 1),
        () async {
      int success = getOnlineWebsocket().length;
      loggerNoLine.d('refreshMainRelayStatus, online: $success');
      if (success > 0) {
        return await setRelayStatusInt(RelayStatusEnum.connected.name);
      }

      if (success == 0) {
        int diff = DateTime.now().millisecondsSinceEpoch -
            initAt.millisecondsSinceEpoch;
        if (diff > 2000) {
          return await setRelayStatusInt(RelayStatusEnum.allFailed.name);
        }
      }
      await setRelayStatusInt(RelayStatusEnum.connecting.name);
    });
  }

  String? lastRelayStatus;
  Future setRelayStatusInt(String name) async {
    lastRelayStatus = name;
    EasyDebounce.debounce(
        'setRelayStatusInt', const Duration(milliseconds: 100), () {
      relayStatusInt.value = lastRelayStatus ?? name;
      channels.refresh();
    });
  }

  bool startLock = false;
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

        if (rw.channelStatus == RelayStatusEnum.connected) {
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
      [bool ignoreFailedTime = false]) async {
    if (rw.relay.active == false) {
      return rw;
    }

    loggerNoLine.i('start connect ${rw.relay.url}');

    final channel = WebSocket(Uri.parse(rw.relay.url),
        pingInterval: const Duration(seconds: 10),
        timeout: const Duration(seconds: 8),
        backoff: LinearBackoff(
          initial: Duration(seconds: 0),
          increment: Duration(seconds: 2),
          maximum: Duration(seconds: 16),
        ));

    rw.channel = channel;

    channel.messages.listen((message) {
      nostrAPI.addNostrEventToQueue(rw.relay, message);
    });
    channel.connection.listen((ConnectionState state) {
      if (state is Connecting || state is Reconnecting) {
        rw.channelStatus = RelayStatusEnum.connecting;
      }

      if (state is Connected || state is Reconnected) {
        rw.channelStatus = RelayStatusEnum.connected;
        rw.connectSuccess(channel);
      }

      if (state is Disconnecting || state is Disconnected) {
        rw.channelStatus = RelayStatusEnum.failed;
      }
      // update the main page status
      refreshMainRelayStatus();
    });

    return rw;
  }

  bool existFreeRelay() {
    for (var channel in channels.entries) {
      if (channel.value.channelStatus == RelayStatusEnum.connected) {
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
