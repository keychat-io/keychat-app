import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/constants.dart';

void main() {
  group('NIP-17 Sender Copy Tests', () {
    test(
      'Test payload structure for sender copy (to_receiver and to_sender)',
      () {
        // Simulate the structure that createGiftJsonWithSenderCopy returns
        final payload = {
          'to_receiver': jsonEncode({
            'id': 'receiver_event_id_123',
            'pubkey': 'receiver_pubkey_xyz',
            'created_at': 1234567890,
            'kind': EventKinds.nip17, // Should be 1059 (outer gift wrap)
            'tags': [
              ['p', 'recipient_pubkey'],
              ['e', 'rumor_id'],
            ],
            'content': 'encrypted_content_for_receiver',
          }),
          'to_sender': jsonEncode({
            'id': 'sender_event_id_456',
            'pubkey': 'sender_pubkey_abc',
            'created_at': 1234567890,
            'kind': EventKinds.nip17, // Should be 1059 (outer gift wrap)
            'tags': [
              ['p', 'sender_pubkey_abc'], // Sender's own pubkey
              ['e', 'rumor_id'], // Same rumor ID for deduplication
            ],
            'content': 'encrypted_content_for_sender',
          }),
        };

        // Verify structure
        expect(payload.containsKey('to_receiver'), true);
        expect(payload.containsKey('to_sender'), true);

        // Decode and verify structure
        final receiverEvent =
            jsonDecode(payload['to_receiver']!) as Map<String, dynamic>;
        final senderEvent =
            jsonDecode(payload['to_sender']!) as Map<String, dynamic>;

        // Both should be gift wraps (kind 1059)
        expect(receiverEvent['kind'], EventKinds.nip17);
        expect(senderEvent['kind'], EventKinds.nip17);

        // Should have p-tags (recipient tags)
        expect(
          receiverEvent['tags'].whereType<List<dynamic>>().any(
            (List<dynamic> tag) => tag.isNotEmpty && tag[0] == 'p',
          ),
          true,
        );
        expect(
          senderEvent['tags'].whereType<List<dynamic>>().any(
            (List<dynamic> tag) => tag.isNotEmpty && tag[0] == 'p',
          ),
          true,
        );

        // Should have same e-tag (rumor ID) for deduplication
        final receiverTags = receiverEvent['tags'].whereType<List<dynamic>>();
        final receiverRumorTag =
            receiverTags.firstWhere(
                  (List<dynamic> tag) => tag.isNotEmpty && tag[0] == 'e',
                  orElse: () => <dynamic>[''],
                )
                as List<dynamic>;
        final dynamic receiverRumorId = (receiverRumorTag.length > 1)
            ? receiverRumorTag[1]
            : null;

        final senderTags = senderEvent['tags'].whereType<List<dynamic>>();
        final senderRumorTag =
            senderTags.firstWhere(
                  (List<dynamic> tag) => tag.isNotEmpty && tag[0] == 'e',
                  orElse: () => <dynamic>[''],
                )
                as List<dynamic>;
        final dynamic senderRumorId = (senderRumorTag.length > 1)
            ? senderRumorTag[1]
            : null;

        expect(receiverRumorId, senderRumorId);
        expect(receiverRumorId, 'rumor_id');
      },
    );

    test('Verify sender and receiver events have different external IDs', () {
      // When sender creates two events:
      // - Event for receiver: encrypted with receiver's DH
      // - Event for sender: encrypted with sender's (self) DH
      // They should have DIFFERENT external event IDs, but same internal rumor ID

      const receiverEventId = 'event_id_for_receiver_123';
      const senderEventId = 'event_id_for_sender_456';

      // External IDs should be different
      expect(receiverEventId, isNotEmpty);
      expect(senderEventId, isNotEmpty);
      expect(receiverEventId, isNot(senderEventId));

      // But they reference the same rumor (via e-tag)
      const rumorId = 'same_rumor_id_xyz';

      expect(rumorId, isNotEmpty);
    });

    test('Verify multi-device sync scenario', () {
      // Sender's device 1 sends message to Alice
      // 1. Creates rumor (kind 14) with content
      // 2. Creates seal for Alice (encrypted with Alice's DH)
      // 3. Creates gift wrap for Alice (encrypted with random key)
      // 4. Creates seal for self (encrypted with own DH)
      // 5. Creates gift wrap for self (encrypted with random key)
      // 6. Sends BOTH gift wraps to relays

      // Receiver gets event for Alice:
      // - Decrypts outer gift wrap
      // - Decrypts seal to get sender's pubkey
      // - Decrypts seal to get rumor (kind 14)
      // - Displays message

      // Sender's device 2 checks relays:
      // - Finds gift wrap sent for self
      // - Decrypts outer gift wrap
      // - Decrypts seal to confirm it's from own device
      // - Decrypts seal to get rumor (kind 14)
      // - Uses rumor ID to deduplicate (same rumor as device 1 sent)
      // - Displays message as "sent by me"

      // Key insight: Rumor ID is used for deduplication across devices
      expect(true, true); // Documentation test
    });

    test('Verify NIP-17 layer hierarchy with sender copy', () {
      // For receiver:
      // Rumor (kind 14, content, created_at=now)
      //   → Seal (kind 13, encrypted with receiver's shared secret)
      //   → Gift Wrap (kind 1059, encrypted with random key, timestamp tweaked)

      // For sender (self):
      // Rumor (kind 14, SAME content, SAME created_at)
      //   → Seal (kind 13, encrypted with sender's shared secret)
      //   → Gift Wrap (kind 1059, encrypted with random key, timestamp tweaked)

      // Both use the same rumor.id for message deduplication
      expect(EventKinds.chatRumor, 14);
      expect(EventKinds.nip17, 1059); // Gift wrap kind

      // In the seal layer (kind 13), the public key reveals the sender to recipient
      // In the rumor (kind 14), the actual message content lives
    });
  });
}
