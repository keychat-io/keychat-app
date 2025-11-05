import 'package:keychat/constants.dart';
import 'package:keychat/models/relay.dart';
import 'package:keychat/nostr-core/nostr_nip4_req.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/relay.service.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:keychat_ecash/NostrWalletConnect/NostrWalletConnect_controller.dart';
import 'package:web_socket_client/web_socket_client.dart';

const _maxReqCount = 20; // max pool size is 32. be setting by relay server

class RelayWebsocket {
  RelayWebsocket(this.relay, this.ws);
  RelayService rs = RelayService.instance;
  late Relay relay;
  WebSocket? channel;
  int maxReqCount = _maxReqCount;
  int sentReqCount = 0;
  bool pong = false;
  Map<String, Set<String>> subscriptions = {}; // subId -> pubkeys
  late WebsocketService ws;

  Future<void> _startListen() async {
    // id keys
    final pubkeys = await IdentityService.instance.getListenPubkeys();

    listenPubkeys(
      pubkeys,
      DateTime.now().subtract(const Duration(days: 2)),
      [EventKinds.nip17],
    );

    // mls group room
    final since = await MessageService.instance.getNostrListenStartAt(
      relay.url,
    );
    final mlsRoomKeys = await IdentityService.instance.getMlsRoomPubkeys();
    listenPubkeys(mlsRoomKeys, since, [EventKinds.nip17]);

    // signal room keys
    final signalRoomKeys = await IdentityService.instance
        .getSignalRoomPubkeys();

    listenPubkeys([...pubkeys, ...signalRoomKeys], since, [EventKinds.nip04]);
  }

  void listenPubkeys(
    List<String> pubkeys,
    DateTime since,
    List<int> kinds,
  ) {
    final groups = listToGroupList(pubkeys, 120);

    for (final group in groups) {
      final subId = generate64RandomHexChars(16);

      final req = NostrReqModel(
        reqId: subId,
        kinds: kinds,
        pubkeys: group,
        since: since,
      );
      sendRawREQ(req.toString());
    }
  }

  dynamic sendREQ(NostrReqModel nq) {
    if (subscriptions.keys.length < maxReqCount) {
      if (nq.pubkeys != null && nq.pubkeys!.isNotEmpty) {
        subscriptions[nq.reqId] = Set.from(nq.pubkeys!);
      }
      return sendRawREQ(nq.toString());
    }
    final index = sentReqCount % maxReqCount;
    final key = subscriptions.keys.elementAt(index);
    if (nq.pubkeys != null && nq.pubkeys!.isNotEmpty) {
      subscriptions[key]!.addAll(nq.pubkeys!);
    }
    // Reuse the reqId of the previous request and overwrite the server's configuration
    nq.reqId = key;
    nq.pubkeys = subscriptions[key]?.toList();
    ++sentReqCount;
    // logger.i('use old sub: ${nq.reqId} , length: ${nq.pubkeys.length}');
    return sendRawREQ(nq.toString());
  }

  bool isConnected() {
    if (channel == null) return false;
    return channel?.connection.state is Connected ||
        channel?.connection.state is Reconnected;
  }

  bool isDisConnected() {
    if (channel == null) return true;
    return channel?.connection.state is Disconnected ||
        channel?.connection.state is Disconnecting;
  }

  bool isConnecting() {
    return channel?.connection.state is Connecting ||
        channel?.connection.state is Reconnecting;
  }

  void _statusCheck() {
    if (channel == null) {
      throw Exception('channel is null');
    }

    if (isDisConnected() || isConnecting()) {
      throw Exception('disconnected: ${relay.url}');
    }
  }

  void sendRawREQ(String message) {
    _statusCheck();
    channel!.send(message);
    loggerNoLine.d('TO [${relay.url}]: $message');
  }

  // send ping to relay. if relay not response, socket is closed.
  Future<bool> checkOnlineStatus() async {
    if (channel == null || isDisConnected()) {
      return false;
    }
    pong = false;
    try {
      channel!.send('ping');
      // loggerNoLine.d('TO [${relay.url}]: ping');
    } catch (e) {
      return false;
    }
    final deadline = DateTime.now().add(const Duration(seconds: 1));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (pong) {
        return true;
      }
    }
    return false;
  }

  Future<void> connectSuccess() async {
    subscriptions.clear();
    maxReqCount = _maxReqCount;
    sentReqCount = 0;

    await _startListen();

    EasyDebounce.debounce(
      'connectSuccess:${relay.url}',
      const Duration(seconds: 3),
      () async {
        await MlsGroupService.instance.uploadKeyPackages(toRelay: relay.url);
      },
    );
    // nwc reconnect
    Utils.getGetxController<NostrWalletConnectController>()?.startListening(
      relay.url,
    );
  }
}
