import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/utils.dart';

void main() {
  group('Top-level functions', () {
    group('formatTimeToHHmm', () {
      test('formats 0 seconds as 00:00', () {
        expect(formatTimeToHHmm(0), equals('00:00'));
      });

      test('formats 59 seconds correctly', () {
        expect(formatTimeToHHmm(59), equals('00:59'));
      });

      test('formats 60 seconds as 01:00', () {
        expect(formatTimeToHHmm(60), equals('01:00'));
      });

      test('formats 90 seconds as 01:30', () {
        expect(formatTimeToHHmm(90), equals('01:30'));
      });

      test('formats 3661 seconds as 61:01', () {
        expect(formatTimeToHHmm(3661), equals('61:01'));
      });

      test('handles negative time by returning 00:00', () {
        expect(formatTimeToHHmm(-10), equals('00:00'));
      });
    });

    group('generate64RandomHexChars', () {
      test('generates 64 hex characters by default', () {
        final result = generate64RandomHexChars();
        expect(result.length, equals(64));
        expect(RegExp(r'^[0-9a-f]+$').hasMatch(result), isTrue);
      });

      test('generates correct length for custom size', () {
        final result = generate64RandomHexChars(16);
        expect(result.length, equals(32));
      });

      test('generates different values on multiple calls', () {
        final results = <String>{};
        for (var i = 0; i < 10; i++) {
          results.add(generate64RandomHexChars());
        }
        expect(results.length, greaterThan(1));
      });
    });

    group('generateRandomAESKey', () {
      test('generates 64 hex characters', () {
        final result = generateRandomAESKey();
        expect(result.length, equals(64));
        expect(RegExp(r'^[0-9a-f]+$').hasMatch(result), isTrue);
      });
    });

    group('getPublicKeyDisplay', () {
      test('returns full key if length < 4', () {
        expect(getPublicKeyDisplay('abc'), equals('abc'));
      });

      test('returns full key if size * 2 >= length', () {
        expect(getPublicKeyDisplay('abcdefgh', 5), equals('abcdefgh'));
      });

      test('formats npub key correctly', () {
        const key = 'npub1234567890abcdef';
        expect(getPublicKeyDisplay(key, 6), equals('npub12...abcdef'));
      });

      test('formats nsec key correctly', () {
        const key = 'nsec1234567890abcdef';
        expect(getPublicKeyDisplay(key, 6), equals('nsec12...abcdef'));
      });

      test('formats hex key with 0x prefix', () {
        const key = '1234567890abcdef1234567890abcdef';
        expect(getPublicKeyDisplay(key, 6), equals('0x123456...abcdef'));
      });
    });

    group('fastHash', () {
      test('returns consistent hash for same input', () {
        const input = 'test_pubkey';
        final hash1 = fastHash(input);
        final hash2 = fastHash(input);
        expect(hash1, equals(hash2));
      });

      test('returns different hash for different input', () {
        final hash1 = fastHash('key1');
        final hash2 = fastHash('key2');
        expect(hash1, isNot(equals(hash2)));
      });

      test('handles empty string', () {
        final hash = fastHash('');
        expect(hash, isA<int>());
      });
    });

    group('getRegistrationId', () {
      test('returns consistent id for same pubkey', () {
        const pubkey = 'test_pubkey_12345';
        final id1 = getRegistrationId(pubkey);
        final id2 = getRegistrationId(pubkey);
        expect(id1, equals(id2));
      });

      test('returns 32-bit integer', () {
        final id = getRegistrationId('any_pubkey');
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0xffffffff));
      });
    });

    group('isBase64', () {
      test('returns true for valid base64 string', () {
        expect(isBase64('SGVsbG8gV29ybGQ='), isTrue);
      });

      test('returns true for base64 without padding', () {
        expect(isBase64('SGVsbG8'), isTrue);
      });

      test('returns true for empty string', () {
        expect(isBase64(''), isTrue);
      });

      test('returns false for invalid characters', () {
        expect(isBase64('Hello!@#'), isFalse);
      });
    });

    group('isEmail', () {
      test('returns true for valid email', () {
        expect(isEmail('test@example.com'), isTrue);
      });

      test('returns true for email with subdomain', () {
        expect(isEmail('user@mail.example.com'), isTrue);
      });

      test('returns true for email with dots in local part', () {
        expect(isEmail('first.last@example.com'), isTrue);
      });

      test('returns false for email without @', () {
        expect(isEmail('testexample.com'), isFalse);
      });

      test('returns false for email without domain', () {
        expect(isEmail('test@'), isFalse);
      });

      test('returns false for email without local part', () {
        expect(isEmail('@example.com'), isFalse);
      });
    });

    group('isGiphyFile', () {
      test('returns true for valid giphy gif URL', () {
        expect(
          isGiphyFile('https://media.giphy.com/media/xyz/giphy.gif'),
          isTrue,
        );
      });

      test('returns true for giphy jpg URL', () {
        expect(
          isGiphyFile('https://i.giphy.com/media/xyz/200.jpg'),
          isTrue,
        );
      });

      test('returns false for non-giphy URL', () {
        expect(
          isGiphyFile('https://example.com/image.gif'),
          isFalse,
        );
      });

      test('returns false for giphy URL without image extension', () {
        expect(
          isGiphyFile('https://giphy.com/gifs/xyz'),
          isFalse,
        );
      });
    });

    group('isPdfUrl', () {
      test('returns true for URL ending with .pdf', () {
        expect(isPdfUrl('https://example.com/document.pdf'), isTrue);
      });

      test('returns true for URL with .pdf and query params', () {
        expect(isPdfUrl('https://example.com/doc.pdf?token=abc'), isTrue);
      });

      test('returns true for URL with .pdf and hash', () {
        expect(isPdfUrl('https://example.com/doc.pdf#page=1'), isTrue);
      });

      test('returns false for non-pdf URL', () {
        expect(isPdfUrl('https://example.com/image.png'), isFalse);
      });

      test('is case insensitive', () {
        expect(isPdfUrl('https://example.com/DOC.PDF'), isTrue);
      });
    });

    group('listToGroupList', () {
      test('splits list into groups of specified size', () {
        final source = [1, 2, 3, 4, 5, 6];
        final result = listToGroupList(source, 2);
        expect(
          result,
          equals([
            [1, 2],
            [3, 4],
            [5, 6],
          ]),
        );
      });

      test('handles last group with fewer elements', () {
        final source = [1, 2, 3, 4, 5];
        final result = listToGroupList(source, 2);
        expect(
          result,
          equals([
            [1, 2],
            [3, 4],
            [5],
          ]),
        );
      });

      test('handles empty list', () {
        final source = <int>[];
        final result = listToGroupList(source, 3);
        expect(result, isEmpty);
      });

      test('handles group size larger than list', () {
        final source = [1, 2];
        final result = listToGroupList(source, 5);
        expect(
          result,
          equals([
            [1, 2],
          ]),
        );
      });
    });

    group('timestampToDateTime', () {
      test('converts unix timestamp to DateTime', () {
        const timestamp = 1704067200; // 2024-01-01 00:00:00 UTC
        final result = timestampToDateTime(timestamp);
        expect(result.year, equals(2024));
        expect(result.month, equals(1));
        expect(result.day, equals(1));
      });

      test('handles timestamp 0', () {
        final result = timestampToDateTime(0);
        expect(result, equals(DateTime.fromMillisecondsSinceEpoch(0)));
      });
    });
  });

  group('Utils', () {
    group('randomInt', () {
      test('returns an integer with correct number of digits', () {
        for (var length = 1; length <= 10; length++) {
          final result = Utils.randomInt(length);
          expect(result.toString().length, lessThanOrEqualTo(length));
        }
      });

      test('returns different values on multiple calls', () {
        final results = <int>{};
        for (var i = 0; i < 100; i++) {
          results.add(Utils.randomInt(6));
        }
        // With 100 calls, we expect to get multiple different values
        expect(results.length, greaterThan(1));
      });

      test('returns a number between expected bounds', () {
        const length = 3;
        final result = Utils.randomInt(length);
        expect(result, greaterThanOrEqualTo(0));
        expect(result, lessThan(1000)); // 10^length
      });
    });

    group('formartTextToLinkText', () {
      test('converts plain HTTP URL to markdown link', () {
        const input = 'Check out wss://example.com for more info';
        const expected =
            'Check out [wss://example.com](wss://example.com) for more info';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('converts plain HTTPS URL to markdown link', () {
        const input = 'Visit https://www.google.com today';
        const expected =
            'Visit [https://www.google.com](https://www.google.com) today';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('converts multiple URLs in the same text', () {
        const input = 'Check https://example.com and https://google.com';
        const expected =
            'Check [https://example.com](https://example.com) and [https://google.com](https://google.com)';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('preserves existing markdown links', () {
        const input = 'Visit [Google](https://google.com) for search';
        const expected = 'Visit [Google](https://google.com) for search';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('does not convert URLs already in markdown syntax', () {
        const input =
            'Check [this link](https://example.com) and https://google.com';
        const expected =
            'Check [this link](https://example.com) and [https://google.com](https://google.com)';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('handles URLs with query parameters', () {
        const input = 'Search https://example.com?q=test&lang=en';
        const expected =
            'Search [https://example.com?q=test&lang=en](https://example.com?q=test&lang=en)';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('handles URLs with hash fragments', () {
        const input = 'Go to https://example.com/page#section';
        const expected =
            'Go to [https://example.com/page#section](https://example.com/page#section)';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('handles URLs with paths', () {
        const input = 'Read https://example.com/blog/post/123';
        const expected =
            'Read [https://example.com/blog/post/123](https://example.com/blog/post/123)';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('handles different protocol schemes', () {
        const input = 'ftp://files.example.com and http://web.example.com';
        const expected =
            '[ftp://files.example.com](ftp://files.example.com) and [http://web.example.com](http://web.example.com)';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('returns empty string for empty input', () {
        const input = '';
        const expected = '';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('returns unchanged text without URLs', () {
        const input = 'This is just plain text without any links';
        const expected = 'This is just plain text without any links';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('handles URLs at the beginning of text', () {
        const input = 'https://example.com is a great site';
        const expected =
            '[https://example.com](https://example.com) is a great site';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('handles URLs at the end of text', () {
        const input = 'Visit our website at https://example.com';
        const expected =
            'Visit our website at [https://example.com](https://example.com)';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('handles URLs with special characters in path', () {
        const input = 'https://example.com/file-name_123.html';
        const expected =
            '[https://example.com/file-name_123.html](https://example.com/file-name_123.html)';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('handles URLs with port numbers', () {
        const input = 'Connect to https://example.com:8080/api';
        const expected =
            'Connect to [https://example.com:8080/api](https://example.com:8080/api)';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('handles mixed content with links and plain text', () {
        const input = '''
Keychat is the super app for Bitcoiners.
Autonomous IDs, Bitcoin ecash wallet, secure chat, and rich Mini Apps — all in Keychat.

Website: https://keychat.io

Chat with me: https://link.keychat.io/abc123
''';
        const expected = '''
Keychat is the super app for Bitcoiners.
Autonomous IDs, Bitcoin ecash wallet, secure chat, and rich Mini Apps — all in Keychat.

Website: [https://keychat.io](https://keychat.io)

Chat with me: [https://link.keychat.io/abc123](https://link.keychat.io/abc123)
''';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('does not convert invalid URLs', () {
        const input = 'This is not a url: ://invalid';
        const expected = 'This is not a url: ://invalid';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });

      test('handles URLs with authentication', () {
        const input = 'https://user:pass@example.com/path';
        const expected =
            '[https://user:pass@example.com/path](https://user:pass@example.com/path)';

        final result = Utils.formartTextToLinkText(input);

        expect(result, equals(expected));
      });
    });

    group('isValidDomain', () {
      test('returns true for valid domain', () {
        expect(Utils.isValidDomain('example.com'), isTrue);
      });

      test('returns true for subdomain', () {
        expect(Utils.isValidDomain('sub.example.com'), isTrue);
      });

      test('returns true for multi-level subdomain', () {
        expect(Utils.isValidDomain('a.b.c.example.com'), isTrue);
      });

      test('returns false for domain with double dots', () {
        expect(Utils.isValidDomain('example..com'), isFalse);
      });

      test('returns false for domain with double hyphens', () {
        expect(Utils.isValidDomain('exam--ple.com'), isFalse);
      });

      test('returns false for domain starting with hyphen', () {
        expect(Utils.isValidDomain('-example.com'), isFalse);
      });

      test('returns false for domain ending with hyphen', () {
        expect(Utils.isValidDomain('example-.com'), isFalse);
      });

      test('returns false for domain exceeding 253 characters', () {
        final longDomain = '${'a' * 250}.com';
        expect(Utils.isValidDomain(longDomain), isFalse);
      });

      test('returns false for invalid TLD', () {
        expect(Utils.isValidDomain('example.c'), isFalse);
      });
    });

    group('capitalizeFirstLetter', () {
      test('capitalizes first letter of lowercase string', () {
        expect(Utils.capitalizeFirstLetter('hello'), equals('Hello'));
      });

      test('returns same string if already capitalized', () {
        expect(Utils.capitalizeFirstLetter('Hello'), equals('Hello'));
      });

      test('returns empty string for empty input', () {
        expect(Utils.capitalizeFirstLetter(''), equals(''));
      });

      test('handles single character', () {
        expect(Utils.capitalizeFirstLetter('a'), equals('A'));
      });

      test('returns unchanged if first char is not a letter', () {
        expect(Utils.capitalizeFirstLetter('123abc'), equals('123abc'));
      });

      test('returns unchanged if first char is special', () {
        expect(Utils.capitalizeFirstLetter('@hello'), equals('@hello'));
      });
    });

    group('generateRandomString', () {
      test('generates string of correct length', () {
        final result = Utils.generateRandomString(10);
        expect(result.length, equals(10));
      });

      test('generates only alphabetic characters', () {
        final result = Utils.generateRandomString(100);
        expect(RegExp(r'^[A-Za-z]+$').hasMatch(result), isTrue);
      });

      test('generates different strings on multiple calls', () {
        final results = <String>{};
        for (var i = 0; i < 10; i++) {
          results.add(Utils.generateRandomString(20));
        }
        expect(results.length, greaterThan(1));
      });

      test('handles zero length', () {
        final result = Utils.generateRandomString(0);
        expect(result, equals(''));
      });
    });

    group('getDaysText', () {
      test('returns "Never" for 0 days', () {
        expect(Utils.getDaysText(0), equals('Never'));
      });

      test('returns "1 day" for 1 day', () {
        expect(Utils.getDaysText(1), equals('1 day'));
      });

      test('returns "X days" for multiple days', () {
        expect(Utils.getDaysText(5), equals('5 days'));
      });

      test('handles negative days as 0', () {
        expect(Utils.getDaysText(-5), equals('Never'));
      });
    });

    group('hexToString', () {
      test('converts hex to string', () {
        expect(Utils.hexToString('48656c6c6f'), equals('Hello'));
      });

      test('handles empty hex string', () {
        expect(Utils.hexToString(''), equals(''));
      });

      test('converts complex hex string', () {
        expect(
          Utils.hexToString('48656c6c6f20576f726c64'),
          equals('Hello World'),
        );
      });
    });

    group('hexToBytes', () {
      test('converts hex string to bytes', () {
        final result = Utils.hexToBytes('48656c6c6f');
        expect(result, equals([72, 101, 108, 108, 111]));
      });

      test('handles empty hex string', () {
        final result = Utils.hexToBytes('');
        expect(result, isEmpty);
      });

      test('throws for odd length hex string', () {
        expect(
          () => Utils.hexToBytes('abc'),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws for invalid hex characters', () {
        expect(
          () => Utils.hexToBytes('ghij'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('hexToUint8List', () {
      test('converts hex string to Uint8List', () {
        final result = Utils.hexToUint8List('48656c6c6f');
        expect(result, isA<Uint8List>());
        expect(result, equals(Uint8List.fromList([72, 101, 108, 108, 111])));
      });

      test('handles empty hex string', () {
        final result = Utils.hexToUint8List('');
        expect(result, isEmpty);
      });

      test('throws for odd length hex string', () {
        expect(
          () => Utils.hexToUint8List('abc'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('stringToHex', () {
      test('converts string to hex', () {
        expect(Utils.stringToHex('Hello'), equals('48656c6c6f'));
      });

      test('handles empty string', () {
        expect(Utils.stringToHex(''), equals(''));
      });

      test('converts string with spaces', () {
        expect(
          Utils.stringToHex('Hello World'),
          equals('48656c6c6f20576f726c64'),
        );
      });
    });

    group('unit8ListToHex', () {
      test('converts Uint8List to hex string', () {
        final input = Uint8List.fromList([72, 101, 108, 108, 111]);
        expect(Utils.unit8ListToHex(input), equals('48656c6c6f'));
      });

      test('handles empty Uint8List', () {
        final input = Uint8List(0);
        expect(Utils.unit8ListToHex(input), equals(''));
      });

      test('pads single digit hex values with zero', () {
        final input = Uint8List.fromList([0, 1, 15]);
        expect(Utils.unit8ListToHex(input), equals('00010f'));
      });
    });

    group('regrexLetter', () {
      test('returns first 2 characters by default', () {
        expect(Utils.regrexLetter('Hello'), equals('He'));
      });

      test('returns custom length characters', () {
        expect(Utils.regrexLetter('Hello', 3), equals('Hel'));
      });

      test('returns full string if shorter than length', () {
        expect(Utils.regrexLetter('Hi', 5), equals('Hi'));
      });

      test('returns single char if string length is 1', () {
        expect(Utils.regrexLetter('H', 2), equals('H'));
      });
    });

    group('randomString', () {
      test('generates string of correct length', () {
        final result = Utils.randomString(10);
        expect(result.length, equals(10));
      });

      test('generates only lowercase alphanumeric characters', () {
        final result = Utils.randomString(100);
        expect(RegExp(r'^[a-z0-9]+$').hasMatch(result), isTrue);
      });

      test('generates different strings on multiple calls', () {
        final results = <String>{};
        for (var i = 0; i < 10; i++) {
          results.add(Utils.randomString(20));
        }
        expect(results.length, greaterThan(1));
      });
    });

    group('getIntersection', () {
      test('returns intersection of two lists', () {
        final list1 = ['a', 'b', 'c', 'd'];
        final list2 = ['b', 'c', 'e', 'f'];
        final result = Utils.getIntersection(list1, list2);
        expect(result, containsAll(['b', 'c']));
        expect(result.length, equals(2));
      });

      test('returns empty list for no intersection', () {
        final list1 = ['a', 'b'];
        final list2 = ['c', 'd'];
        final result = Utils.getIntersection(list1, list2);
        expect(result, isEmpty);
      });

      test('handles empty first list', () {
        final list1 = <String>[];
        final list2 = ['a', 'b'];
        final result = Utils.getIntersection(list1, list2);
        expect(result, isEmpty);
      });

      test('handles empty second list', () {
        final list1 = ['a', 'b'];
        final list2 = <String>[];
        final result = Utils.getIntersection(list1, list2);
        expect(result, isEmpty);
      });
    });
  });
}
