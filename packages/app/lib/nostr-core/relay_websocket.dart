import 'package:app/constants.dart';
import 'package:app/models/relay.dart';
import 'package:app/nostr-core/nostr_nip4_req.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:async_queue/async_queue.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:keychat_ecash/NostrWalletConnect/NostrWalletConnect_controller.dart';
import 'package:web_socket_client/web_socket_client.dart';

const _maxReqCount = 20; // max pool size is 32. be setting by relay server

class RelayWebsocket {
  RelayService rs = RelayService.instance;
  late Relay relay;
  WebSocket? channel;
  List<String> notices = [];
  int maxReqCount = _maxReqCount;
  int sentReqCount = 0;
  Map<String, Set<String>> subscriptions = {}; // subId -> pubkeys
  late WebsocketService ws;
  RelayWebsocket(this.relay, this.ws);

  _startListen() async {
    // id keys
    List<String> pubkeys = await IdentityService.instance.getListenPubkeys();

    listenPubkeys(pubkeys, DateTime.now().subtract(const Duration(days: 2)),
        [EventKinds.nip17]);

    // mls group room
    DateTime since =
        await MessageService.instance.getNostrListenStartAt(relay.url);
    List<String> mlsRoomKeys =
        await IdentityService.instance.getMlsRoomPubkeys();
    listenPubkeys(mlsRoomKeys, since, [EventKinds.nip17]);

    // signal room keys
    List<String> signalRoomKeys =
        await IdentityService.instance.getSignalRoomPubkeys();

    listenPubkeys([...pubkeys, ...signalRoomKeys], since, [EventKinds.nip04]);
  }

  Future listenPubkeys(
      List<String> pubkeys, DateTime since, List<int> kinds) async {
    List<List<String>> groups = listToGroupList(pubkeys, 120);

    for (List<String> group in groups) {
      String subId = generate64RandomHexChars(16);

      NostrReqModel req = NostrReqModel(
          reqId: subId, kinds: kinds, pubkeys: group, since: since);
      sendRawREQ(req.toString());
    }
  }

  sendREQ(NostrReqModel nq) {
    _statusCheck();
    if (subscriptions.keys.length < maxReqCount) {
      if (nq.pubkeys != null && nq.pubkeys!.isNotEmpty) {
        subscriptions[nq.reqId] = Set.from(nq.pubkeys!);
      }
      return sendRawREQ(nq.toString());
    }
    int index = sentReqCount % maxReqCount;
    String key = subscriptions.keys.elementAt(index);
    if (nq.pubkeys != null && nq.pubkeys!.isNotEmpty) {
      subscriptions[key]!.addAll(nq.pubkeys!);
    }
    // Reuse the reqId of the previous request and overwrite the server's configuration
    nq.reqId = key;
    nq.pubkeys = subscriptions[key]?.toList();
    ++sentReqCount;
    // logger.d('use old sub: ${nq.reqId} , length: ${nq.pubkeys.length}');
    return sendRawREQ(nq.toString());
  }

  isConnected() {
    if (channel == null) return false;
    return channel?.connection.state is Connected ||
        channel?.connection.state is Reconnected;
  }

  isDisConnected() {
    if (channel == null) return true;
    return channel?.connection.state is Disconnected ||
        channel?.connection.state is Disconnecting;
  }

  isConnecting() {
    return channel?.connection.state is Connecting ||
        channel?.connection.state is Reconnecting;
  }

  _statusCheck() {
    if (channel == null) {
      throw Exception('channel is null');
    }

    if (isDisConnected() || isConnecting()) {
      throw Exception('disconnected: ${relay.url}');
    }
  }

  Future _proccessFailedEvents() async {
    Set<String> failedEvents = ws.getFailedEvents(relay.url);
    if (failedEvents.isEmpty) return;
    logger.i('proccessFailedEvents: ${failedEvents.length}');
    List<String> tasksString = failedEvents.toList();
    failedEvents.clear();
    AsyncQueue queue = AsyncQueue.autoStart();
    for (String element in tasksString) {
      queue.addJob((_) => sendRawREQ(element, retry: true));
    }
  }

  sendRawREQ(String message, {bool retry = false}) {
    try {
      _statusCheck();
      channel?.send(message);
      loggerNoLine.d('TO [${relay.url}]: $message');
    } catch (e, s) {
      logger.e('TO [${relay.url}]: $message', error: e, stackTrace: s);
      if (retry) {
        ws.addFaiedEvents(relay.url, message);
      }
      rethrow;
    }
  }

  // send ping to relay. if relay not response, socket is closed.
  Future<bool> checkOnlineStatus() async {
    if (channel == null || isDisConnected()) {
      return false;
    }
    notices.clear();
    try {
      channel!.send('ping');
    } catch (e) {
      return false;
    }
    final deadline = DateTime.now().add(const Duration(seconds: 1));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (notices.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  void connectSuccess() async {
    subscriptions.clear();
    notices.clear();
    maxReqCount = _maxReqCount;
    sentReqCount = 0;

    _startListen();
    Future.delayed(const Duration(seconds: 1)).then((value) {
      // init mls keypackages
      EasyDebounce.debounce(
          'connectSuccess:${relay.url}', const Duration(seconds: 3), () async {
        await MlsGroupService.instance.uploadKeyPackages(toRelays: [relay.url]);
      });
      _proccessFailedEvents();
      // nwc reconnect
      Utils.getGetxController<NostrWalletConnectController>()
          ?.startListening(relay.url);
    });
  }
}
