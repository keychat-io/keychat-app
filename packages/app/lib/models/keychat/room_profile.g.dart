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

Map<String, dynamic> _$RoomProfileToJson(RoomProfile instance) {
  final val = <String, dynamic>{
    'pubkey': instance.pubkey,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('prikey', instance.prikey);
  writeNotNull('avatar', instance.avatar);
  writeNotNull('oldToRoomPubKey', instance.oldToRoomPubKey);
  val['groupType'] = _$GroupTypeEnumMap[instance.groupType]!;
  writeNotNull('ext', instance.ext);
  writeNotNull('groupRelay', instance.groupRelay);
  val['updatedAt'] = instance.updatedAt;
  val['name'] = instance.name;
  val['users'] = instance.users;
  writeNotNull('signalKeys', instance.signalKeys);
  writeNotNull('signalPubkey', instance.signalPubkey);
  writeNotNull('signaliPrikey', instance.signaliPrikey);
  writeNotNull('signalKeyId', instance.signalKeyId);
  return val;
}

const _$GroupTypeEnumMap = {
  GroupType.shareKey: 'shareKey',
  GroupType.sendAll: 'sendAll',
  GroupType.kdf: 'kdf',
};
