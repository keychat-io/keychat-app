import 'package:app/constants.dart';
import 'package:app/nostr-core/nostr_nip4_req.dart';
import 'package:app/utils.dart' show Utils, generate64RandomHexChars;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  test('Can call rust function', () async {
    final req = NostrReqModel(
      reqId: generate64RandomHexChars(16),
      authors: [
        '36b48ff102d063d123f30dcff1e92849af5edf5914540723f87ee896fb0141fa',
      ],
      kinds: [EventKinds.mlsNipKeypackages],
      limit: 1,
      since: DateTime.now().subtract(const Duration(days: 365)),
    );
    debugPrint(req.toString());
  });

  group('isValidDomain tests', () {
    test('Valid domains should return true', () {
      expect(Utils.isValidDomain('example.com'), isTrue);
      expect(
        Utils.isValidDomain('sub.example.com'),
        isTrue,
      ); // subdomains now supported
      expect(Utils.isValidDomain('example-site.com'), isTrue);
      expect(Utils.isValidDomain('example123.org'), isTrue);
      expect(
        Utils.isValidDomain('my-domain-name.co.uk'),
        isTrue,
      ); // multi-level domains supported
      expect(Utils.isValidDomain('domain.io'), isTrue);
      expect(
        Utils.isValidDomain('sub.sub.example.com'),
        isTrue,
      ); // third-level domain
      expect(
        Utils.isValidDomain('a.b.c.example.org'),
        isTrue,
      ); // fourth-level domain
    });

    test('Domains that are too long should return false', () {
      // Generate a domain that exceeds 253 characters
      final longLabel = 'a' * 240;
      final longDomain = '$longLabel.com';
      expect(Utils.isValidDomain(longDomain), isFalse);
    });

    test('Domains with invalid characters should return false', () {
      expect(Utils.isValidDomain('example!.com'), isFalse);
      expect(Utils.isValidDomain('exa mple.com'), isFalse);
      expect(Utils.isValidDomain('example_.com'), isFalse);
      expect(Utils.isValidDomain('exam@ple.com'), isFalse);
      expect(Utils.isValidDomain('example..com'), isFalse);
    });

    test('Domains with consecutive dots or hyphens should return false', () {
      expect(Utils.isValidDomain('example..com'), isFalse);
      expect(Utils.isValidDomain('example--site.com'), isFalse);
    });

    test('Domains that start or end with a hyphen should return false', () {
      expect(Utils.isValidDomain('-example.com'), isFalse);
      expect(Utils.isValidDomain('example-.com'), isFalse);
      expect(Utils.isValidDomain('example.-com'), isFalse);
    });

    test('normal string should return false', () {
      expect(Utils.isValidDomain('1234'), isFalse);
      expect(Utils.isValidDomain('sdsds sddsd'), isFalse);
      expect(Utils.isValidDomain('aasdd dsd .m'), isFalse);
    });
  });
}
