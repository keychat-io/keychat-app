import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/room_member.dart';

void main() {
  group('RoomMember', () {
    Map<String, dynamic> buildFullJson() => {
      'idPubkey': 'npub1abc123',
      'roomId': 42,
      'name': 'Alice',
      'status': 'invited',
      'isAdmin': true,
      'createdAt': '2024-01-01T00:00:00.000',
      'updatedAt': '2024-01-02T00:00:00.000',
      'msg': 'joined the room',
      'signalIdentityKey': 'curve25519hex',
    };

    group('fromJson -> toJson roundtrip', () {
      test('preserves serializable fields', () {
        final json = buildFullJson();
        final member = RoomMember.fromJson(json);
        final result = member.toJson();

        expect(result['idPubkey'], equals('npub1abc123'));
        expect(result['roomId'], equals(42));
        expect(result['name'], equals('Alice'));
        expect(result['status'], equals('invited'));
        expect(result['isAdmin'], isTrue);
        expect(result['msg'], equals('joined the room'));
        expect(result['signalIdentityKey'], equals('curve25519hex'));
      });
    });

    group('toJson', () {
      test('excludes fields marked with includeToJson: false', () {
        final member = RoomMember(
          idPubkey: 'npub1test',
          roomId: 1,
          name: 'Bob',
        );
        // Set excluded fields
        member
          ..isCheck = true
          ..messageCount = 5
          ..mlsPKExpired = true;

        final json = member.toJson();

        // These fields should NOT be in toJson output
        expect(json.containsKey('id'), isFalse);
        expect(json.containsKey('isCheck'), isFalse);
        expect(json.containsKey('messageCount'), isFalse);
        expect(json.containsKey('mlsPKExpired'), isFalse);
        expect(json.containsKey('contact'), isFalse);
      });

      test('includes expected fields', () {
        final member = RoomMember(
          idPubkey: 'npub1test',
          roomId: 1,
          name: 'Bob',
          status: UserStatusType.inviting,
        );
        member
          ..isAdmin = true
          ..msg = 'hello';

        final json = member.toJson();

        expect(json.containsKey('idPubkey'), isTrue);
        expect(json.containsKey('roomId'), isTrue);
        expect(json.containsKey('name'), isTrue);
        expect(json.containsKey('isAdmin'), isTrue);
        expect(json.containsKey('status'), isTrue);
        expect(json.containsKey('createdAt'), isTrue);
        expect(json.containsKey('updatedAt'), isTrue);
        expect(json.containsKey('msg'), isTrue);
      });
    });

    group('status enum serialization', () {
      test('serializes status as string name', () {
        final member = RoomMember(
          idPubkey: 'npub1test',
          roomId: 1,
          status: UserStatusType.blocked,
        );

        final json = member.toJson();
        expect(json['status'], equals('blocked'));
      });

      test('deserializes status from string name', () {
        final json = buildFullJson();
        json['status'] = 'removed';
        final member = RoomMember.fromJson(json);

        expect(member.status, equals(UserStatusType.removed));
      });

      test('defaults to invited when status is missing', () {
        final json = buildFullJson();
        json.remove('status');
        final member = RoomMember.fromJson(json);

        expect(member.status, equals(UserStatusType.invited));
      });

      test('all enum values roundtrip correctly', () {
        for (final status in UserStatusType.values) {
          final member = RoomMember(
            idPubkey: 'npub1test',
            roomId: 1,
            status: status,
          );
          final json = member.toJson();
          final restored = RoomMember.fromJson(json);
          expect(restored.status, equals(status));
        }
      });
    });
  });
}
