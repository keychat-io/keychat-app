// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qrcode_user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QRUserModel _$QRUserModelFromJson(Map<String, dynamic> json) => QRUserModel()
  ..name = json['name'] as String
  ..pubkey = json['pubkey'] as String
  ..curve25519PkHex = json['curve25519PkHex'] as String
  ..onetimekey = json['onetimekey'] as String
  ..signedId = (json['signedId'] as num).toInt()
  ..signedPublic = json['signedPublic'] as String
  ..signedSignature = json['signedSignature'] as String
  ..prekeyId = (json['prekeyId'] as num).toInt()
  ..prekeyPubkey = json['prekeyPubkey'] as String
  ..globalSign = json['globalSign'] as String
  ..relay = json['relay'] as String?
  ..time = (json['time'] as num).toInt();

Map<String, dynamic> _$QRUserModelToJson(QRUserModel instance) {
  final val = <String, dynamic>{
    'name': instance.name,
    'pubkey': instance.pubkey,
    'curve25519PkHex': instance.curve25519PkHex,
    'onetimekey': instance.onetimekey,
    'signedId': instance.signedId,
    'signedPublic': instance.signedPublic,
    'signedSignature': instance.signedSignature,
    'prekeyId': instance.prekeyId,
    'prekeyPubkey': instance.prekeyPubkey,
    'globalSign': instance.globalSign,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('relay', instance.relay);
  val['time'] = instance.time;
  return val;
}
