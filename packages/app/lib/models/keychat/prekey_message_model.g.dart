// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prekey_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrekeyMessageModel _$PrekeyMessageModelFromJson(Map<String, dynamic> json) =>
    PrekeyMessageModel(
      nostrId: json['nostrId'] as String,
      signalId: json['signalId'] as String,
      time: (json['time'] as num).toInt(),
      name: json['name'] as String,
      sig: json['sig'] as String,
      message: json['message'] as String,
      lightning: json['lightning'] as String?,
      avatar: json['avatar'] as String?,
    );

Map<String, dynamic> _$PrekeyMessageModelToJson(PrekeyMessageModel instance) =>
    <String, dynamic>{
      'nostrId': instance.nostrId,
      'signalId': instance.signalId,
      'time': instance.time,
      'sig': instance.sig,
      'name': instance.name,
      'message': instance.message,
      if (instance.lightning case final value?) 'lightning': value,
      if (instance.avatar case final value?) 'avatar': value,
    };
