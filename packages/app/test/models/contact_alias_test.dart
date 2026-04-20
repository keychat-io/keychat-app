// Tests deliberately touch deprecated fields to verify alias parity with them.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/contact.dart';

void main() {
  group('Contact semantic aliases', () {
    Contact makeContact() {
      return Contact(
        identityId: 1,
        pubkey: 'a' * 64,
        npubkey: 'npub1test',
      );
    }

    group('signalIdentityKey', () {
      test('getter reads curve25519PkHex', () {
        final c = makeContact()..curve25519PkHex = '05${'c' * 64}';
        expect(c.signalIdentityKey, equals('05${'c' * 64}'));
      });

      test('setter writes curve25519PkHex', () {
        final c = makeContact()..signalIdentityKey = '05${'d' * 64}';
        expect(c.curve25519PkHex, equals('05${'d' * 64}'));
      });

      test('returns null when curve25519PkHex is null', () {
        final c = makeContact();
        expect(c.signalIdentityKey, isNull);
      });
    });
  });
}
