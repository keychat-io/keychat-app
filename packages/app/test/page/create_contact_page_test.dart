import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/page/chat/create_contact_page.dart';

void main() {
  group('normalizeAddContactInput', () {
    test('trims plain input', () {
      expect(normalizeAddContactInput('  abc123  '), 'abc123');
    });

    test('extracts universal link key', () {
      expect(
        normalizeAddContactInput('https://www.keychat.io/u/?k=npub123'),
        'npub123',
      );
    });

    test('returns empty value for blank universal link key', () {
      expect(normalizeAddContactInput('https://www.keychat.io/u/?k='), isEmpty);
    });
  });

  group('isValidAddContactPubkeyInput', () {
    test('rejects empty pubkey before FFI conversion', () {
      expect(isValidAddContactPubkeyInput(''), isFalse);
      expect(isValidAddContactPubkeyInput('   '), isFalse);
    });

    test('rejects short invalid input before FFI conversion', () {
      expect(isValidAddContactPubkeyInput('abc123'), isFalse);
    });

    test('accepts 64-character hex pubkey', () {
      expect(isValidAddContactPubkeyInput('a' * 64), isTrue);
    });

    test('rejects non-hex 64-character pubkey', () {
      expect(isValidAddContactPubkeyInput('g' * 64), isFalse);
    });
  });
}
