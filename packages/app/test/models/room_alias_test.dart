// Tests deliberately touch deprecated fields to verify alias parity with them.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/room.dart';

void main() {
  group('Room semantic aliases', () {
    Room makeRoom() {
      return Room(
        toMainPubkey: 'a' * 64,
        npub: 'npub1test',
        identityId: 1,
      );
    }

    group('peerSignalIdentityKey', () {
      test('getter reads curve25519PkHex', () {
        final r = makeRoom()..curve25519PkHex = '05${'c' * 64}';
        expect(r.peerSignalIdentityKey, equals('05${'c' * 64}'));
      });

      test('setter writes curve25519PkHex', () {
        final r = makeRoom()..peerSignalIdentityKey = '05${'d' * 64}';
        expect(r.curve25519PkHex, equals('05${'d' * 64}'));
      });

      test('returns null when curve25519PkHex is null', () {
        final r = makeRoom();
        expect(r.peerSignalIdentityKey, isNull);
      });
    });

    group('mySignalIdentityKey', () {
      test('getter reads signalIdPubkey', () {
        final r = makeRoom()..signalIdPubkey = '05${'e' * 64}';
        expect(r.mySignalIdentityKey, equals('05${'e' * 64}'));
      });

      test('setter writes signalIdPubkey', () {
        final r = makeRoom()..mySignalIdentityKey = '05${'f' * 64}';
        expect(r.signalIdPubkey, equals('05${'f' * 64}'));
      });

      test('returns null when signalIdPubkey is null', () {
        final r = makeRoom();
        expect(r.mySignalIdentityKey, isNull);
      });
    });

    group('receiveAddress', () {
      test('getter reads onetimekey', () {
        final r = makeRoom()..onetimekey = 'inbox_pubkey_hex';
        expect(r.receiveAddress, equals('inbox_pubkey_hex'));
      });

      test('setter writes onetimekey', () {
        final r = makeRoom()..receiveAddress = 'new_inbox_hex';
        expect(r.onetimekey, equals('new_inbox_hex'));
      });

      test('returns null when onetimekey is null', () {
        final r = makeRoom();
        expect(r.receiveAddress, isNull);
      });
    });
  });
}
