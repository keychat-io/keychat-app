import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/models/embedded/msg_reply.dart';

void main() {
  const eventId = 'event_abc123';
  const userId = 'user_xyz789';
  const userName = 'Bob';
  const content = 'Hello, world!';

  group('MsgReply JSON serialization', () {
    test('fromJson with new field names (eventId, userId, userName)', () {
      final json = {
        'eventId': eventId,
        'userId': userId,
        'userName': userName,
        'content': content,
      };

      final reply = MsgReply.fromJson(json);

      expect(reply.eventId, eventId);
      expect(reply.userId, userId);
      expect(reply.userName, userName);
      expect(reply.content, content);
    });

    test('fromJson with legacy field names (id, user)', () {
      final json = {
        'id': eventId,
        'user': userId,
        'content': content,
      };

      final reply = MsgReply.fromJson(json);

      expect(reply.eventId, eventId);
      expect(reply.userId, userId);
      expect(reply.content, content);
    });

    test('toJson outputs both new and legacy keys', () {
      final reply = MsgReply()
        ..eventId = eventId
        ..userId = userId
        ..userName = userName
        ..content = content;

      final json = reply.toJson();

      // New keys
      expect(json['eventId'], eventId);
      expect(json['userId'], userId);
      expect(json['userName'], userName);
      expect(json['content'], content);

      // Legacy keys
      expect(json['id'], eventId);
      expect(json['user'], userId);
    });

    test('fromJson -> toJson roundtrip', () {
      final original = MsgReply()
        ..eventId = eventId
        ..userId = userId
        ..userName = userName
        ..content = content;

      final json = original.toJson();
      final restored = MsgReply.fromJson(json);

      expect(restored.eventId, original.eventId);
      expect(restored.userId, original.userId);
      expect(restored.userName, original.userName);
      expect(restored.content, original.content);
    });

    test('nullable fields: eventId=null, userId=null', () {
      final reply = MsgReply()..content = content;

      final json = reply.toJson();

      // With includeIfNull: false, null new keys should be absent
      expect(json.containsKey('eventId'), isFalse);
      expect(json.containsKey('userId'), isFalse);
      expect(json.containsKey('userName'), isFalse);

      // Legacy keys are always written (even as null / empty)
      expect(json['id'], isNull);
      expect(json['user'], '');

      // Roundtrip with nulls
      final restored = MsgReply.fromJson(json);
      expect(restored.eventId, isNull);
      expect(restored.content, content);
    });
  });
}
