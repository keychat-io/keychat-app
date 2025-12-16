import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keychat/utils.dart';
import 'package:keychat/utils/config.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class SecureStorage {
  // Avoid self instance
  SecureStorage._();
  static SecureStorage? _instance;
  static SecureStorage get instance => _instance ??= SecureStorage._();
  static const FlutterSecureStorage storage = FlutterSecureStorage(
    mOptions: MacOsOptions(
      synchronizable: true,
      accessibility: KeychainAccessibility.first_unlock,
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String mnemonicKey = kReleaseMode ? 'mnemonic' : '${Config.env}:mnemonic';
  String pinKey = 'APP_PIN_HASH';
  String biometricsStatusKey = 'APP_BIOMETRICS_STATUS';

  static Map<String, String> keys = {};

  Future<void> write(String key, String value) async {
    await storage.write(key: key, value: value);
    keys[key] = value;
  }

  Future<String?> read(String key) async {
    return storage.read(key: key);
  }

  Future<void> writePhraseWordsWhenNotExist(String words) async {
    final exist = await getPhraseWords();
    if (exist == null) {
      await storage.write(key: mnemonicKey, value: words);
    }
  }

  Future<String?> getPhraseWords() async {
    return storage.read(key: mnemonicKey);
  }

  Future<String> getOrCreatePhraseWords() async {
    var words = await getPhraseWords();
    if (words == null) {
      final account = await rust_nostr.generateFromMnemonic();
      words = account.mnemonic;
    }
    if (words == null) {
      throw Exception('Failed to generate mnemonic phrase');
    }
    await writePhraseWordsWhenNotExist(words);
    return words;
  }

  Future<String?> readPrikey(String pubkey) async {
    if (keys.containsKey(pubkey)) {
      return keys[pubkey];
    }
    var res = await storage.read(key: _getPrivateKeyName(pubkey));
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
    final prikey = await _restoreSecp256k1Prikey(pubkey);
    if (prikey != null && prikey.isNotEmpty) {
      return prikey;
    }

    throw Exception("$pubkey 's private key not found");
  }

  Future<String?> _restoreSecp256k1Prikey(String secp256k1PKHex) async {
    final mnemonic = await getPhraseWords();
    if (mnemonic == null || mnemonic.isEmpty) {
      return null;
    }

    try {
      final list = await rust_nostr.importFromPhraseWith(
        phrase: mnemonic,
        offset: 0,
        count: 10,
      );
      for (final account in list) {
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
    throw Exception("$pubkey 's private key not found");
  }

  @Deprecated('Use pubkey instead')
  String _getPrivateKeyName(String pubkey) {
    if (kReleaseMode) {
      return 'prikey:$pubkey';
    }
    return '${Config.env}:prikey:$pubkey';
  }

  Future<Map<String, String>> readAll() {
    return storage.readAll();
  }

  Future<void> deletePrikey(String pubkey) async {
    final key = _getPrivateKeyName(pubkey);
    keys.remove(pubkey);
    await storage.delete(key: key);
    await storage.delete(key: pubkey);
  }

  // in debug model, if you open multi clients, all of them share the same keychain
  Future<void> clearAll([bool force = false]) async {
    if (force || kReleaseMode) {
      await storage.deleteAll(
        iOptions: const IOSOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );
    }
    await storage.delete(
      key: mnemonicKey,
      iOptions: const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
  }

  Future<void> setBiometrics(bool status) async {
    if (status) {
      await storage.write(
        key: biometricsStatusKey,
        value: (status ? 1 : 0).toString(),
      );
      return;
    }
    await storage.delete(key: biometricsStatusKey);
  }

  Future<bool> isBiometricsEnable() async {
    final value = await storage.read(key: biometricsStatusKey);
    return value == '1';
  }

  Future<String> _hashPin(String pin) async {
    final hash = await rust_nostr.sha256Hash(data: pin);
    return hash;
  }

  Future<bool> hasPinCode() async {
    final pinHash = await storage.read(key: pinKey);
    return pinHash != null && pinHash.isNotEmpty;
  }

  Future<void> savePinCode(String pin) async {
    final hashedPin = await _hashPin(pin);
    await storage.write(key: pinKey, value: hashedPin);
  }

  Future<bool> verifyPinCode(String pin) async {
    final storedHash = await storage.read(key: pinKey);
    if (storedHash == null) return false;

    final inputHash = await _hashPin(pin);
    return storedHash == inputHash;
  }

  Future<void> deletePinCode() async {
    await storage.delete(key: pinKey);
  }
}
