import 'dart:async';

import 'package:keychat_ecash/nwc/nwc_models.dart';

/// Manages pending NWC requests and matches them with responses.
///
/// Uses singleton pattern to ensure a single instance manages all requests.
class NwcRequestManager {
  NwcRequestManager._();

  static NwcRequestManager? _instance;

  /// Returns the singleton instance.
  static NwcRequestManager get instance => _instance ??= NwcRequestManager._();

  /// Map of pending requests by event ID.
  final Map<String, Completer<NwcResponse>> _pendingRequests = {};

  /// Map of timeout timers by event ID.
  final Map<String, Timer> _timeoutTimers = {};

  /// Default timeout duration for requests (30 seconds).
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Registers a new pending request.
  ///
  /// Returns a Future that completes when the response is received
  /// or times out after [timeout] duration.
  Future<NwcResponse> registerRequest(
    String eventId, {
    Duration timeout = defaultTimeout,
  }) {
    // Clean up any existing request with same ID
    _cleanupRequest(eventId);

    final completer = Completer<NwcResponse>();
    _pendingRequests[eventId] = completer;

    // Set up timeout
    _timeoutTimers[eventId] = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('NWC request timed out', timeout),
        );
        _cleanupRequest(eventId);
      }
    });

    return completer.future;
  }

  /// Completes a pending request with the given response.
  ///
  /// Returns true if the request was found and completed, false otherwise.
  bool completeRequest(String eventId, NwcResponse response) {
    final completer = _pendingRequests[eventId];
    if (completer == null || completer.isCompleted) {
      return false;
    }

    completer.complete(response);
    _cleanupRequest(eventId);
    return true;
  }

  /// Completes a pending request with an error.
  ///
  /// Returns true if the request was found and completed, false otherwise.
  bool completeRequestWithError(String eventId, Object error) {
    final completer = _pendingRequests[eventId];
    if (completer == null || completer.isCompleted) {
      return false;
    }

    completer.completeError(error);
    _cleanupRequest(eventId);
    return true;
  }

  /// Checks if there's a pending request with the given event ID.
  bool hasPendingRequest(String eventId) {
    return _pendingRequests.containsKey(eventId);
  }

  /// Gets the number of pending requests.
  int get pendingCount => _pendingRequests.length;

  /// Cleans up a request and its timeout timer.
  void _cleanupRequest(String eventId) {
    _timeoutTimers[eventId]?.cancel();
    _timeoutTimers.remove(eventId);
    _pendingRequests.remove(eventId);
  }

  /// Cancels all pending requests.
  void cancelAll() {
    for (final eventId in _pendingRequests.keys.toList()) {
      final completer = _pendingRequests[eventId];
      if (completer != null && !completer.isCompleted) {
        completer.completeError(Exception('Request cancelled'));
      }
      _cleanupRequest(eventId);
    }
  }

  /// Resets the manager (useful for testing).
  void reset() {
    cancelAll();
    _pendingRequests.clear();
    _timeoutTimers.clear();
  }
}
