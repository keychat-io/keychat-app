import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static SecureStorage? _instance;
  // Avoid self instance
  SecureStorage._();
  static SecureStorage get instance => _instance ??= SecureStorage._();
  static FlutterSecureStorage storage = const FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock));

  String mnemonicKey = 'mnemonic';
  static Map<String, String> keys = {};

  Future writePhraseWords(String words) async {
    await storage.write(key: mnemonicKey, value: words);
  }

  Future<String?> getPhraseWords() async {
    return await storage.read(key: mnemonicKey);
  }

  Future writePrikey(String pubkey, String prikey) async {
    await storage.write(key: _getPrivateKeyName(pubkey), value: prikey);
    keys[pubkey] = prikey;
  }

  Future<String?> readPrikey(String pubkey) async {
    if (keys.containsKey(pubkey)) {
      return keys[pubkey];
    }
    var res = await storage.read(key: _getPrivateKeyName(pubkey));
    if (res != null) {
      keys[pubkey] = res; // store in memory
    }
    return res;
  }

  Future<String> readPrikeyOrFail(String pubkey) async {
    if (keys.containsKey(pubkey)) {
      return keys[pubkey]!;
    }
    var res = await storage.read(key: _getPrivateKeyName(pubkey));
    if (res != null) {
      keys[pubkey] = res; // store in memory
      return res;
    }
    throw Exception('$pubkey \'s private key not found');
  }

  String _getPrivateKeyName(String pubkey) => "prikey:$pubkey";

  Future<Map<String, String>> readAll() {
    return storage.readAll();
  }

  Future deletePrikey(String pubkey) async {
    String key = _getPrivateKeyName(pubkey);
    await storage.delete(key: key);
  }

  Future clearAll() async {
    await storage.deleteAll();
  }

  // Future deleteMnemonic(String pubkey) async {
  //   await storage.delete(key: pubkey);
  // }
}
