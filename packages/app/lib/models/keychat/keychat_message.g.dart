// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'keychat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

KeychatMessage _$KeychatMessageFromJson(Map<String, dynamic> json) =>
    KeychatMessage(
      type: (json['type'] as num).toInt(),
      c: $enumDecode(_$MessageTypeEnumMap, json['c']),
      msg: json['msg'] as String?,
      name: json['name'] as String?,
      data: json['data'] as String?,
    );

Map<String, dynamic> _$KeychatMessageToJson(KeychatMessage instance) =>
    <String, dynamic>{
      'c': _$MessageTypeEnumMap[instance.c]!,
      'type': instance.type,
      if (instance.msg case final value?) 'msg': value,
      if (instance.name case final value?) 'name': value,
      if (instance.data case final value?) 'data': value,
    };

const _$MessageTypeEnumMap = {
  MessageType.nip04: 'nip04',
  MessageType.signal: 'signal',
  MessageType.group: 'group',
  MessageType.kdfGroup: 'kdfGroup',
  MessageType.mls: 'mls',
};
