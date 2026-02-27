import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/constants.dart';
import 'package:keychat/service/SignerService.dart';

void main() {
  group('NIP-17 Rumor Kind Tests', () {
    test('EventKinds.chatRumor should equal 14', () {
      expect(EventKinds.chatRumor, equals(14));
    });

    test('EventKinds.nip17 (gift wrap) should equal 1059', () {
      expect(EventKinds.nip17, equals(1059));
    });

    test('chatRumor (14) should not equal nip17 (1059)', () {
      expect(EventKinds.chatRumor, isNot(equals(EventKinds.nip17)));
    });

    test('Correct NIP-17/59 kind hierarchy', () {
      // Rumor (inner layer) should be kind 14
      expect(EventKinds.chatRumor, equals(14));

      // Gift Wrap (outer layer) should be kind 1059
      expect(EventKinds.nip17, equals(1059));

      // Seal should be kind 13 (defined elsewhere)
      // NIP-59 spec: Rumor (14) → Seal (13) → Gift Wrap (1059)
    });

    test('Amber rumor structure uses kind 14 and p-tag', () {
      final rumor = SignerService.instance.buildRumorEventForTesting(
        content: 'hello',
        from: 'sender_pubkey',
        to: 'receiver_pubkey',
      );

      expect(rumor['kind'], equals(EventKinds.chatRumor));
      expect(rumor['pubkey'], equals('sender_pubkey'));
      expect(rumor['content'], equals('hello'));
      expect(rumor['created_at'], isA<int>());

      final tags = rumor['tags'] as List<dynamic>;
      expect(tags, isNotEmpty);
      final firstTag = tags.first as List<dynamic>;
      expect(firstTag[0], equals('p'));
      expect(firstTag[1], equals('receiver_pubkey'));
    });
  });
}
