import 'dart:async';
import 'dart:convert' show jsonDecode;
import 'dart:math' show min;

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

/// Tracks connection backoff state for a single relay.
/// Implements exponential backoff to prevent reconnection storms.
class _RelayBackoffState {
  int failureCount = 0;
  DateTime? lastAttempt;
  DateTime? lastSuccess;

  /// Calculate exponential backoff duration based on failure count.
  /// Returns: 3s, 6s, 12s, 24s, 48s, max 60s
  Duration getBackoffDuration() {
    final seconds = min(3 * (1 << failureCount), 60);
    return Duration(seconds: seconds);
  }

  /// Check if enough time has passed since last attempt.
  bool shouldAttempt() {
    if (lastAttempt == null) return true;
    final backoff = getBackoffDuration();
    return DateTime.now().difference(lastAttempt!) > backoff;
  }

  /// Record a connection failure, incrementing backoff.
  void recordFailure() {
    failureCount++;
    lastAttempt = DateTime.now();
    logger.d(
      'Relay failure recorded, count: $failureCount, next retry in: ${getBackoffDuration().inSeconds}s',
    );
  }

  /// Record a successful connection, resetting backoff.
  void recordSuccess() {
    failureCount = 0;
    lastAttempt = null;
    lastSuccess = DateTime.now();
  }

  /// Check if relay has had a recent successful connection.
  /// Used to determine if a relay is healthy enough to skip reconnection.
  bool isHealthy() {
    if (lastSuccess == null) return false;
    // Healthy if successful connection within last 5 minutes
    return DateTime.now().difference(lastSuccess!) < const Duration(minutes: 5);
  }
}

