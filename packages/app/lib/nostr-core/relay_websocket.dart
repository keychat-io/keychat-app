import 'package:app/models/relay.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_nip4_req.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:websocket_universal/websocket_universal.dart';
import '../utils.dart' as utils;

const _maxReqCount = 20; // max pool size is 32. be setting by relay server

class RelayWebsocket {
  RelayService rs = RelayService();
  late Relay relay;
  RelayStatusEnum channelStatus = RelayStatusEnum.init;
  IWebSocketHandler? channel;
  List<String> notices = [];
  int maxReqCount = _maxReqCount;
  int sentReqCount = 0;
  int failedTimes = 0;
  Map<String, Set<String>> subscriptions = {};

  RelayWebsocket(this.relay);

  _reset() {
    subscriptions.clear();
    notices.clear();
    maxReqCount = _maxReqCount;
    sentReqCount = 0;
    channelStatus = RelayStatusEnum.init;
    channel = null;
  }

  // listen identity key will take position.
  _start() async {
    DateTime since = await MessageService().getNostrListenStartAt(relay.url);
    List<String> pubkeys = await IdentityService().getListenPubkeys();
    startListen(pubkeys, since);

    List<String> signal = await ContactService().getAllReceiveKeys();
    startListen(signal, since);
    NostrAPI().checkFaildEvent();
  }

  Future startListen(List<String> pubkeys, DateTime since) async {
    List<List<String>> groups = utils.listToGroupList(pubkeys, 120);

    for (List<String> group in groups) {
      String subId = utils.generate64RandomHexChars(16);

      NostrNip4Req req =
          NostrNip4Req(reqId: subId, pubkeys: group, since: since, limit: 300);
      try {
        sendRawREQ(req.toString());
        logger.e(
            'start listen success: ${relay.url} - ${req.pubkeys.length} pubkeys');
      } catch (e) {
        logger.e('startListen error', error: e);
      }
    }
  }

  sendREQ(NostrNip4Req nq) {
    if (channel == null || channelStatus != RelayStatusEnum.success) {
      throw Exception('Not connected with relay server, ${relay.url}');
    }

    // not reacth the limit
    if (subscriptions.keys.length < maxReqCount) {
      // logger.d('create sub: ${nq.reqId}');
      subscriptions[nq.reqId] = Set.from(nq.pubkeys);
      return sendRawREQ(nq.toString());
    }
    int index = sentReqCount % maxReqCount;
    String key = subscriptions.keys.elementAt(index);
    subscriptions[key]!.addAll(nq.pubkeys);
    // Reuse the reqId of the previous request and overwrite the server's configuration
    nq.reqId = key;
    nq.pubkeys = subscriptions[key]!.toList();
    ++sentReqCount;
    // logger.d('use old sub: ${nq.reqId} , length: ${nq.pubkeys.length}');
    return sendRawREQ(nq.toString());
  }

  sendRawREQ(String message) {
    if (channel == null || channelStatus != RelayStatusEnum.success) {
      throw Exception(
          'Not connected with relay server ${relay.url}: ${channelStatus.name}');
    }
    channel!.sendMessage(message);
    logger.i('Send[${relay.url}] $message');
  }

  // send ping to relay. if relay not response, socket is closed.
  Future<bool> checkOnlineStatus() async {
    if (channel == null || channelStatus != RelayStatusEnum.success) {
      return false;
    }
    notices.clear();
    channel!.sendMessage('ping');

    final deadline = DateTime.now().add(const Duration(seconds: 1));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (notices.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  void connectSuccess(IWebSocketHandler textSocketHandler) {
    failedTimes = 0;
    _reset();
    channel = textSocketHandler;
    Get.find<WebsocketService>()
        .setChannelStatus(relay.url, RelayStatusEnum.success);
    _start();
  }

  void connecting() {
    Get.find<WebsocketService>()
        .setChannelStatus(relay.url, RelayStatusEnum.connecting);
  }

  void disconnected() {
    failedTimes++;
    Get.find<WebsocketService>()
        .setChannelStatus(relay.url, RelayStatusEnum.failed);
  }
}
