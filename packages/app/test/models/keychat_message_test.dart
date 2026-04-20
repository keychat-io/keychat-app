import 'dart:convert' show jsonDecode;

import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/constants.dart';
import 'package:keychat/models/embedded/msg_reply.dart';
import 'package:keychat/models/keychat/keychat_message.dart';
import 'package:keychat/models/keychat/qrcode_user_model.dart';
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

  group('setHelloMessage backward-compat wire format', () {
    // setHelloMessagge depends on services (GetX, SignalIdService, etc.)
    // that cannot run in a pure unit test. Instead, we simulate the exact
    // `data` map it assembles at keychat_message.dart (identity fields +
    // SignalIdService.getQRCodeData legacy-keyed output) and verify that
    // QRUserModel.toString() still emits every legacy key old clients
    // need to decode the hello message.
    Map<String, dynamic> assembleHelloData() => {
          // Identity fields — new names (keychat_message.dart:92-101)
          'name': 'Alice',
          'nostrIdentityKey': 'nostr_identity_key_hex',
          'signalIdentityKey': 'signal_identity_key_hex',
          'receiveAddress': 'receive_address_hex',
          'time': 1700000000,
          'relay': 'wss://relay.example.com',
          'lightning': '',
          'avatar': '',
          'globalSign': 'global_sign_value',
          // Signal prekey fields — legacy names
          // (SignalIdService.getQRCodeData still emits legacy keys)
          'signedId': 42,
          'signedPublic': 'signed_prekey_hex',
          'signedSignature': 'signed_prekey_sig_hex',
          'prekeyId': 7,
          'prekeyPubkey': 'one_time_prekey_hex',
        };

    test('hello data parses via QRUserModel', () {
      final model = QRUserModel.fromJson(assembleHelloData());
      expect(model.name, 'Alice');
      expect(model.nostrIdentityKey, 'nostr_identity_key_hex');
      expect(model.signalIdentityKey, 'signal_identity_key_hex');
      expect(model.receiveAddress, 'receive_address_hex');
      expect(model.signalSignedPrekeyId, 42);
      expect(model.signalOneTimePrekeyId, 7);
    });

    test('hello message JSON contains every legacy key old clients expect',
        () {
      // Mirrors keychat_message.dart: name = QRUserModel.fromJson(data).toString()
      final helloJson = QRUserModel.fromJson(assembleHelloData()).toJson();

      // Identity legacy aliases
      expect(helloJson['pubkey'], 'nostr_identity_key_hex');
      expect(helloJson['curve25519PkHex'], 'signal_identity_key_hex');
      expect(helloJson['onetimekey'], 'receive_address_hex');
      // Signal prekey legacy aliases
      expect(helloJson['signedId'], 42);
      expect(helloJson['signedPublic'], 'signed_prekey_hex');
      expect(helloJson['signedSignature'], 'signed_prekey_sig_hex');
      expect(helloJson['prekeyId'], 7);
      expect(helloJson['prekeyPubkey'], 'one_time_prekey_hex');
    });
  });
}
