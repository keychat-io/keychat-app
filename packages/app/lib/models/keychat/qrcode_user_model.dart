import 'dart:convert' show base64Decode, base64Encode, jsonEncode, utf8;
import 'dart:io' show gzip;
import 'package:json_annotation/json_annotation.dart';

part 'qrcode_user_model.g.dart';

@JsonSerializable(includeIfNull: false)
class QRUserModel {
  QRUserModel();

  factory QRUserModel.fromJson(Map<String, dynamic> json) =>
      _$QRUserModelFromJson(json);

  factory QRUserModel.fromShortString(String str) {
    final restoredData = utf8.decode(gzip.decode(base64Decode(str)));
    final values = restoredData.split(',');
    return QRUserModel()
      ..name = values[0].replaceAll('"', '')
      ..relay = values[1]
      ..nostrIdentityKey = values[2]
      ..signalIdentityKey = values[3]
      ..receiveAddress = values[4]
      ..signalSignedPrekeyId = int.parse(values[5])
      ..signalSignedPrekey = values[6]
      ..signalSignedPrekeySignature = values[7]
      ..signalOneTimePrekeyId = int.parse(values[8])
      ..signalOneTimePrekey = values[9]
      ..time = int.parse(values[10])
      ..globalSign = values[11]
      ..avatar = values.length > 12 ? values[12] : null
      ..lightning = values.length > 13 ? values[13] : null;
  }
  late String name; // user display name

  /// Nostr identity pubkey (secp256k1 hex).
  @JsonKey(readValue: _readNostrIdentityKey)
  late String nostrIdentityKey;

  /// Signal identity pubkey (curve25519 hex).
  @JsonKey(readValue: _readSignalIdentityKey)
  late String signalIdentityKey;

  /// Nostr temporary inbox pubkey for first-message delivery (NOT a Signal one-time prekey).
  /// Reads from both `"receiveAddress"` (v2) and `"onetimekey"` (v1) for backward compatibility.
  @JsonKey(readValue: _readReceiveAddress)
  late String receiveAddress;

  static Object? _readNostrIdentityKey(Map json, String key) =>
      json['nostrIdentityKey'] ?? json['pubkey'];

  static Object? _readSignalIdentityKey(Map json, String key) =>
      json['signalIdentityKey'] ?? json['curve25519PkHex'];

  static Object? _readReceiveAddress(Map json, String key) =>
      json['receiveAddress'] ?? json['onetimekey'];

  /// Signal signed prekey ID.
  @JsonKey(readValue: _readSignalSignedPrekeyId)
  late int signalSignedPrekeyId;

  /// Signal signed prekey (curve25519 hex).
  @JsonKey(readValue: _readSignalSignedPrekey)
  late String signalSignedPrekey;

  /// Signal signed prekey signature (hex).
  @JsonKey(readValue: _readSignalSignedPrekeySignature)
  late String signalSignedPrekeySignature;

  /// Signal one-time prekey ID.
  @JsonKey(readValue: _readSignalOneTimePrekeyId)
  late int signalOneTimePrekeyId;

  /// Signal one-time prekey (curve25519 hex).
  @JsonKey(readValue: _readSignalOneTimePrekey)
  late String signalOneTimePrekey;

  static Object? _readSignalSignedPrekeyId(Map json, String key) =>
      json['signalSignedPrekeyId'] ?? json['signedId'];

  static Object? _readSignalSignedPrekey(Map json, String key) =>
      json['signalSignedPrekey'] ?? json['signedPublic'];

  static Object? _readSignalSignedPrekeySignature(Map json, String key) =>
      json['signalSignedPrekeySignature'] ?? json['signedSignature'];

  static Object? _readSignalOneTimePrekeyId(Map json, String key) =>
      json['signalOneTimePrekeyId'] ?? json['prekeyId'];

  static Object? _readSignalOneTimePrekey(Map json, String key) =>
      json['signalOneTimePrekey'] ?? json['prekeyPubkey'];
  late String globalSign;
  String relay = '';
  int time = -1;
  String? avatar;
  String? lightning;

  @override
  String toString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
    ..._$QRUserModelToJson(this),
    // Legacy key aliases for backward compatibility with old clients
    'pubkey': nostrIdentityKey,
    'curve25519PkHex': signalIdentityKey,
    'onetimekey': receiveAddress,
    'signedId': signalSignedPrekeyId,
    'signedPublic': signalSignedPrekey,
    'signedSignature': signalSignedPrekeySignature,
    'prekeyId': signalOneTimePrekeyId,
    'prekeyPubkey': signalOneTimePrekey,
  };

  String toShortStringForQrcode() {
    final data =
        '"$name",$relay,$nostrIdentityKey,$signalIdentityKey,$receiveAddress,$signalSignedPrekeyId,$signalSignedPrekey,$signalSignedPrekeySignature,$signalOneTimePrekeyId,$signalOneTimePrekey,$time,$globalSign,$avatar,$lightning';

    final compressedData = gzip.encode(utf8.encode(data));

    return base64Encode(compressedData);
  }
}
