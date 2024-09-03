import 'package:app/constants.dart';
import 'package:app/models/relay.dart';
import 'package:app/nostr-core/nostr_nip4_req.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils.dart' as utils;

const _maxReqCount = 20; // max pool size is 32. be setting by relay server

class RelayWebsocket {
  RelayService rs = RelayService();
  late Relay relay;
  RelayStatusEnum channelStatus = RelayStatusEnum.init;
  WebSocketChannel? channel;
  List<String> notices = [];
  int maxReqCount = _maxReqCount;
  int sentReqCount = 0;
  int failedTimes = 0;
  Map<String, Set<String>> subscriptions = {};

  RelayWebsocket(this.relay);

  // listen identity key will take position.
  _startListen() async {
    DateTime since = await MessageService().getNostrListenStartAt(relay.url);
    List<String> pubkeys = await IdentityService().getListenPubkeys();
    listenPubkeys(pubkeys, since);
    listenPubkeys(pubkeys, DateTime.now().subtract(const Duration(days: 2)),
        [EventKinds.nip17]);

    List<String> signal = await ContactService().getAllReceiveKeys();
    listenPubkeys(signal, since);
  }

  Future listenPubkeys(List<String> pubkeys, DateTime since,
      [List<int> kinds = const [EventKinds.encryptedDirectMessage]]) async {
    List<List<String>> groups = utils.listToGroupList(pubkeys, 120);

    for (List<String> group in groups) {
      String subId = utils.generate64RandomHexChars(16);

      NostrNip4Req req = NostrNip4Req(
          reqId: subId, kinds: kinds, pubkeys: group, since: since);
      try {
        sendRawREQ(req.toString());
      } catch (e) {
        logger.e('Listen error', error: e);
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
    channel!.sink.add(message);
    logger.i('Send[${relay.url}] $message');
  }

  // send ping to relay. if relay not response, socket is closed.
  Future<bool> checkOnlineStatus() async {
    if (channel == null || channelStatus != RelayStatusEnum.success) {
      return false;
    }
    notices.clear();
    channel!.sink.add('ping');
    final deadline = DateTime.now().add(const Duration(seconds: 1));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (notices.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  void connectSuccess(IOWebSocketChannel socket) async {
    failedTimes = 0;
    subscriptions.clear();
    notices.clear();
    maxReqCount = _maxReqCount;
    sentReqCount = 0;
    channel = socket;
    channelStatus = RelayStatusEnum.success;

    await Get.find<WebsocketService>()
        .setChannelStatus(relay.url, RelayStatusEnum.success);
    _startListen();
  }

  void connecting() {
    Get.find<WebsocketService>()
        .setChannelStatus(relay.url, RelayStatusEnum.connecting);
  }

  void disconnected(String? errorMessage) {
    failedTimes++;
    Get.find<WebsocketService>()
        .setChannelStatus(relay.url, RelayStatusEnum.failed, errorMessage);
  }
}
