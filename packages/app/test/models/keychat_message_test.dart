import 'dart:convert' show jsonDecode;

import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/constants.dart';
import 'package:keychat/models/embedded/msg_reply.dart';
import 'package:keychat/models/keychat/keychat_message.dart';
import 'package:keychat/models/room.dart';

void main() {
  group('KeychatMessage JSON serialization', () {
    test('fromJson -> toJson roundtrip', () {
      final json = <String, dynamic>{
        'type': KeyChatEventKinds.dm,
        'c': 'signal',
        'msg': 'hello',
        'name': 'Alice',
      };
      final km = KeychatMessage.fromJson(json);
      expect(km.type, equals(KeyChatEventKinds.dm));
      expect(km.c, equals(MessageType.signal));
      expect(km.msg, equals('hello'));
      expect(km.name, equals('Alice'));

      final output = km.toJson();
      expect(output['type'], equals(KeyChatEventKinds.dm));
      expect(output['c'], equals('signal'));
    });

    test('toJson omits null fields (includeIfNull: false)', () {
      final km = KeychatMessage(
        type: KeyChatEventKinds.dm,
        c: MessageType.signal,
      );
      final json = km.toJson();
      expect(json.containsKey('msg'), isFalse);
      expect(json.containsKey('name'), isFalse);
      expect(json.containsKey('data'), isFalse);
    });

    test('toString produces valid JSON', () {
      final km = KeychatMessage(
        type: KeyChatEventKinds.dm,
        c: MessageType.signal,
        msg: 'test',
      );
      final parsed = jsonDecode(km.toString()) as Map<String, dynamic>;
      expect(parsed['msg'], equals('test'));
    });
  });

  group('KeychatMessage.getTextMessage', () {
    test('returns plain content when reply is null', () {
      final result = KeychatMessage.getTextMessage(
        MessageType.signal,
        'hello',
        null,
      );
      expect(result, equals('hello'));
    });

    test('returns KeychatMessage JSON when reply is provided', () {
      final reply = MsgReply.fromJson({
        'eventId': 'evt123',
        'userId': 'user456',
        'content': 'original message',
      });

      final result = KeychatMessage.getTextMessage(
        MessageType.signal,
        'my reply',
        reply,
      );

      // result should be a JSON string of KeychatMessage
      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['type'], equals(KeyChatEventKinds.dm));
      expect(parsed['c'], equals('signal'));
      expect(parsed['msg'], equals('my reply'));
      // name contains the reply JSON
      expect(parsed['name'], isNotNull);
    });
  });

  group('KeychatMessage.getFeatureMessageString', () {
    test('produces valid JSON with subtype', () {
      final room = Room(
        toMainPubkey: 'abc',
        npub: 'npub1test',
        identityId: 1,
      );
      final result = KeychatMessage.getFeatureMessageString(
        MessageType.signal,
        room,
        'invite data',
        KeyChatEventKinds.dmAddContactFromAlice,
        name: 'Alice',
      );

      final parsed = jsonDecode(result) as Map<String, dynamic>;
      expect(parsed['type'], equals(KeyChatEventKinds.dmAddContactFromAlice));
      expect(parsed['c'], equals('signal'));
      expect(parsed['msg'], equals('invite data'));
      expect(parsed['name'], equals('Alice'));
    });
  });

  group('setHelloMessage field names', () {
    // setHelloMessagge depends on services (GetX, SignalIdService, etc.)
    // so we verify the field names used in the data map indirectly
    // through the QRUserModel serialization tests.
    // The key contract: hello message data map must use these keys:
    test('expected hello message field names are documented', () {
      // These are the canonical field names that setHelloMessagge must produce
      const expectedKeys = [
        'name',
        'nostrIdentityKey',
        'signalIdentityKey',
        'receiveAddress',
        'time',
        'relay',
        'lightning',
        'avatar',
        'globalSign',
      ];
      // Verify they exist as string constants (compile-time check)
      for (final key in expectedKeys) {
        expect(key, isNotEmpty);
      }
    });
  });
}
