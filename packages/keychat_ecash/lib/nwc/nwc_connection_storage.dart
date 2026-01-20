import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keychat_ecash/nwc/nwc_connection_info.dart';

class NwcConnectionStorage {
  NwcConnectionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  static const _storageKey = 'nwc_connections_list';
  final FlutterSecureStorage _storage;

  Future<List<NwcConnectionInfo>> getAll() async {
    final jsonString = await _storage.read(key: _storageKey);
    if (jsonString == null) {
      return [];
    }
    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((e) => NwcConnectionInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // In case of corrupted data, return empty list or handle error
      return [];
    }
  }

  Future<void> save(List<NwcConnectionInfo> list) async {
    final jsonString = jsonEncode(list.map((e) => e.toJson()).toList());
    await _storage.write(key: _storageKey, value: jsonString);
  }

  Future<void> add(NwcConnectionInfo info) async {
    final list = await getAll();
    if (list.any((element) => element.uri == info.uri)) {
      throw Exception('Connection with this URI already exists');
    }
    list.add(info);
    await save(list);
  }

  Future<void> update(NwcConnectionInfo info) async {
    final list = await getAll();
    final index = list.indexWhere((element) => element.uri == info.uri);
    if (index == -1) {
      throw Exception('Connection not found');
    }
    list[index] = info;
    await save(list);
  }

  Future<void> delete(String uri) async {
    final list = await getAll();
    list.removeWhere((element) => element.uri == uri);
    await save(list);
  }
}
