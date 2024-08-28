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
    );

Map<String, dynamic> _$KeychatMessageToJson(KeychatMessage instance) {
  final val = <String, dynamic>{
    'c': _$MessageTypeEnumMap[instance.c]!,
    'type': instance.type,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('msg', instance.msg);
  writeNotNull('name', instance.name);
  return val;
}

const _$MessageTypeEnumMap = {
  MessageType.nip04: 'nip04',
  MessageType.signal: 'signal',
  MessageType.group: 'group',
  MessageType.kdfGroup: 'kdfGroup',
};
