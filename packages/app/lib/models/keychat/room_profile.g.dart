// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoomProfile _$RoomProfileFromJson(Map<String, dynamic> json) => RoomProfile(
      json['pubkey'] as String,
      json['name'] as String,
      json['users'] as List<dynamic>,
      $enumDecode(_$GroupTypeEnumMap, json['groupType']),
      (json['updatedAt'] as num).toInt(),
    )
      ..prikey = json['prikey'] as String?
      ..avatar = json['avatar'] as String?
      ..oldToRoomPubKey = json['oldToRoomPubKey'] as String?
      ..ext = json['ext'] as String?
      ..groupRelay = json['groupRelay'] as String?
      ..signalKeys = json['signalKeys'] as String?
      ..signalPubkey = json['signalPubkey'] as String?
      ..signaliPrikey = json['signaliPrikey'] as String?
      ..signalKeyId = (json['signalKeyId'] as num?)?.toInt();

Map<String, dynamic> _$RoomProfileToJson(RoomProfile instance) =>
    <String, dynamic>{
      'pubkey': instance.pubkey,
      if (instance.prikey case final value?) 'prikey': value,
      if (instance.avatar case final value?) 'avatar': value,
      if (instance.oldToRoomPubKey case final value?) 'oldToRoomPubKey': value,
      'groupType': _$GroupTypeEnumMap[instance.groupType]!,
      if (instance.ext case final value?) 'ext': value,
      if (instance.groupRelay case final value?) 'groupRelay': value,
      'updatedAt': instance.updatedAt,
      'name': instance.name,
      'users': instance.users,
      if (instance.signalKeys case final value?) 'signalKeys': value,
      if (instance.signalPubkey case final value?) 'signalPubkey': value,
      if (instance.signaliPrikey case final value?) 'signaliPrikey': value,
      if (instance.signalKeyId case final value?) 'signalKeyId': value,
    };

const _$GroupTypeEnumMap = {
  GroupType.shareKey: 'shareKey',
  GroupType.sendAll: 'sendAll',
  GroupType.kdf: 'kdf',
  GroupType.mls: 'mls',
};
