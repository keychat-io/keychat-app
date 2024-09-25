import 'dart:convert';

class SubscribeResult {
  static SubscribeResult? _instance;
  // Avoid self instance
  SubscribeResult._();
  static SubscribeResult get instance => _instance ??= SubscribeResult._();

  final Map<String, List> _map = {};
  final Map<String, int> _eventMaxRelay = {};

  Future<dynamic> registerSubscripton(
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

  fill(String eventId, String data) {
    List list = _map[eventId] ?? [];
    list.add(data);
    _map[eventId] = list;
  }

  bool isFilled(String eventId) {
    List list = _map[eventId] ?? [];
    return list.length >= (_eventMaxRelay[eventId] ?? 0);
  }

  dynamic removeSubscripton(String eventId) {
    List list = _map[eventId] ?? [];
    _map.remove(eventId);

    if (list.isEmpty) {
      return null;
    }

    list = list.map((e) => jsonDecode(e)).toList();
    list = list.where((e) => e['created_at'] != null).toList();
    if (list.isEmpty) return jsonDecode(list.last);
    list.sort((a, b) => a['created_at'].compareTo(b['created_at']));
    return list.last;
  }
}
