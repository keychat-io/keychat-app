import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-CBC encryption helper for wallet connection URIs.
///
/// The AES key is generated once and stored in FlutterSecureStorage (OS keychain).
/// This allows bulk connection data to live in Isar (queryable, structured)
/// while keeping secrets encrypted at rest.
class WalletConnectionCrypto {
  WalletConnectionCrypto._();
  static WalletConnectionCrypto? _instance;
  static WalletConnectionCrypto get instance =>
      _instance ??= WalletConnectionCrypto._();

  static const String _keyStorageKey = 'wallet_connection_encryption_key';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(
      synchronizable: true,
      accessibility: KeychainAccessibility.first_unlock,
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  encrypt.Encrypter? _cachedEncrypter;

  /// Gets or creates the AES-256-CBC Encrypter, caching both the key and
  /// the Encrypter instance to avoid repeated object allocation.
  Future<encrypt.Encrypter> _getEncrypter() async {
    if (_cachedEncrypter != null) return _cachedEncrypter!;

    final stored = await _secureStorage.read(key: _keyStorageKey);
    encrypt.Key key;
    if (stored != null) {
      key = encrypt.Key.fromBase64(stored);
    } else {
      // Generate a new random 256-bit key
      final random = Random.secure();
      final keyBytes =
          Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
      key = encrypt.Key(keyBytes);

      await _secureStorage.write(
        key: _keyStorageKey,
        value: key.base64,
      );
    }

    _cachedEncrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    return _cachedEncrypter!;
  }

  /// Encrypts plaintext using AES-256-CBC.
  ///
  /// Returns a base64 string in format: iv:ciphertext
  Future<String> encryptText(String plaintext) async {
    final encrypter = await _getEncrypter();
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts a string produced by [encryptText].
  Future<String> decryptText(String ciphertext) async {
    final encrypter = await _getEncrypter();
    final parts = ciphertext.split(':');
    if (parts.length != 2) {
      throw const FormatException('Invalid encrypted format');
    }
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    return encrypter.decrypt(encrypted, iv: iv);
  }
}
