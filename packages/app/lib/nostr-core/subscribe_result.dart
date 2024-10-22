import 'package:app/nostr-core/nostr_event.dart';

class SubscribeResult {
  static SubscribeResult? _instance;
  // Avoid self instance
  SubscribeResult._();
  static SubscribeResult get instance => _instance ??= SubscribeResult._();

  final Map<String, List> _map = {};
  final Map<String, int> _eventMaxRelay = {};

  Future<NostrEventModel?> registerSubscripton(
      String eventId, int maxRelay, Duration wait) async {
    if (maxRelay <= 0) {
      throw Exception('Relay maybe disconnected');
    }
    _eventMaxRelay[eventId] = maxRelay;
    final deadline = DateTime.now().add(wait);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (isFilled(eventId)) {
        return removeSubscripton(eventId);
      }
    }
    return removeSubscripton(eventId);
  }

  fill(String eventId, NostrEventModel nem) {
    List list = _map[eventId] ?? <NostrEventModel>[];
    list.add(nem);
    _map[eventId] = list;
  }

  bool isFilled(String eventId) {
    return (_map[eventId] ?? <NostrEventModel>[]).length >=
        (_eventMaxRelay[eventId] ?? 0);
  }

  NostrEventModel? removeSubscripton(String eventId) {
    List list = _map[eventId] ?? <NostrEventModel>[];
    _map.remove(eventId);

    if (list.isEmpty) {
      return null;
    }
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list.last;
  }
}