class WebsocketService extends GetxService {
  WebsocketService() {
    logger.i('start init websocket service');
    // initialize relays and websocket service
    RelayService.instance.initRelay().then((relays) {
      mainRelayStatus.value = RelayStatusEnum.connecting.name;
      unawaited(start(relays));
      final activeCount = relays.where((element) => element.active).length;
      if (activeCount == 0) {
        mainRelayStatus.value = RelayStatusEnum.noAcitveRelay.name;
      }
    });
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

  /// Tracks exponential backoff state for each relay.
  /// Key: relay URL, Value: backoff state with failure count and timing
  final Map<String, _RelayBackoffState> _backoffStates = {};

  /// Get or create backoff state for a relay.
  /// Public to allow health checks from other services.
  _RelayBackoffState getBackoffState(String url) {
    return _backoffStates.putIfAbsent(url, _RelayBackoffState.new);
  }

  /// Returns the number of currently connected (active) relay WebSocket channels.
  int activitySocketCount() {
    return channels.values.where((element) => element.isConnected()).length;
  }

  /// Returns the [RelayFileFee] configuration for the relay at [url], or null if not set.
  RelayFileFee? getRelayFileFeeModel(String url) {
    final uri = Uri.parse(url);
    return relayFileFeeModels[uri.host];
  }

  /// Stores the [RelayFileFee] configuration for the relay at [url], keyed by hostname.
  void setRelayFileFeeModel(String url, RelayFileFee fuc) {
    final uri = Uri.parse(url);
    relayFileFeeModels[uri.host] = fuc;
  }

  /// Attaches a Cashu ecash token to a relay event status if the relay requires payment.
  ///
  /// Fetches a stamp of the required [payInfoModel.amount] from the configured mints.
  /// Updates [eventSendStatus] with the token and mint info, then appends the token
  /// to the raw event JSON string.
  ///
  /// Throws if [totalBalanceSat] is 0 or the mint cannot issue the stamp.
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

  /// Creates and registers a new WebSocket channel for [relay].
  ///
  /// If [relay.active] is false, the channel entry is created but not connected.
  /// Invokes [connectedCallback] after the connection is established.
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

  /// Checks connection health for all (or specified) relays and reconnects as needed.
  ///
  /// Uses exponential backoff to skip relays in the cooldown period unless [forceReconnect]
  /// is true. Pings each connected relay and triggers reconnection if unresponsive.
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

        final backoff = getBackoffState(rw.relay.url);

        // Skip if in backoff period (unless forced)
        if (!forceReconnect && !backoff.shouldAttempt()) {
          logger.d(
            'Skipping ${rw.relay.url} - in backoff period (${backoff.failureCount} failures)',
          );
          return;
        }

        if (forceReconnect) {
          // Clean up old subscriptions before closing
          rw.cleanupSubscriptions();
          rw.channel?.close();
          backoff.lastAttempt = DateTime.now();
          await _startConnectRelay(rw);
          return;
        }

        // Check health before reconnecting
        if (rw.isConnected()) {
          final isHealthy = await rw.checkOnlineStatus();
          if (isHealthy) {
            backoff.recordSuccess();
            logger.d('${rw.relay.url} is healthy, skipping reconnect');
            return; // Connection is good
          }
        }

        // Need to reconnect
        logger.i('Reconnecting ${rw.relay.url}');
        rw.cleanupSubscriptions();
        rw.channel?.close();
        backoff.recordFailure();
        await _startConnectRelay(rw);
      }),
    );
  }

  /// Creates WebSocket channels for all relays in [list] concurrently.
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

  /// Deactivates [relay], closes its WebSocket channel, and persists the change.
  Future<void> disableRelay(Relay relay) async {
    relay.active = false;
    relay.errorMessage = null;
    await RelayService.instance.update(relay);
    if (channels[relay.url] != null) {
      channels[relay.url]!.cleanupSubscriptions();
      channels[relay.url]!.channel?.close();
      channels[relay.url]!.relay = relay;
      channels.refresh();
    }
  }

  /// Returns true if at least one connected relay has zero message fee configured.
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

  /// Sends a REQ to one or more relays and waits up to [wait] for responses.
  ///
  /// Registers a [SubscribeResult] subscription keyed by [subId] and collects
  /// events until [waitTimeToFill] or the deadline passes.
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

  /// Returns the URLs of all relays that have [active] set to true.
  List<String> getActiveRelayString() {
    final res = <String>{};
    for (final rw in List<RelayWebsocket>.from(channels.values)) {
      if (rw.relay.active) {
        res.add(rw.relay.url);
      }
    }
    return res.toList();
  }

  /// Maps a WebSocket [ConnectionState] to a status indicator [Color].
  ///
  /// Connecting/Reconnecting → yellow, Connected/Reconnected → green, Disconnected → red.
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

  /// Returns all [RelayWebsocket] instances that are currently connected.
  List<RelayWebsocket> getOnlineSocket() {
    return channels.values.where((element) => element.isConnected()).toList();
  }

  /// Returns the URLs of all currently connected relay WebSocket channels.
  List<String> getOnlineSocketString() {
    final res = <String>[];
    // ignore: omit_local_variable_types
    for (final RelayWebsocket rw in List.from(channels.values)) {
      if (rw.channel != null && rw.isConnected()) {
        res.add(rw.relay.url);
      }
    }
    return res;
  }

  /// Maps a WebSocket [ConnectionState] to an [EventSendEnum] send status code.
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

  /// Subscribes to events for [pubkeys] of specified [kinds] on all (or given) relays.
  ///
  /// Shows a toast if all relays are disconnected.
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

  /// Subscribes to NIP-17 (gift-wrap, kind 1059) events for [pubkeys].
  ///
  /// Returns the [NostrReqModel] sent, or null if [pubkeys] is empty.
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

  /// Loads relay message and file fee configurations from local storage into memory.
  ///
  /// Called on [onReady] to restore fee settings cached from the last relay info fetch.
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
        relayMessageFeeModels[host] = RelayMessageFee.fromJson(
          entry.value as Map<String, dynamic>,
        );
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
        relayFileFeeModels[host] = RelayFileFee.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }
  }

  @override
  void onReady() {
    super.onReady();
    localFeesConfigFromLocalStorage();
    RelayService.instance.refreshRelayInfo();
  }

  /// Recomputes and updates [mainRelayStatus] and [relayConnectedCount] based on current connections.
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

  /// Removes a single [pubkey] from all active relay subscription sets.
  ///
  /// Used when a contact is removed or a room is closed to stop receiving their events.
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

  /// Removes multiple [keys] pubkeys from the first subscription slot of each relay.
  void removePubkeysFromSubscription(List<String> keys) {
    for (final rw in channels.values) {
      final subs = rw.subscriptions;
      for (final entry in subs.entries) {
        subs[entry.key]?.removeAll(keys);
        break;
      }
    }
  }

  /// Returns the subscription ID that currently tracks [pubkey], or null if not subscribed.
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

  /// Broadcasts a raw REQ/CLOSE/EVENT string to all (or given) connected relays.
  ///
  /// Returns the number of relays the message was sent to.
  /// Throws if no relays are connected.
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

  /// Sends a raw EVENT string and registers an optional OK [callback] for acknowledgment.
  ///
  /// If [relays] is specified, sends only to those relays; otherwise broadcasts to all connected.
  /// The [callback] is called when the relay sends an OK response for the event ID.
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
          NostrAPI.instance.setOKCallback(list[1]['id'] as String, callback);
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

  /// Sends a [NostrReqModel] REQ to all (or given) relays using slot-limited subscriptions.
  ///
  /// Invokes [callback] for each relay the REQ is successfully sent to.
  /// Throws 'RelayDisconnected' if no relay accepts the request.
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
    }
  }

  /// Starts or restarts all relay WebSocket connections.
  ///
  /// Clears existing connection state and creates fresh channels for all relays in [list].
  /// Uses [startLock] to prevent concurrent starts.
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

  /// Closes all relay WebSocket channels and clears connection state.
  ///
  /// Cancels all stream subscriptions to prevent memory leaks before reconnecting.
  Future<void> stopListening() async {
    for (final rw in channels.values) {
      // Clean up all subscriptions before closing
      rw.cleanupSubscriptions();
      rw.channel?.close();
    }
    channels.clear();
    _backoffStates.clear();
  }

  /// Publishes a Nostr event to connected relays and returns the set of relay URLs it was sent to.
  ///
  /// Attaches a Cashu ecash token if the relay requires payment.
  /// Adds the message to the retry queue for acknowledgment tracking.
  /// Throws if no active or connected relays are available.
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
      return rw != null && rw.isConnected() && rw.supportsKind(event.kind);
    }).toList();
    if (connectedRelays.isEmpty) {
      throw Exception('No connected relay supports kind ${event.kind}');
    }
    logger.d('try write event: $roomId, $eventString, $connectedRelays');
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

    /// Store message subscription to enable proper cleanup.
    /// Saves reference so we can cancel it when reconnecting.
    rw.messagesSubscription = rw.channel!.messages.listen(
      (message) {
        nostrAPI.addNostrEventToQueue(rw.relay, message);
      },
      onError: (dynamic error, dynamic stackTrace) {
        logger.e(
          'WebSocket message error for ${rw.relay.url}',
          error: error,
          stackTrace: stackTrace is StackTrace ? stackTrace : null,
        );
      },
    );

    /// Store connection state subscription to enable proper cleanup.
    /// Prevents zombie subscribers in long-running sessions.
    rw.connectionStateSubscription = rw.channel!.connection.listen(
      (ConnectionState state) {
        final backoff = getBackoffState(rw.relay.url);

        if (state is Connected || state is Reconnected) {
          backoff.recordSuccess();
          logger.i('Relay connected: ${rw.relay.url}');
          rw.connectSuccess();
          if (connectedCallback != null) {
            connectedCallback();
          }
          // Retry pending messages for this relay
          unawaited(
            MessageRetryService.instance.retryPendingMessages(rw.relay.url),
          );
        } else if (state is Disconnected) {
          backoff.recordFailure();
          logger.w(
            'Relay disconnected: ${rw.relay.url}, failures: ${backoff.failureCount}',
          );

          // Circuit breaker: cleanup if too many failures
          if (backoff.failureCount >= 5) {
            logger.e(
              'Relay ${rw.relay.url} exceeded failure threshold (5), activating circuit breaker',
            );
            rw.cleanupSubscriptions();
          }
        }

        // update the main page status
        unawaited(refreshMainRelayStatus());
      },
      onError: (dynamic error, dynamic stackTrace) {
        getBackoffState(rw.relay.url).recordFailure();
        logger.e(
          'WebSocket connection state error for ${rw.relay.url}',
          error: error,
          stackTrace: stackTrace is StackTrace ? stackTrace : null,
        );
        unawaited(refreshMainRelayStatus());
      },
    );

    return rw;
  }

  /// Ensures the given relays are in the channel pool and connected.
  ///
  /// [relays] - relay URLs to ensure. If null/empty, uses all current channels.
  /// Returns the list of connected relay URLs (filtered by [relays] if provided).
  Future<List<String>> ensureRelaysConnected([List<String>? relays]) async {
    final targetRelays = (relays != null && relays.isNotEmpty)
        ? relays
        : channels.keys.toList();

    // Step 1: Add missing relays
    for (final url in targetRelays) {
      if (!channels.containsKey(url)) {
        try {
          await RelayService.instance.addAndConnect(url);
        } catch (e) {
          logger.e('Failed to add relay $url: $e');
        }
      }
    }

    // Step 2: Check if any target relay is already connected
    final connected = targetRelays
        .where((url) => channels[url]?.isConnected() ?? false)
        .toList();
    if (connected.isNotEmpty) return connected;

    // Step 3: None connected, trigger reconnect and wait
    final rwList = targetRelays
        .map((url) => channels[url])
        .whereType<RelayWebsocket>()
        .toList();
    if (rwList.isNotEmpty) {
      try {
        await checkOnlineAndConnect(list: rwList);
      } catch (e) {
        logger.e('ensureRelaysConnected reconnect error: $e');
      }
    }
    await Future<void>.delayed(const Duration(seconds: 2));

    // Step 4: Return currently connected relays (filtered by input)
    if (relays != null && relays.isNotEmpty) {
      return relays
          .where((url) => channels[url]?.isConnected() ?? false)
          .toList();
    }
    return getOnlineSocketString();
  }

  /// Records a pong response from [relay], used by [RelayWebsocket.checkOnlineStatus].
  void updateRelayPong(String relay) {
    if (channels[relay] != null) {
      channels[relay]!.pong = true;
    }
  }

  /// Re-initializes the WebSocket service from persistent relay configuration.
  ///
  /// Equivalent to a full service restart: reloads relays from DB and reconnects all channels.
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

  /// Get connection health status for all relays.
  /// Useful for debugging and monitoring connection quality.
  Map<String, Map<String, dynamic>> getConnectionHealth() {
    return Map.fromEntries(
      channels.entries.map((entry) {
        final backoff = getBackoffState(entry.key);
        return MapEntry(entry.key, {
          'connected': entry.value.isConnected(),
          'failures': backoff.failureCount,
          'lastSuccess': backoff.lastSuccess?.toIso8601String(),
          'isHealthy': backoff.isHealthy(),
          'nextRetry': backoff.shouldAttempt()
              ? 'now'
              : backoff.lastAttempt!
                    .add(backoff.getBackoffDuration())
                    .toIso8601String(),
        });
      }),
    );
  }
}
