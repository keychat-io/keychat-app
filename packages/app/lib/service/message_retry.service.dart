import 'dart:async';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:get/get.dart';

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
    // Exponential backoff: 2s, 4s, 8s, 16s
    return Duration(seconds: 2 * (1 << retryCount));
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
        'retryPendingMessages:$relay', const Duration(seconds: 5), () async {
      final pendingItems = _retryQueue.entries
          .where((entry) => entry.value.relay == relay && entry.value.canRetry)
          .toList();

      for (final entry in pendingItems) {
        await _retryMessage(entry.key);
      }
    });
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
}
