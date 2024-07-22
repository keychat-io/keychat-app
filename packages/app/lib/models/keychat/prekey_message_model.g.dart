// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prekey_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PrekeyMessageModel _$PrekeyMessageModelFromJson(Map<String, dynamic> json) =>
    PrekeyMessageModel(
      nostrId: json['nostrId'] as String,
      name: json['name'] as String,
      sig: json['sig'] as String,
      message: json['message'] as String,
    );

Map<String, dynamic> _$PrekeyMessageModelToJson(PrekeyMessageModel instance) =>
    <String, dynamic>{
      'nostrId': instance.nostrId,
      'name': instance.name,
      'sig': instance.sig,
      'message': instance.message,
    };
