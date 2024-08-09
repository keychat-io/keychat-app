import 'package:app/models/db_provider.dart';
import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'room_member.g.dart';

enum UserStatusType { inviting, invited, blocked, removed }

@JsonSerializable(includeIfNull: false)
@Collection(ignore: {'props', 'isCheck'})
// ignore: must_be_immutable
class RoomMember extends Equatable {
  @JsonKey(includeToJson: false, includeFromJson: false)
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('roomId')])
  late String idPubkey; // secp256k1

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

  RoomMember(
      {required this.idPubkey, required this.roomId, required this.name}) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  factory RoomMember.fromJson(Map<String, dynamic> json) =>
      _$RoomMemberFromJson(json);

  Map<String, dynamic> toJson() => _$RoomMemberToJson(this);

  @override
  List<Object?> get props =>
      [id, roomId, idPubkey, name, isAdmin, status, createdAt, updatedAt];

  Future<RoomMember> updateCurve25519PkHex(String signalIdPubkey) async {
    curve25519PkHex = signalIdPubkey;
    Isar database = DBProvider.database;
    await database.writeTxn(() async {
      await database.roomMembers.put(this);
    });
    return this;
  }
}
