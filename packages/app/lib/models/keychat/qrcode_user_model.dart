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
      ..pubkey = values[2]
      ..curve25519PkHex = values[3]
      ..onetimekey = values[4]
      ..signedId = int.parse(values[5])
      ..signedPublic = values[6]
      ..signedSignature = values[7]
      ..prekeyId = int.parse(values[8])
      ..prekeyPubkey = values[9]
      ..time = int.parse(values[10])
      ..globalSign = values[11]
      ..avatar = values.length > 12 ? values[12] : null
      ..lightning = values.length > 13 ? values[13] : null;
  }
  late String name; // user define name
  late String pubkey;
  late String curve25519PkHex;
  late String onetimekey;
  late int signedId;
  late String signedPublic;
  late String signedSignature;
  late int prekeyId;
  late String prekeyPubkey;
  late String globalSign;
  String relay = '';
  int time = -1;
  String? avatar;
  String? lightning;

  @override
  String toString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => _$QRUserModelToJson(this);

  String toShortStringForQrcode() {
    final data =
        '"$name",$relay,$pubkey,$curve25519PkHex,$onetimekey,$signedId,$signedPublic,$signedSignature,$prekeyId,$prekeyPubkey,$time,$globalSign,$avatar,$lightning';

    final compressedData = gzip.encode(utf8.encode(data));

    return base64Encode(compressedData);
  }
}
