import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/message.dart';

void main() {
  group('MessageMediaType', () {
    test('audio enum value exists', () {
      expect(MessageMediaType.audio, isNotNull);
      expect(MessageMediaType.values.contains(MessageMediaType.audio), isTrue);
    });

    test('audio enum has correct name', () {
      expect(MessageMediaType.audio.name, 'audio');
    });

    test('audio enum ordinal is after messageReaction', () {
      final reactionIndex = MessageMediaType.values.indexOf(
        MessageMediaType.messageReaction,
      );
      final audioIndex = MessageMediaType.values.indexOf(
        MessageMediaType.audio,
      );
      expect(audioIndex, greaterThan(reactionIndex));
    });

    test('audio is the last enum value', () {
      expect(MessageMediaType.values.last, MessageMediaType.audio);
    });

    test('all original enum values still exist', () {
      // Verify adding audio did not break existing values
      final expected = [
        'text',
        'cashu',
        'image',
        'video',
        'contact',
        'pdf',
        'setPostOffice',
        'groupInvite',
        'file',
        'groupInviteConfirm',
        'botText',
        'botPricePerMessageRequest',
        'botSelectionRequest',
        'botOneTimePaymentRequest',
        'groupInvitationInfo',
        'groupInvitationRequesting',
        'lightningInvoice',
        'profileRequest',
        'messageReaction',
        'audio',
      ];
      final actual = MessageMediaType.values.map((v) => v.name).toList();
      expect(actual, expected);
    });
  });
}
