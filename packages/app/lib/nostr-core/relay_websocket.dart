import 'dart:async';

import 'package:keychat/constants.dart';
import 'package:keychat/models/relay.dart';
import 'package:keychat/nostr-core/nostr_nip4_req.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/service/relay.service.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/NostrWalletConnect/NostrWalletConnect_controller.dart';
import 'package:keychat_ecash/nwc/nwc_controller.dart';
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

  // Stream subscriptions to prevent memory leaks
  StreamSubscription<ConnectionState>? connectionStateSubscription;
  StreamSubscription<dynamic>? messagesSubscription;

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

  /// Subscribes to events for [pubkeys] of specified [kinds] since [since].
  ///
  /// Splits pubkeys into groups of 120 to stay within relay subscription limits.
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

  /// Sends a REQ subscription, reusing an existing subscription slot if the relay's
  /// max concurrent subscription count [maxReqCount] is reached.
  ///
  /// When the limit is reached, merges the new pubkeys into an existing subscription
  /// using round-robin slot selection to avoid server rejection.
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

  /// Returns true if the WebSocket channel is in a [Connected] or [Reconnected] state.
  bool isConnected() {
    if (channel == null) return false;
    return channel?.connection.state is Connected ||
        channel?.connection.state is Reconnected;
  }

  /// Returns true if the WebSocket channel is in a [Disconnected] or [Disconnecting] state.
  bool isDisConnected() {
    if (channel == null) return true;
    return channel?.connection.state is Disconnected ||
        channel?.connection.state is Disconnecting;
  }

  /// Returns true if the WebSocket channel is in a [Connecting] or [Reconnecting] state.
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

  /// Sends a raw REQ/EVENT/CLOSE message string directly to the relay WebSocket.
  ///
  /// Throws if the channel is disconnected or null.
  void sendRawREQ(String message) {
    _statusCheck();
    channel!.send(message);
    loggerNoLine.d('TO [${relay.url}]: $message');
  }

  /// Sends a ping to the relay and waits up to 1 second for a pong response.
  ///
  /// Returns true if the relay responded (pong received), false otherwise.
  /// If the relay does not respond, the caller should close and reconnect the socket.
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

  /// Called after a successful WebSocket connection is established.
  ///
  /// Resets subscription state, starts listening to required pubkeys,
  /// and triggers NWC reconnection callbacks.
  Future<void> connectSuccess() async {
    subscriptions.clear();
    maxReqCount = _maxReqCount;
    sentReqCount = 0;

    await _startListen();

    // nwc server reconnect
    Utils.getGetxController<NostrWalletConnectController>()?.startListening(
      relay.url,
    );

    // nwc client reconnect
    Utils.getGetxController<NwcController>()?.onRelayConnected(relay.url);
  }

  /// Clean up all subscriptions to prevent memory leaks.
  /// Call this before creating a new WebSocket connection.
  void cleanupSubscriptions() {
    connectionStateSubscription?.cancel();
    connectionStateSubscription = null;
    messagesSubscription?.cancel();
    messagesSubscription = null;
    subscriptions.clear();
  }
}
