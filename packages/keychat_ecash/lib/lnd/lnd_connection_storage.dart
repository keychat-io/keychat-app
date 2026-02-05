import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keychat_ecash/lnd/lnd_connection_info.dart';

/// Persists LND connections to secure storage.
class LndConnectionStorage {
  LndConnectionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'lnd_connections_list';
  final FlutterSecureStorage _storage;

  /// Get all saved LND connections.
  Future<List<LndConnectionInfo>> getAll() async {
    final jsonString = await _storage.read(key: _storageKey);
    if (jsonString == null) {
      return [];
    }
    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((e) => LndConnectionInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // In case of corrupted data, return empty list
      return [];
    }
  }

  /// Save the full list of connections.
  Future<void> save(List<LndConnectionInfo> list) async {
    final jsonString = jsonEncode(list.map((e) => e.toJson()).toList());
    await _storage.write(key: _storageKey, value: jsonString);
  }

  /// Add a new connection.
  ///
  /// Throws if connection with same URI already exists.
  Future<void> add(LndConnectionInfo info) async {
    final list = await getAll();
    if (list.any((element) => element.uri == info.uri)) {
      throw Exception('Connection with this URI already exists');
    }
    list.add(info);
    await save(list);
  }

  /// Update an existing connection.
  Future<void> update(LndConnectionInfo info) async {
    final list = await getAll();
    final index = list.indexWhere((element) => element.uri == info.uri);
    if (index == -1) {
      throw Exception('Connection not found');
    }
    list[index] = info;
    await save(list);
  }

  /// Delete a connection by URI.
  Future<void> delete(String uri) async {
    final list = await getAll();
    list.removeWhere((element) => element.uri == uri);
    await save(list);
  }
}
