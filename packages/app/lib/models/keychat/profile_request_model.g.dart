// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_request_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileRequestModel _$ProfileRequestModelFromJson(Map<String, dynamic> json) =>
    ProfileRequestModel(
      pubkey: json['pubkey'] as String,
      name: json['name'] as String,
      version: (json['version'] as num).toInt(),
      avatar: json['avatar'] as String?,
      lightning: json['lightning'] as String?,
      bio: json['bio'] as String?,
      note: json['note'] as String?,
    );

Map<String, dynamic> _$ProfileRequestModelToJson(
  ProfileRequestModel instance,
) => <String, dynamic>{
  'name': instance.name,
  'pubkey': instance.pubkey,
  'version': instance.version,
  'avatar': ?instance.avatar,
  'lightning': ?instance.lightning,
  'bio': ?instance.bio,
  'note': ?instance.note,
};
