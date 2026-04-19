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

  /// Deserializes from JSON with backward compatibility.
  ///
  /// The field [groupId] was previously serialized as 'oldToRoomPubKey'.
  /// To accept data from both old and new clients, we read 'groupId' first
  /// and fall back to 'oldToRoomPubKey' if absent.
  factory RoomProfile.fromJson(Map<String, dynamic> json) {
    // Clone so we don't mutate the caller's map with the legacy-key fallback.
    final data = {...json};
    data['groupId'] ??= data['oldToRoomPubKey'];
    return _$RoomProfileFromJson(data);
  }

  final String pubkey;
  String? prikey;
  String? avatar;

  /// The previous room unique ID before pubkey changed.
  /// Equal to [Room.toMainPubkey]; used to look up the existing room
  /// when processing group invitations.
  ///
  /// Renamed from 'oldToRoomPubKey' to 'groupId' for clarity.
  /// JSON I/O keeps both keys for cross-version compatibility — see
  /// `fromJson` and `toJson`.
  String? groupId;
  GroupType groupType;
  String? ext;
  String? groupRelay;
  int updatedAt;
  final String name;
  final List<dynamic> users;
  String? signalKeys;
  String? signalPubkey;
  String? signaliPrikey;
  int? signalKeyId;

  @override
  String toString() => jsonEncode(toJson());

  /// Serializes to JSON with backward compatibility.
  ///
  /// Outputs both 'groupId' (for new clients) and 'oldToRoomPubKey'
  /// (for old clients that only recognize the legacy key).
  /// When [groupId] is null, neither key is emitted (includeIfNull: false).
  Map<String, dynamic> toJson() {
    final json = _$RoomProfileToJson(this);
    if (json.containsKey('groupId')) {
      json['oldToRoomPubKey'] = json['groupId'];
    }
    return json;
  }
}
