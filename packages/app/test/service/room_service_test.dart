import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/room.dart';
import 'package:keychat/service/room.service.dart';

void main() {
  group('RoomService', () {
    late RoomService service;

    setUp(() {
      service = RoomService.instance;
    });

    group('checkRoomStatus', () {
      Room makeRoom(RoomStatus status) {
        return Room(
          toMainPubkey: 'abc123',
          npub: 'npub1test',
          identityId: 1,
          status: status,
        );
      }

      test('throws for dissolved room', () {
        final room = makeRoom(RoomStatus.dissolved);
        expect(
          () => service.checkRoomStatus(room),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('dissolved'),
            ),
          ),
        );
      });

      test('throws for removedFromGroup room', () {
        final room = makeRoom(RoomStatus.removedFromGroup);
        expect(
          () => service.checkRoomStatus(room),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('removed'),
            ),
          ),
        );
      });

      test('does not throw for enabled room', () async {
        final room = makeRoom(RoomStatus.enabled);
        await expectLater(service.checkRoomStatus(room), completes);
      });

      test('does not throw for requesting room', () async {
        final room = makeRoom(RoomStatus.requesting);
        await expectLater(service.checkRoomStatus(room), completes);
      });

      test('does not throw for init room', () async {
        final room = makeRoom(RoomStatus.init);
        await expectLater(service.checkRoomStatus(room), completes);
      });
    });
  });
}
