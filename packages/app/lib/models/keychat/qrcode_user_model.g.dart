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
  ..signalSignedPrekeyId =
      (QRUserModel._readSignalSignedPrekeyId(json, 'signalSignedPrekeyId')
              as num)
          .toInt()
  ..signalSignedPrekey =
      QRUserModel._readSignalSignedPrekey(json, 'signalSignedPrekey') as String
  ..signalSignedPrekeySignature =
      QRUserModel._readSignalSignedPrekeySignature(
              json, 'signalSignedPrekeySignature')
          as String
  ..signalOneTimePrekeyId =
      (QRUserModel._readSignalOneTimePrekeyId(json, 'signalOneTimePrekeyId')
              as num)
          .toInt()
  ..signalOneTimePrekey =
      QRUserModel._readSignalOneTimePrekey(json, 'signalOneTimePrekey')
          as String
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
      'signalSignedPrekeyId': instance.signalSignedPrekeyId,
      'signalSignedPrekey': instance.signalSignedPrekey,
      'signalSignedPrekeySignature': instance.signalSignedPrekeySignature,
      'signalOneTimePrekeyId': instance.signalOneTimePrekeyId,
      'signalOneTimePrekey': instance.signalOneTimePrekey,
      'globalSign': instance.globalSign,
      'relay': instance.relay,
      'time': instance.time,
      'avatar': ?instance.avatar,
      'lightning': ?instance.lightning,
    };
