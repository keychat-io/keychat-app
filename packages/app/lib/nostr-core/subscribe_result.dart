import 'package:app/nostr-core/nostr_event.dart';

class SubscribeResult {
  // Avoid self instance
  SubscribeResult._();
  static SubscribeResult? _instance;
  static SubscribeResult get instance => _instance ??= SubscribeResult._();

  final Map<String, List> _map = {};
  final Map<String, int> _eventMaxRelay = {};

  /// waitTimeToFill: fill the subscription after the wait time
  Future<List<NostrEventModel>> registerSubscripton(String subId, int maxRelay,
      {Duration wait = const Duration(seconds: 2),
      bool waitTimeToFill = false}) async {
    if (maxRelay <= 0) {
      throw Exception('Relay maybe disconnected');
    }
    _eventMaxRelay[subId] = maxRelay;
    final deadline = DateTime.now().add(wait);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!waitTimeToFill && isFilled(subId)) {
        return removeSubscripton(subId);
      }
    }
    return removeSubscripton(subId);
  }

  void fill(String subId, NostrEventModel nem) {
    final list = _map[subId] ?? <NostrEventModel>[];
    list.add(nem);
    _map[subId] = list;
  }

  bool isFilled(String subId) {
    return (_map[subId] ?? <NostrEventModel>[]).length >=
        (_eventMaxRelay[subId] ?? 0);
  }

  List<NostrEventModel> removeSubscripton(String subId) {
    var list = _map[subId] ?? <NostrEventModel>[];
    _map.remove(subId);
    // Filter out events with the same ID (keep only the first occurrence)
    final uniqueEvents = <String>{};
    list = list.where((event) {
      final model = event as NostrEventModel;
      if (uniqueEvents.contains(model.id)) {
        return false;
      }
      uniqueEvents.add(model.id);
      return true;
    }).toList();
    // from min to max
    list.sort((a, b) => (a as NostrEventModel)
        .createdAt
        .compareTo((b as NostrEventModel).createdAt));
    return list as List<NostrEventModel>;
  }
}
