import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/identity.dart';

void main() {
  group('Identity semantic aliases', () {
    Identity makeIdentity() {
      return Identity(
        name: 'Alice',
        npub: 'npub1test',
        secp256k1PKHex: 'a' * 64,
      );
    }

    group('nostrIdentityKey', () {
      test('getter reads secp256k1PKHex', () {
        final id = makeIdentity();
        expect(id.nostrIdentityKey, equals('a' * 64));
      });

      test('setter writes secp256k1PKHex', () {
        final id = makeIdentity()..nostrIdentityKey = 'b' * 64;
        // ignore: deprecated_member_use_from_same_package
        expect(id.secp256k1PKHex, equals('b' * 64));
      });
    });

    group('signalIdentityKey', () {
      test('getter reads curve25519PkHex', () {
        final id = makeIdentity()..curve25519PkHex = '05${'c' * 64}';
        expect(id.signalIdentityKey, equals('05${'c' * 64}'));
      });

      test('setter writes curve25519PkHex', () {
        final id = makeIdentity()..signalIdentityKey = '05${'d' * 64}';
        // ignore: deprecated_member_use_from_same_package
        expect(id.curve25519PkHex, equals('05${'d' * 64}'));
      });

      test('returns null when curve25519PkHex is null', () {
        final id = makeIdentity();
        expect(id.signalIdentityKey, isNull);
      });
    });

    group('displayName', () {
      test('trims whitespace', () {
        final id = Identity(
          name: '  Alice  ',
          npub: 'npub1test',
          secp256k1PKHex: 'a' * 64,
        );
        expect(id.displayName, equals('Alice'));
      });
    });

    group('Equatable props', () {
      test('same props produces equal identities', () {
        final now = DateTime.now();
        final a = makeIdentity()
          ..id = 1
          ..createdAt = now;
        final b = makeIdentity()
          ..id = 1
          ..createdAt = now;
        expect(a, equals(b));
      });

      test('different id produces unequal identities', () {
        final now = DateTime.now();
        final a = makeIdentity()
          ..id = 1
          ..createdAt = now;
        final b = makeIdentity()
          ..id = 2
          ..createdAt = now;
        expect(a, isNot(equals(b)));
      });
    });
  });
}
