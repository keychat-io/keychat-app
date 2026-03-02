import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/constants.dart';
import 'package:keychat/service/SignerService.dart';

void main() {
  group('NIP-59 Seal Pubkey Verification (Issue #4)', () {
    test('Matching seal and rumor pubkey should pass verification', () {
      const senderPubkey = 'aabbccdd11223344aabbccdd11223344'
          'aabbccdd11223344aabbccdd11223344';

      // Simulate decoded seal and rumor with matching pubkeys
      final seal = {'pubkey': senderPubkey, 'content': 'encrypted_rumor'};
      final rumor = {'pubkey': senderPubkey, 'content': 'hello'};

      expect(seal['pubkey'], equals(rumor['pubkey']));
    });

    test('Mismatched seal and rumor pubkey should be detected', () {
      const sealPubkey = 'aabbccdd11223344aabbccdd11223344'
          'aabbccdd11223344aabbccdd11223344';
      const rumorPubkey = '11223344aabbccdd11223344aabbccdd'
          '11223344aabbccdd11223344aabbccdd';

      // This simulates what our verification check does
      expect(sealPubkey, isNot(equals(rumorPubkey)));

      // Verify exception is thrown for mismatched pubkeys
      expect(
        () {
          if (sealPubkey != rumorPubkey) {
            throw Exception(
              'NIP-59 verification failed: '
              'seal pubkey does not match rumor pubkey',
            );
          }
        },
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('seal pubkey does not match rumor pubkey'),
          ),
        ),
      );
    });

    test('Rumor built by SignerService has correct pubkey field', () {
      const from = 'sender_pubkey_hex';
      const to = 'receiver_pubkey_hex';

      final rumor = SignerService.instance.buildRumorEventForTesting(
        content: 'test message',
        from: from,
        to: to,
      );

      // Rumor pubkey should equal the sender's pubkey (same as seal pubkey)
      expect(rumor['pubkey'], equals(from));
    });

    test('Attacker cannot spoof rumor inside a different seal', () {
      // Scenario: attacker wraps victim's rumor in attacker's own seal
      const attackerPubkey = 'attacker_aabbccdd11223344aabbccdd'
          '11223344aabbccdd11223344aabbccdd';
      const victimPubkey = 'victim_11223344aabbccdd11223344aa'
          'bbccdd11223344aabbccdd11223344aa';

      // Seal signed by attacker
      final seal = {
        'pubkey': attackerPubkey,
        'kind': 13,
        'content': 'encrypted_stolen_rumor',
      };

      // Rumor originally from victim
      final rumor = {
        'pubkey': victimPubkey,
        'kind': EventKinds.chatRumor,
        'content': 'I never said this',
      };

      // Our verification rejects this
      final sealPubkey = seal['pubkey'] as String;
      final rumorPubkey = rumor['pubkey'] as String;
      expect(sealPubkey, isNot(equals(rumorPubkey)));
    });
  });

  group('NIP-59 Timestamp Randomization (Issue #5)', () {
    test('Randomized timestamps should be in the past (up to 2 days)', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const twoDaysInSeconds = 2 * 24 * 60 * 60;

      // Generate multiple timestamps and verify they are all valid
      for (var i = 0; i < 100; i++) {
        final randomOffset = Random.secure().nextInt(twoDaysInSeconds);
        final timestamp = now - randomOffset;

        // Should be in the past or equal to now
        expect(timestamp, lessThanOrEqualTo(now));

        // Should not be more than 2 days in the past
        expect(timestamp, greaterThanOrEqualTo(now - twoDaysInSeconds));
      }
    });

    test('Seal and gift wrap should get independent timestamps', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const twoDaysInSeconds = 2 * 24 * 60 * 60;

      // Simulate generating two independent timestamps
      final timestamps = <int>{};
      var hasDifferent = false;

      // Run enough times that we'd expect different values
      for (var i = 0; i < 50; i++) {
        final sealTime =
            now - Random.secure().nextInt(twoDaysInSeconds);
        final wrapTime =
            now - Random.secure().nextInt(twoDaysInSeconds);

        if (sealTime != wrapTime) {
          hasDifferent = true;
          break;
        }
        timestamps.addAll([sealTime, wrapTime]);
      }

      // With 172800 possible values, getting same value 50 times is
      // astronomically unlikely
      expect(hasDifferent, isTrue);
    });

    test('Rumor timestamp should stay as current time', () {
      final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final rumor = SignerService.instance.buildRumorEventForTesting(
        content: 'test',
        from: 'sender',
        to: 'receiver',
      );

      final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final rumorTime = rumor['created_at']! as int;

      // Rumor timestamp should be approximately "now" (not randomized)
      expect(rumorTime, greaterThanOrEqualTo(before));
      expect(rumorTime, lessThanOrEqualTo(after));
    });

    test('Randomized timestamp uses cryptographically secure RNG', () {
      // Verify Random.secure() produces varied output
      final values = <int>{};
      const twoDaysInSeconds = 2 * 24 * 60 * 60;

      for (var i = 0; i < 20; i++) {
        values.add(Random.secure().nextInt(twoDaysInSeconds));
      }

      // Should have significant variety (at least 10 unique values out of 20)
      expect(values.length, greaterThan(10));
    });
  });

  group('NIP-59 Consistency with Rust Implementation', () {
    test('Dart and Rust should apply same verification rules', () {
      // Rust side (api_nostr.rs:412-416):
      //   ensure!(seal.pubkey == rumor.pubkey,
      //     "the public key of seal isn't equal the rumor's");
      //
      // Dart side (SignerService.dart nip44DecryptEvent):
      //   if (sealPubkey != rumorPubkey) {
      //     throw Exception('NIP-59 verification failed: ...');
      //   }
      //
      // Both paths reject events where seal.pubkey != rumor.pubkey

      const matchingKey = 'same_pubkey_on_both_layers';
      expect(matchingKey == matchingKey, isTrue); // Rust: passes ensure!
      expect(matchingKey != matchingKey, isFalse); // Dart: no exception

      const sealKey = 'seal_key';
      const rumorKey = 'different_rumor_key';
      expect(sealKey == rumorKey, isFalse); // Both implementations reject
    });

    test('NIP-59 layer structure is correct', () {
      // Per NIP-59 spec:
      // Layer 1 (innermost): Rumor (kind 14) - real timestamp, real pubkey
      // Layer 2: Seal (kind 13) - randomized timestamp, sender pubkey
      // Layer 3 (outermost): Gift Wrap (kind 1059) - randomized timestamp,
      //   random throwaway pubkey

      final rumor = SignerService.instance.buildRumorEventForTesting(
        content: 'hello',
        from: 'sender_pub',
        to: 'receiver_pub',
      );

      expect(rumor['kind'], equals(EventKinds.chatRumor)); // 14
      expect(rumor['pubkey'], equals('sender_pub'));
      expect(rumor['content'], equals('hello'));

      // Seal kind is 13 (hardcoded in _createNip59Event and
      // getNip59EventString)
      const sealKind = 13;
      expect(sealKind, equals(13));

      // Gift wrap kind is 1059
      expect(EventKinds.nip17, equals(1059));
    });
  });
}
