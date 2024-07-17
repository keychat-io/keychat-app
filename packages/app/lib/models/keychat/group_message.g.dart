// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GroupMessage _$GroupMessageFromJson(Map<String, dynamic> json) => GroupMessage(
      message: json['message'] as String,
      pubkey: json['pubkey'] as String,
      sig: json['sig'] as String?,
    )
      ..subtype = (json['subtype'] as num?)?.toInt()
      ..ext = json['ext'] as String?;

Map<String, dynamic> _$GroupMessageToJson(GroupMessage instance) {
  final val = <String, dynamic>{
    'message': instance.message,
    'pubkey': instance.pubkey,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('sig', instance.sig);
  writeNotNull('subtype', instance.subtype);
  writeNotNull('ext', instance.ext);
  return val;
}
