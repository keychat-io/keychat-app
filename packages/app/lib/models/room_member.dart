import 'package:keychat/models/contact.dart';
import 'package:equatable/equatable.dart';
import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'room_member.g.dart';

enum UserStatusType { inviting, invited, blocked, removed, unknown }

@JsonSerializable(includeIfNull: false)
@Collection(
  ignore: {
    'props',
    'isCheck',
    'messageCount',
    'mlsPKExpired',
    'contact',
    'displayName',
    'signalIdentityKey',
  },
)
// ignore: must_be_immutable
class RoomMember extends Equatable {
  // fetch time

  RoomMember({
    required this.idPubkey,
    required this.roomId,
    this.name,
    this.status = UserStatusType.invited,
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  factory RoomMember.fromJson(Map<String, dynamic> json) =>
      _$RoomMemberFromJson(json);
  @JsonKey(includeToJson: false, includeFromJson: false)
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('roomId')])
  late String idPubkey; // secp256k1

  @JsonKey(includeToJson: false, includeFromJson: false)
  @Deprecated('Use signalIdentityKey instead')
  String? curve25519PkHex;

  /// The member's Signal identity key (curve25519 hex).
  // ignore: deprecated_member_use_from_same_package
  String? get signalIdentityKey => curve25519PkHex;
  // ignore: deprecated_member_use_from_same_package
  set signalIdentityKey(String? v) => curve25519PkHex = v;

  late int roomId;

  String? name;

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

  @JsonKey(includeToJson: false, includeFromJson: false)
  Contact? contact;
  String get displayName => contact?.displayName ?? name ?? idPubkey;

  String? msg; // last system message

  Map<String, dynamic> toJson() => _$RoomMemberToJson(this);

  @override
  List<Object?> get props => [
    id,
    roomId,
    idPubkey,
    name,
    isAdmin,
    status,
    createdAt,
    updatedAt,
  ];
}
