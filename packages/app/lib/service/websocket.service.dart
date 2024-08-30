import 'package:app/constants.dart';
import 'package:app/models/embedded/cashu_info.dart';
import 'package:app/models/embedded/relay_file_fee.dart';
import 'package:app/models/embedded/relay_message_fee.dart';
import 'package:app/models/message_bill.dart';
import 'package:app/models/relay.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/nostr-core/nostr_nip4_req.dart';
import 'package:app/nostr-core/relay_event_status.dart';
import 'package:app/nostr-core/relay_websocket.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_debounce.dart';
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
    RelayWebsocket rw = RelayWebsocket(relay);
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
      // logger.d(
      //     '> checkOnlineAndConnect ${rw.relay.url}: ${rw.channelStatus.name} ${rw.channel?.closeCode} _ ${rw.channel?.closeReason}');
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
      {DateTime? since, String? relay, int? limit}) async {
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

  sendRawReq(String msg, [String? relay]) {
    if (relay != null && channels[relay] != null) {
      return channels[relay]!.sendRawREQ(msg);
    }
    for (RelayWebsocket rw in channels.values) {
      rw.sendRawREQ(msg);
    }
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
      if (relayStatusInt.value != name) {
        relayStatusInt.value = name;
      }
    });
  }

  bool startLock = false;
  Future start([List<Relay>? list]) async {
    if (startLock) return;
    try {
      startLock = true;
      NostrAPI().processedEventIds.clear();
      initAt = DateTime.now();
      WriteEventStatus.clear();
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
          break;
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
      String? hisRelay,
      Function(bool)? sentCallback}) async {
    List<String> relays = getOnlineRelayString();
    // set his relay
    if (hisRelay != null && hisRelay.isNotEmpty) {
      relays = [];
      if (channels[hisRelay] != null) {
        if (channels[hisRelay]!.channelStatus == RelayStatusEnum.success) {
          relays = [hisRelay];
        }
      }
    }
    if (relays.isEmpty) {
      throw Exception('His relay not connected');
    }

    // listen status
    WriteEventStatus.addSubscripton(event.id, relays.length,
        sentCallback: sentCallback);

    List<Future> tasks = [];
    Map failedRelay = {};
    String toSendMesage = "[\"EVENT\",$eventString]";
    for (String relay in relays) {
      tasks.add(() async {
        try {
          String eventRaw =
              await addCashuToMessage(toSendMesage, relay, roomId, event.id);
          if (channels[relay]?.channel != null) {
            logger.i(
                'to:[$relay]: $eventRaw }'); // ${eventRaw.length > 200 ? eventRaw.substring(0, 400) : eventRaw}');
            channels[relay]!.channel!.sink.add(eventRaw);
          } else {
            failedRelay[relay] = 'Relay not connected';
          }
        } catch (e, s) {
          String message = Utils.getErrorMessage(e);
          logger.e(message, error: e, stackTrace: s);
          failedRelay[relay] = message;
        }
      }());
    }
    Future.wait(tasks).whenComplete(() {
      if (relays.length == failedRelay.entries.length) {
        String messages = failedRelay.entries
            .map((item) => '${item.key}: ${item.value}')
            .toList()
            .join('\n');
        Get.snackbar('Message Send Failed', messages,
            icon: const Icon(Icons.error));
      }
    });
    return relays;
  }

  Future<String> addCashuToMessage(
      String message, String relay, int roomId, String eventId) async {
    RelayMessageFee? payInfoModel = relayMessageFeeModels[relay];
    if (payInfoModel == null) return message;
    if (payInfoModel.amount == 0) return message;
    CashuInfoModel? cashuA;

    cashuA = await CashuUtil.getStamp(
        amount: payInfoModel.amount,
        token: payInfoModel.unit.name,
        mints: payInfoModel.mints);

    message = message.substring(0, message.length - 1);
    message += ',"${cashuA.token}"]';
    double amount = (payInfoModel.amount).toDouble();

    MessageBill mb = MessageBill(
        eventId: eventId,
        roomId: roomId,
        amount: amount,
        relay: relay,
        createdAt: DateTime.now(),
        cashuA: cashuA.token);
    MessageService().insertMessageBill(mb);
    return message;
  }

  Future createChannels([List<Relay> list = const []]) async {
    await Future.wait(list.map((Relay relay) async {
      RelayWebsocket rw = RelayWebsocket(relay);
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
}
