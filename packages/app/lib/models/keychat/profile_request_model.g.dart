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
      lightning: json['lightning'] as String?,
      bio: json['bio'] as String?,
      note: json['note'] as String?,
    );

Map<String, dynamic> _$ProfileRequestModelToJson(
        ProfileRequestModel instance) =>
    <String, dynamic>{
      'name': instance.name,
      'pubkey': instance.pubkey,
      if (instance.avatar case final value?) 'avatar': value,
      if (instance.lightning case final value?) 'lightning': value,
      if (instance.bio case final value?) 'bio': value,
      if (instance.note case final value?) 'note': value,
    };
