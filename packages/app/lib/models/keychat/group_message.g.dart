// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroupMessage _$GroupMessageFromJson(Map<String, dynamic> json) =>
    GroupMessage(
        message: json['message'] as String,
        pubkey: json['pubkey'] as String,
        sig: json['sig'] as String?,
      )
      ..subtype = (json['subtype'] as num?)?.toInt()
      ..ext = json['ext'] as String?;

Map<String, dynamic> _$GroupMessageToJson(GroupMessage instance) =>
    <String, dynamic>{
      'message': instance.message,
      'pubkey': instance.pubkey,
      'sig': ?instance.sig,
      'subtype': ?instance.subtype,
      'ext': ?instance.ext,
    };
