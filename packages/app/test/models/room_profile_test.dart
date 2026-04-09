import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/keychat/room_profile.dart';
import 'package:keychat/models/room.dart';

void main() {
  const pubkey = 'pubkey_abc';
  const name = 'Test Group';
  const groupId = 'group_id_123';
  const updatedAt = 1700000000;
  final users = ['user1', 'user2'];
  const groupType = GroupType.sendAll;

  /// Creates a baseline RoomProfile for reuse.
  RoomProfile makeProfile({String? id}) {
    final profile = RoomProfile(pubkey, name, users, groupType, updatedAt);
    profile.groupId = id;
    return profile;
  }

  group('RoomProfile JSON serialization', () {
    test('fromJson with new field name (groupId)', () {
      final json = {
        'pubkey': pubkey,
        'name': name,
        'users': users,
        'groupType': 'sendAll',
        'updatedAt': updatedAt,
        'groupId': groupId,
      };

      final profile = RoomProfile.fromJson(json);

      expect(profile.pubkey, pubkey);
      expect(profile.name, name);
      expect(profile.groupType, groupType);
      expect(profile.groupId, groupId);
      expect(profile.updatedAt, updatedAt);
    });

    test('fromJson with legacy field name (oldToRoomPubKey)', () {
      final json = {
        'pubkey': pubkey,
        'name': name,
        'users': users,
        'groupType': 'sendAll',
        'updatedAt': updatedAt,
        'oldToRoomPubKey': groupId,
      };

      final profile = RoomProfile.fromJson(json);

      expect(profile.groupId, groupId);
    });

    test('toJson outputs both groupId and oldToRoomPubKey', () {
      final profile = makeProfile(id: groupId);
      final json = profile.toJson();

      expect(json['groupId'], groupId);
      expect(json['oldToRoomPubKey'], groupId);
    });

    test('fromJson -> toJson roundtrip', () {
      final original = makeProfile(id: groupId);
      final json = original.toJson();
      final restored = RoomProfile.fromJson(json);

      expect(restored.pubkey, original.pubkey);
      expect(restored.name, original.name);
      expect(restored.groupType, original.groupType);
      expect(restored.groupId, original.groupId);
      expect(restored.updatedAt, original.updatedAt);
    });

    test('groupId=null: neither groupId nor oldToRoomPubKey in output', () {
      final profile = makeProfile(id: null);
      final json = profile.toJson();

      // includeIfNull: false — null groupId should not appear
      expect(json.containsKey('groupId'), isFalse);
      expect(json.containsKey('oldToRoomPubKey'), isFalse);
    });
  });
}
