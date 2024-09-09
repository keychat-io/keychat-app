import 'dart:convert' show jsonEncode;

import 'package:json_annotation/json_annotation.dart';

import '../room.dart';
part 'room_profile.g.dart';

@JsonSerializable(includeIfNull: false)
class RoomProfile {
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
  RoomProfile(
      this.pubkey, this.name, this.users, this.groupType, this.updatedAt);

  factory RoomProfile.fromJson(Map<String, dynamic> json) =>
      _$RoomProfileFromJson(json);

  @override
  toString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => _$RoomProfileToJson(this);
}
