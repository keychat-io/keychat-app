import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/keychat/qrcode_user_model.dart';

void main() {
  /// Shared sample values used across all QRUserModel tests.
  const name = 'Alice';
  const relay = 'wss://relay.example.com';
  const nostrIdentityKey = 'nostr_identity_key_hex';
  const signalIdentityKey = 'signal_identity_key_hex';
  const receiveAddress = 'receive_address_hex';
  const signalSignedPrekeyId = 42;
  const signalSignedPrekey = 'signed_prekey_hex';
  const signalSignedPrekeySignature = 'signed_prekey_sig_hex';
  const signalOneTimePrekeyId = 7;
  const signalOneTimePrekey = 'one_time_prekey_hex';
  const globalSign = 'global_sign_value';
  const time = 1700000000;

  /// Builds a JSON map using the NEW (v2) field names.
  Map<String, dynamic> newFieldJson() => {
        'name': name,
        'relay': relay,
        'nostrIdentityKey': nostrIdentityKey,
        'signalIdentityKey': signalIdentityKey,
        'receiveAddress': receiveAddress,
        'signalSignedPrekeyId': signalSignedPrekeyId,
        'signalSignedPrekey': signalSignedPrekey,
        'signalSignedPrekeySignature': signalSignedPrekeySignature,
        'signalOneTimePrekeyId': signalOneTimePrekeyId,
        'signalOneTimePrekey': signalOneTimePrekey,
        'globalSign': globalSign,
        'time': time,
      };

  /// Builds a JSON map using the LEGACY (v1) field names.
  Map<String, dynamic> legacyFieldJson() => {
        'name': name,
        'relay': relay,
        'pubkey': nostrIdentityKey,
        'curve25519PkHex': signalIdentityKey,
        'onetimekey': receiveAddress,
        'signedId': signalSignedPrekeyId,
        'signedPublic': signalSignedPrekey,
        'signedSignature': signalSignedPrekeySignature,
        'prekeyId': signalOneTimePrekeyId,
        'prekeyPubkey': signalOneTimePrekey,
        'globalSign': globalSign,
        'time': time,
      };

  /// Verifies that [model] has the expected field values.
  void expectCorrectFields(QRUserModel model) {
    expect(model.name, name);
    expect(model.relay, relay);
    expect(model.nostrIdentityKey, nostrIdentityKey);
    expect(model.signalIdentityKey, signalIdentityKey);
    expect(model.receiveAddress, receiveAddress);
    expect(model.signalSignedPrekeyId, signalSignedPrekeyId);
    expect(model.signalSignedPrekey, signalSignedPrekey);
    expect(model.signalSignedPrekeySignature, signalSignedPrekeySignature);
    expect(model.signalOneTimePrekeyId, signalOneTimePrekeyId);
    expect(model.signalOneTimePrekey, signalOneTimePrekey);
    expect(model.globalSign, globalSign);
    expect(model.time, time);
  }

  group('QRUserModel JSON serialization', () {
    test('fromJson with NEW field names', () {
      final model = QRUserModel.fromJson(newFieldJson());
      expectCorrectFields(model);
    });

    test('fromJson with LEGACY field names', () {
      final model = QRUserModel.fromJson(legacyFieldJson());
      expectCorrectFields(model);
    });

    test('toJson outputs both new and legacy keys', () {
      final model = QRUserModel.fromJson(newFieldJson());
      final json = model.toJson();

      // New keys
      expect(json['nostrIdentityKey'], nostrIdentityKey);
      expect(json['signalIdentityKey'], signalIdentityKey);
      expect(json['receiveAddress'], receiveAddress);
      expect(json['signalSignedPrekeyId'], signalSignedPrekeyId);
      expect(json['signalSignedPrekey'], signalSignedPrekey);
      expect(json['signalSignedPrekeySignature'], signalSignedPrekeySignature);
      expect(json['signalOneTimePrekeyId'], signalOneTimePrekeyId);
      expect(json['signalOneTimePrekey'], signalOneTimePrekey);

      // Legacy keys
      expect(json['pubkey'], nostrIdentityKey);
      expect(json['curve25519PkHex'], signalIdentityKey);
      expect(json['onetimekey'], receiveAddress);
      expect(json['signedId'], signalSignedPrekeyId);
      expect(json['signedPublic'], signalSignedPrekey);
      expect(json['signedSignature'], signalSignedPrekeySignature);
      expect(json['prekeyId'], signalOneTimePrekeyId);
      expect(json['prekeyPubkey'], signalOneTimePrekey);
    });

    test('fromJson -> toJson -> fromJson roundtrip', () {
      final original = QRUserModel.fromJson(newFieldJson());
      final json = original.toJson();
      final restored = QRUserModel.fromJson(json);

      expectCorrectFields(restored);
    });
  });

  group('QRUserModel short string encoding', () {
    test('toShortStringForQrcode -> fromShortString roundtrip', () {
      final original = QRUserModel.fromJson(newFieldJson());
      final encoded = original.toShortStringForQrcode();
      final decoded = QRUserModel.fromShortString(encoded);

      expectCorrectFields(decoded);
    });

    test('fromShortString preserves optional avatar and lightning', () {
      final model = QRUserModel.fromJson(newFieldJson())
        ..avatar = 'https://example.com/avatar.png'
        ..lightning = 'lnurl1dp68gurn8ghj7...';

      final encoded = model.toShortStringForQrcode();
      final decoded = QRUserModel.fromShortString(encoded);

      expect(decoded.avatar, model.avatar);
      expect(decoded.lightning, model.lightning);
    });
  });
}
