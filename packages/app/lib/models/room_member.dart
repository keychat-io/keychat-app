import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'room_member.g.dart';

enum UserStatusType { inviting, invited, blocked, removed }

@JsonSerializable(includeIfNull: false)
@Collection(ignore: {
  'props',
  'isCheck',
  'messageCount',
  'mlsPKExpired',
  'nameFromRelay',
  'avatarFromRelay',
  'fetchFromRelayAt',
  'displayName'
})
// ignore: must_be_immutable
class RoomMember extends Equatable {
  @JsonKey(includeToJson: false, includeFromJson: false)
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('roomId')])
  late String idPubkey; // secp256k1

  @JsonKey(includeToJson: false, includeFromJson: false)
  String? curve25519PkHex;

  late int roomId;

  late String name;

  DateTime? createdAt;
  DateTime? updatedAt;

  bool isAdmin = false;

  @Enumerated(EnumType.ordinal32)
  UserStatusType status = UserStatusType.invited;

  @JsonKey(includeToJson: false, includeFromJson: false)
  bool isCheck = false;

  @JsonKey(includeToJson: false, includeFromJson: false)
  int messageCount = 0;

  @JsonKey(includeToJson: false, includeFromJson: false)
  bool mlsPKExpired = false;

  // local cache
  @JsonKey(includeToJson: false, includeFromJson: false)
  String? nameFromRelay; // fetch from relay

  @JsonKey(includeToJson: false, includeFromJson: false)
  String? avatarFromRelay; // fetch from relay

  @JsonKey(includeToJson: false, includeFromJson: false)
  DateTime? fetchFromRelayAt; // fetch time

  RoomMember(
      {required this.idPubkey,
      required this.roomId,
      required this.name,
      this.status = UserStatusType.invited}) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }
  get displayName => nameFromRelay ?? name;

  factory RoomMember.fromJson(Map<String, dynamic> json) =>
      _$RoomMemberFromJson(json);

  Map<String, dynamic> toJson() => _$RoomMemberToJson(this);

  @override
  List<Object?> get props =>
      [id, roomId, idPubkey, name, isAdmin, status, createdAt, updatedAt];
}
