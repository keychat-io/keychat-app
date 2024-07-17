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
  int? updatedAt;
  final String name;
  final List users;
  RoomProfile(this.pubkey, this.name, this.users, this.groupType);

  factory RoomProfile.fromJson(Map<String, dynamic> json) =>
      _$RoomProfileFromJson(json);

  @override
  toString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => _$RoomProfileToJson(this);
}
