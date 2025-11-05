import 'dart:async';
import 'package:keychat/models/models.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:mutex/mutex.dart';

class MessageRetryItem {
  MessageRetryItem({
    required this.eventId,
    required this.relay,
    required this.rawEvent,
    required this.roomId,
    required this.createdAt,
    this.retryCount = 0,
  });

  final String eventId;
  final String relay;
  final String rawEvent;
  final int roomId;
  final DateTime createdAt;
  int retryCount;
  Timer? timeoutTimer;
  DateTime? lastRetryAt;

  bool get canRetry => retryCount < 4;

  Duration get nextRetryDelay {
    // Exponential backoff: 3s, 6s, 12s, 24s
    return Duration(seconds: 3 * (1 << retryCount));
  }
}

class MessageRetryService extends GetxService {
  MessageRetryService._();
  static MessageRetryService? _instance;
  static MessageRetryService get instance =>
      _instance ??= MessageRetryService._();

  // Key: "eventId:relay"
  final Map<String, MessageRetryItem> _retryQueue = {};
  final Map<String, Set<String>> _eventRelays = {}; // eventId -> Set<relay>
  final _fillSubscriptionMutex = Mutex();

  void addMessage({
    required String eventId,
    required String relay,
    required String rawEvent,
    required int roomId,
  }) {
    final key = _getKey(eventId, relay);

    // Track relays for this event
    _eventRelays.putIfAbsent(eventId, () => {}).add(relay);

    final item = MessageRetryItem(
      eventId: eventId,
      relay: relay,
      rawEvent: rawEvent,
      roomId: roomId,
      createdAt: DateTime.now(),
    );

    _retryQueue[key] = item;

    // Set timeout timer (5 seconds)
    item.timeoutTimer = Timer(const Duration(seconds: 5), () {
      _handleTimeout(key);
    });

    loggerNoLine.d('Added message to retry queue: $eventId -> $relay');
  }

  void markSuccess(String eventId, String relay) {
    final key = _getKey(eventId, relay);
    final item = _retryQueue[key];

    if (item != null) {
      item.timeoutTimer?.cancel();
      _retryQueue.remove(key);
      loggerNoLine.d('Message sent successfully: $eventId -> $relay');
    }

    // Clean up event relay tracking
    _eventRelays[eventId]?.remove(relay);
    if (_eventRelays[eventId]?.isEmpty ?? false) {
      _eventRelays.remove(eventId);
    }
  }

  Future<void> retryPendingMessages(String relay) async {
    EasyThrottle.throttle(
      'retryPendingMessages:$relay',
      const Duration(seconds: 5),
      () async {
        final pendingItems = _retryQueue.entries
            .where(
              (entry) => entry.value.relay == relay && entry.value.canRetry,
            )
            .toList();

        for (final entry in pendingItems) {
          await _retryMessage(entry.key);
        }
      },
    );
  }

  void clearEventMessages(String eventId) {
    final relays = _eventRelays[eventId];
    if (relays != null) {
      for (final relay in relays.toList()) {
        final key = _getKey(eventId, relay);
        final item = _retryQueue[key];
        item?.timeoutTimer?.cancel();
        _retryQueue.remove(key);
      }
      _eventRelays.remove(eventId);
    }
  }

  List<MessageRetryItem> getPendingMessages() {
    return _retryQueue.values.toList();
  }

  void _handleTimeout(String key) {
    final item = _retryQueue[key];
    if (item == null) return;

    loggerNoLine.w(
      'Message timeout: ${item.eventId} -> ${item.relay}, retry: ${item.retryCount}',
    );
    _scheduleRetry(key);
  }

  void _scheduleRetry(String key) {
    final item = _retryQueue[key];
    if (item == null || !item.canRetry) {
      if (item != null && !item.canRetry) {
        loggerNoLine.e(
          'Message max retries reached: ${item.eventId} -> ${item.relay}',
        );
        _retryQueue.remove(key);
      }
      return;
    }

    final delay = item.nextRetryDelay;
    item.retryCount++;
    item.lastRetryAt = DateTime.now();

    loggerNoLine.d(
      'Scheduling retry for ${item.eventId} -> ${item.relay} in ${delay.inSeconds}s (attempt ${item.retryCount}/4)',
    );

    Timer(delay, () => _retryMessage(key));
  }

