// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileRequestModel _$ProfileRequestModelFromJson(Map<String, dynamic> json) =>
    ProfileRequestModel(
      pubkey: json['pubkey'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      lightningAddress: json['lightningAddress'] as String?,
      note: json['note'] as String?,
      note2: json['note2'] as String?,
    );

Map<String, dynamic> _$ProfileRequestModelToJson(
        ProfileRequestModel instance) =>
    <String, dynamic>{
      'name': instance.name,
      'pubkey': instance.pubkey,
      if (instance.avatar case final value?) 'avatar': value,
      if (instance.lightningAddress case final value?)
        'lightningAddress': value,
      if (instance.note case final value?) 'note': value,
      if (instance.note2 case final value?) 'note2': value,
    };
