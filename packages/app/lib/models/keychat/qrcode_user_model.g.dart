// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qrcode_user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QRUserModel _$QRUserModelFromJson(Map<String, dynamic> json) => QRUserModel()
  ..name = json['name'] as String
  ..nostrIdentityKey =
      QRUserModel._readNostrIdentityKey(json, 'nostrIdentityKey') as String
  ..signalIdentityKey =
      QRUserModel._readSignalIdentityKey(json, 'signalIdentityKey') as String
  ..receiveAddress =
      QRUserModel._readReceiveAddress(json, 'receiveAddress') as String
  ..signedId = (json['signedId'] as num).toInt()
  ..signedPublic = json['signedPublic'] as String
  ..signedSignature = json['signedSignature'] as String
  ..prekeyId = (json['prekeyId'] as num).toInt()
  ..prekeyPubkey = json['prekeyPubkey'] as String
  ..globalSign = json['globalSign'] as String
  ..relay = json['relay'] as String
  ..time = (json['time'] as num).toInt()
  ..avatar = json['avatar'] as String?
  ..lightning = json['lightning'] as String?;

Map<String, dynamic> _$QRUserModelToJson(QRUserModel instance) =>
    <String, dynamic>{
      'name': instance.name,
      'nostrIdentityKey': instance.nostrIdentityKey,
      'signalIdentityKey': instance.signalIdentityKey,
      'receiveAddress': instance.receiveAddress,
      'signedId': instance.signedId,
      'signedPublic': instance.signedPublic,
      'signedSignature': instance.signedSignature,
      'prekeyId': instance.prekeyId,
      'prekeyPubkey': instance.prekeyPubkey,
      'globalSign': instance.globalSign,
      'relay': instance.relay,
      'time': instance.time,
      'avatar': ?instance.avatar,
      'lightning': ?instance.lightning,
    };
