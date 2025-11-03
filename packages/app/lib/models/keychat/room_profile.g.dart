// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RoomProfile _$RoomProfileFromJson(Map<String, dynamic> json) =>
    RoomProfile(
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
      'prikey': ?instance.prikey,
      'avatar': ?instance.avatar,
      'oldToRoomPubKey': ?instance.oldToRoomPubKey,
      'groupType': _$GroupTypeEnumMap[instance.groupType]!,
      'ext': ?instance.ext,
      'groupRelay': ?instance.groupRelay,
      'updatedAt': instance.updatedAt,
      'name': instance.name,
      'users': instance.users,
      'signalKeys': ?instance.signalKeys,
      'signalPubkey': ?instance.signalPubkey,
      'signaliPrikey': ?instance.signaliPrikey,
      'signalKeyId': ?instance.signalKeyId,
    };

const _$GroupTypeEnumMap = {
  GroupType.shareKey: 'shareKey',
  GroupType.sendAll: 'sendAll',
  GroupType.kdf: 'kdf',
  GroupType.mls: 'mls',
};
