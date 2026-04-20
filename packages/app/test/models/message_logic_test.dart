import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/message.dart';

void main() {
  group('Message.convertToMsgFileInfo', () {
    Message makeMessage(String content) {
      return Message(
        content: content,
        roomId: 1,
        identityId: 1,
        msgid: 'test_msg_id',
        idPubkey: 'pubkey',
        from: 'sender',
        to: 'receiver',
        createdAt: DateTime.now(),
        sent: SendStatusType.success,
        eventIds: const <String>[],
        encryptType: MessageEncryptType.signal,
        rawEvents: const <String>[],
      );
    }

    /// Full keychat media URL with all required query parameters.
    String makeMediaUrl({String type = 'image'}) =>
        'https://relay.example.com/file.enc'
        '?kctype=$type&iv=abc123&key=def456&hash=h1&size=1024&sourceName=photo.jpg';

    test('returns MsgFileInfo for valid keychat media URL', () {
      final msg = makeMessage(makeMediaUrl());
      final mfi = msg.convertToMsgFileInfo();
      expect(mfi, isNotNull);
      expect(mfi!.type, equals('image'));
      expect(mfi.url, equals('https://relay.example.com/file.enc'));
      expect(mfi.iv, equals('abc123'));
      expect(mfi.key, equals('def456'));
    });

    test('returns null for URL without kctype parameter', () {
      final msg = makeMessage('https://example.com/file.enc?iv=abc');
      expect(msg.convertToMsgFileInfo(), isNull);
    });

    test('returns null for URL without query parameters', () {
      final msg = makeMessage('https://example.com/file.enc');
      expect(msg.convertToMsgFileInfo(), isNull);
    });

    test('returns null for plain text', () {
      final msg = makeMessage('hello world');
      expect(msg.convertToMsgFileInfo(), isNull);
    });

    test('returns null for empty content', () {
      final msg = makeMessage('');
      expect(msg.convertToMsgFileInfo(), isNull);
    });

    test('handles video type', () {
      final msg = makeMessage(makeMediaUrl(type: 'video'));
      final mfi = msg.convertToMsgFileInfo();
      expect(mfi, isNotNull);
      expect(mfi!.type, equals('video'));
    });
  });
}
