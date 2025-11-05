import 'dart:convert' show jsonEncode;

import 'package:keychat/models/room.dart';
import 'package:json_annotation/json_annotation.dart';

part 'room_profile.g.dart';

@JsonSerializable(includeIfNull: false)
class RoomProfile {
  RoomProfile(
    this.pubkey,
    this.name,
    this.users,
    this.groupType,
    this.updatedAt,
  );

  factory RoomProfile.fromJson(Map<String, dynamic> json) =>
      _$RoomProfileFromJson(json);
  final String pubkey;
  String? prikey;
  String? avatar;
  String? oldToRoomPubKey; // for share private key group
  GroupType groupType;
  String? ext;
  String? groupRelay;
  int updatedAt;
  final String name;
  final List users;
  String? signalKeys;
  String? signalPubkey;
  String? signaliPrikey;
  int? signalKeyId;

  @override
  String toString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => _$RoomProfileToJson(this);
}
