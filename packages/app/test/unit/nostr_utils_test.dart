import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/nostr-core/utils.dart';

void main() {
  group('addEscapeChars', () {
    test('escapes double quotes', () {
      expect(addEscapeChars('say "hello"'), equals(r'say \"hello\"'));
    });

    test('escapes newlines', () {
      expect(addEscapeChars('line1\nline2'), equals(r'line1\nline2'));
    });

    test('escapes both quotes and newlines', () {
      expect(
        addEscapeChars('"hello"\n"world"'),
        equals(r'\"hello\"\n\"world\"'),
      );
    });

    test('returns empty string unchanged', () {
      expect(addEscapeChars(''), equals(''));
    });

    test('returns string without special chars unchanged', () {
      expect(addEscapeChars('plain text'), equals('plain text'));
    });
  });

  group('generate64RandomHexChars', () {
    test('returns 64-character string', () {
      final hex = generate64RandomHexChars();
      expect(hex.length, equals(64));
    });

    test('contains only hex characters', () {
      final hex = generate64RandomHexChars();
      expect(hex, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('generates different values each call', () {
      final hex1 = generate64RandomHexChars();
      final hex2 = generate64RandomHexChars();
      expect(hex1, isNot(equals(hex2)));
    });
  });
}
