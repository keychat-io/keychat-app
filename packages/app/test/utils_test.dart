import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/Utils.dart';

void main() {
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
  });
}