  Future<void> _retryMessage(String key) async {
    final item = _retryQueue[key];
    if (item == null) return;

    try {
      // Import WebsocketService to avoid circular dependency
      final ws = Get.find<WebsocketService>();

      // Check if relay is connected
      if (ws.channels[item.relay]?.isConnected() != true) {
        loggerNoLine.w(
          'Relay not connected for retry: ${item.relay}, will retry later',
        );
        return;
      }

      loggerNoLine.d('Retrying message: ${item.eventId} -> ${item.relay}');

      // Send message
      ws.channels[item.relay]!.sendRawREQ(item.rawEvent);

      // Reset timeout timer
      item.timeoutTimer?.cancel();
      item.timeoutTimer = Timer(const Duration(seconds: 5), () {
        _handleTimeout(key);
      });
    } catch (e) {
      loggerNoLine.e('Retry failed: ${item.eventId} -> ${item.relay}: $e');
      _scheduleRetry(key);
    }
  }

  String _getKey(String eventId, String relay) => '$eventId:$relay';

  void clear() {
    for (final item in _retryQueue.values) {
      item.timeoutTimer?.cancel();
    }
    _retryQueue.clear();
    _eventRelays.clear();
  }

  Map<String, Set<NostrEventStatus>> essMap = <String, Set<NostrEventStatus>>{};
  Map<String, DateTime> essAddTime = <String, DateTime>{};
  int fillSubscriptionCount = 0;

  void addNostrEventStatus(NostrEventStatus ess) {
    final set = essMap[ess.eventId] ?? <NostrEventStatus>{}
      ..add(ess);
    essMap[ess.eventId] = set;
    essAddTime[ess.eventId] = DateTime.now();
  }

  Future<void> fillSubscription({
    required String eventId,
    required String relay,
    required bool isSuccess,
    String? errorMessage,
  }) async {
    markSuccess(eventId, relay); // remove retry send

    await _fillSubscriptionMutex.protect(() async {
      loggerNoLine.i(
        'Filling subscription for event $eventId on relay $relay: '
        'success=$isSuccess, error=$errorMessage',
      );
      fillSubscriptionCount++;
      final essSet = essMap[eventId];
      if (essSet == null) return;
      final es = essSet.where((element) => element.relay == relay).firstOrNull;
      if (es == null) return;
      if (isSuccess) {
        es.sendStatus = EventSendEnum.success;
      } else {
        es
          ..sendStatus = EventSendEnum.serverReturnFailed
          ..error = errorMessage;
      }

      await DBProvider.database.writeTxn(() async {
        await DBProvider.database.nostrEventStatus.put(es);
      });

      final message = await DBProvider.database.messages
          .filter()
          .eventIdsElementContains(eventId)
          .findFirst();
      if (message == null) return;
      final sentSuccessRelay = essSet
          .where((element) => element.sendStatus == EventSendEnum.success)
          .length;

      if (sentSuccessRelay > message.successRelays) {
        message
          ..sent = sentSuccessRelay > 0
              ? SendStatusType.success
              : SendStatusType.failed
          ..successRelays = sentSuccessRelay;
        EasyDebounce.debounce(
          'updateMessageAndRefresh${message.id}',
          const Duration(milliseconds: 200),
          () async {
            await MessageService.instance.updateMessageAndRefresh(message);
          },
        );
      }

      // clear old subscriptions
      if (fillSubscriptionCount % 30 == 0) {
        _clearOneMinutesOldSubscriptions();
      }
    });
  }

  void _clearOneMinutesOldSubscriptions() {
    final now = DateTime.now();
    final toRemove = essAddTime.entries
        .where((entry) => now.difference(entry.value).inMinutes >= 1)
        .map((entry) => entry.key)
        .toList();

    for (final eventId in toRemove) {
      essMap.remove(eventId);
      essAddTime.remove(eventId);
    }
  }
}
