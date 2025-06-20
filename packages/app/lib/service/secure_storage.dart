import 'package:app/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app/utils/config.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class SecureStorage {
  static SecureStorage? _instance;
  // Avoid self instance
  SecureStorage._();
  static SecureStorage get instance => _instance ??= SecureStorage._();
  static const FlutterSecureStorage storage = FlutterSecureStorage(
      mOptions: MacOsOptions(
        synchronizable: true,
        accessibility: KeychainAccessibility.first_unlock,
      ),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock));

  String mnemonicKey = kReleaseMode ? 'mnemonic' : '${Config.env}:mnemonic';
  static Map<String, String> keys = {};

  Future write(String key, String value) async {
    await storage.write(key: key, value: value);
    keys[key] = value;
  }

  Future writePhraseWordsWhenNotExist(String words) async {
    String? exist = await getPhraseWords();
    if (exist == null) {
      await storage.write(key: mnemonicKey, value: words);
    }
  }

  Future<String?> getPhraseWords() async {
    return await storage.read(key: mnemonicKey);
  }

  Future<String?> readPrikey(String pubkey) async {
    if (keys.containsKey(pubkey)) {
      return keys[pubkey];
    }
    String? res = await storage.read(key: _getPrivateKeyName(pubkey));
    res ??= await storage.read(key: pubkey);
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
    res ??= await storage.read(key: pubkey);
    if (res != null && res.isNotEmpty) {
      keys[pubkey] = res; // store in memory
      return res;
    }

    // restore from mnemonic
    String? prikey = await _restoreSecp256k1Prikey(pubkey);
    if (prikey != null && prikey.isNotEmpty) {
      return prikey;
    }

    throw Exception('$pubkey \'s private key not found');
  }

  Future<String?> _restoreSecp256k1Prikey(String secp256k1PKHex) async {
    String? mnemonic = await getPhraseWords();
    if (mnemonic == null || mnemonic.isEmpty) {
      return null;
    }

    try {
      List<rust_nostr.Secp256k1Account> list = await rust_nostr
          .importFromPhraseWith(phrase: mnemonic, offset: 0, count: 10);
      for (var account in list) {
        if (account.pubkey == secp256k1PKHex) {
          await write(account.pubkey, account.prikey);
          return account.prikey;
        }
      }
    } catch (e) {
      logger.e('Failed to import accounts: ${Utils.getErrorMessage(e)}');
    }
    return null;
  }

  Future<String> readCurve25519PrikeyOrFail(String pubkey) async {
    if (keys.containsKey(pubkey)) {
      return keys[pubkey]!;
    }
    var res = await storage.read(key: _getPrivateKeyName(pubkey));
    res ??= await storage.read(key: pubkey);
    if (res != null && res.isNotEmpty) {
      keys[pubkey] = res;
      return res;
    }
    throw Exception('$pubkey \'s private key not found');
  }

  @Deprecated('Use pubkey instead')
  String _getPrivateKeyName(String pubkey) {
    if (kReleaseMode) {
      return "prikey:$pubkey";
    }
    return "${Config.env}:prikey:$pubkey";
  }

  Future<Map<String, String>> readAll() {
    return storage.readAll();
  }

  Future<void> deletePrikey(String pubkey) async {
    String key = _getPrivateKeyName(pubkey);
    keys.remove(pubkey);
    await storage.delete(key: key);
    await storage.delete(key: pubkey);
  }

  // in debug model, if you open multi clients, all of them share the same keychain
  Future<void> clearAll([bool force = false]) async {
    if (force || kReleaseMode) {
      await storage.deleteAll(
          iOptions: const IOSOptions(
              accessibility: KeychainAccessibility.first_unlock));
    }
    await storage.delete(
        key: mnemonicKey,
        iOptions: const IOSOptions(
            accessibility: KeychainAccessibility.first_unlock));
  }
}
