import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/room.dart';

void main() {
  group('Room pure logic', () {
    Room makeRoom({
      RoomType type = RoomType.common,
      GroupType groupType = GroupType.common,
      int identityId = 1,
    }) {
      return Room(
        toMainPubkey: 'abc123',
        npub: 'npub1test',
        identityId: identityId,
        type: type,
      )..groupType = groupType;
    }

    group('getDeviceIdForSignal', () {
      test('returns identityId for common room', () {
        final room = makeRoom(identityId: 42);
        expect(room.getDeviceIdForSignal(), equals(42));
      });

      test('returns 10000 + id for group room', () {
        final room = makeRoom(type: RoomType.group, identityId: 42)..id = 5;
        expect(room.getDeviceIdForSignal(), equals(10005));
      });

      test('returns 10000 + id for bot room', () {
        // ignore: deprecated_member_use_from_same_package
        final room = makeRoom(type: RoomType.bot, identityId: 42)..id = 3;
        expect(room.getDeviceIdForSignal(), equals(10003));
      });
    });

    group('group type getters', () {
      test('isSendAllGroup is true for sendAll group', () {
        final room =
            makeRoom(type: RoomType.group, groupType: GroupType.sendAll);
        expect(room.isSendAllGroup, isTrue);
      });

      test('isSendAllGroup is false for common room', () {
        final room = makeRoom(groupType: GroupType.sendAll);
        expect(room.isSendAllGroup, isFalse);
      });

      test('isMLSGroup is true for MLS group', () {
        final room = makeRoom(type: RoomType.group, groupType: GroupType.mls);
        expect(room.isMLSGroup, isTrue);
      });

      test('isMLSGroup is false for non-group room', () {
        final room = makeRoom(groupType: GroupType.mls);
        expect(room.isMLSGroup, isFalse);
      });
    });

    group('receiveAddress alias', () {
      test('receiveAddress reads onetimekey', () {
        final room = makeRoom()..onetimekey = 'test_key';
        expect(room.receiveAddress, equals('test_key'));
      });

      test('receiveAddress setter writes onetimekey', () {
        final room = makeRoom()..receiveAddress = 'new_key';
        expect(room.onetimekey, equals('new_key'));
      });
    });

    group('signal identity aliases', () {
      test('peerSignalIdentityKey reads curve25519PkHex', () {
        final room = makeRoom()..curve25519PkHex = 'peer_key';
        expect(room.peerSignalIdentityKey, equals('peer_key'));
      });

      test('mySignalIdentityKey reads signalIdPubkey', () {
        final room = makeRoom()..signalIdPubkey = 'my_key';
        expect(room.mySignalIdentityKey, equals('my_key'));
      });

      test('peerSignalIdentityKey setter writes curve25519PkHex', () {
        final room = makeRoom()..peerSignalIdentityKey = 'set_peer';
        expect(room.curve25519PkHex, equals('set_peer'));
      });

      test('mySignalIdentityKey setter writes signalIdPubkey', () {
        final room = makeRoom()..mySignalIdentityKey = 'set_my';
        expect(room.signalIdPubkey, equals('set_my'));
      });
    });

  });
}
