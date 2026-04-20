import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keychat/constants.dart';
import 'package:keychat/models/message.dart';
import 'package:keychat/nostr-core/nostr_event.dart';

void main() {
  const testId =
      '4b697394206581b03ca5222b37449a9cdca1741b122d78defc177444e2536f49';
  const testPubkey =
      '981CC2078AF05B62EE1F98CFF325AAC755BF5C5836A265C254447B5933C6223B';
  const testPubkeyLower =
      '981cc2078af05b62ee1f98cff325aac755bf5c5836a265c254447b5933c6223b';
  const testCreatedAt = 1672175320;
  const testKind = 1;
  final testTags = <List<String>>[
    ['p', 'abc123', 'wss://relay.example.com'],
    ['e', 'def456'],
  ];
  const testContent = 'Hello, Nostr!';
  const testSig =
      '797c47bef50eff748b8af0f38edcb390facf664b2367d72eb71c50b5f37bc83c';

  Map<String, dynamic> buildJsonMap() => {
    'id': testId,
    'pubkey': testPubkeyLower,
    'created_at': testCreatedAt,
    'kind': testKind,
    'tags': testTags,
    'content': testContent,
    'sig': testSig,
  };

  group('NostrEventModel', () {
    group('constructor', () {
      test('pubkey is lowercased', () {
        final event = NostrEventModel(
          testId,
          testPubkey,
          testCreatedAt,
          testKind,
          testTags,
          testContent,
          testSig,
          verify: false,
        );

        expect(event.pubkey, equals(testPubkeyLower));
      });
    });

    group('fromJson', () {
      test('constructs event with all fields', () {
        final json = buildJsonMap();
        final event = NostrEventModel.fromJson(json, verify: false);

        expect(event.id, equals(testId));
        expect(event.pubkey, equals(testPubkeyLower));
        expect(event.createdAt, equals(testCreatedAt));
        expect(event.kind, equals(testKind));
        expect(event.tags, equals(testTags));
        expect(event.content, equals(testContent));
        expect(event.sig, equals(testSig));
      });

      test('pubkey is lowercased', () {
        final json = buildJsonMap();
        json['pubkey'] = testPubkey; // uppercase
        final event = NostrEventModel.fromJson(json, verify: false);

        expect(event.pubkey, equals(testPubkeyLower));
      });
    });

    group('toJson', () {
      test('serializes all fields with correct key names', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          testKind,
          testTags,
          testContent,
          testSig,
          verify: false,
        );

        final json = event.toJson();

        expect(json['id'], equals(testId));
        expect(json['pubkey'], equals(testPubkeyLower));
        expect(json['created_at'], equals(testCreatedAt));
        expect(json['kind'], equals(testKind));
        expect(json['tags'], equals(testTags));
        expect(json['content'], equals(testContent));
        expect(json['sig'], equals(testSig));
        // Ensure snake_case key is used, not camelCase
        expect(json.containsKey('createdAt'), isFalse);
      });

      test('fromJson -> toJson roundtrip preserves data', () {
        final original = buildJsonMap();
        final event = NostrEventModel.fromJson(original, verify: false);
        final result = event.toJson();

        expect(result['id'], equals(original['id']));
        expect(result['pubkey'], equals(original['pubkey']));
        expect(result['created_at'], equals(original['created_at']));
        expect(result['kind'], equals(original['kind']));
        expect(result['tags'], equals(original['tags']));
        expect(result['content'], equals(original['content']));
        expect(result['sig'], equals(original['sig']));
      });
    });

    group('deserialize', () {
      test('from ["EVENT", json] (length 2)', () {
        final json = buildJsonMap();
        final input = ['EVENT', json];

        final event = NostrEventModel.deserialize(input, verify: false);

        expect(event.id, equals(testId));
        expect(event.pubkey, equals(testPubkeyLower));
        expect(event.subscriptionId, isNull);
      });

      test('from ["EVENT", subId, json] (length 3) preserves subscriptionId',
          () {
        final json = buildJsonMap();
        final input = ['EVENT', 'sub_abc', json];

        final event = NostrEventModel.deserialize(input, verify: false);

        expect(event.id, equals(testId));
        expect(event.subscriptionId, equals('sub_abc'));
      });
    });

    group('serialize', () {
      test('produces correct array format without subscriptionId', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          testKind,
          testTags,
          testContent,
          testSig,
          verify: false,
        );

        final serialized = event.serialize();
        final decoded = jsonDecode(serialized) as List<dynamic>;

        expect(decoded.length, equals(2));
        expect(decoded[0], equals('EVENT'));
        expect((decoded[1] as Map<String, dynamic>)['id'], equals(testId));
      });

      test('includes subscriptionId when present', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          testKind,
          testTags,
          testContent,
          testSig,
          subscriptionId: 'sub_xyz',
          verify: false,
        );

        final serialized = event.serialize();
        final decoded = jsonDecode(serialized) as List<dynamic>;

        expect(decoded.length, equals(3));
        expect(decoded[0], equals('EVENT'));
        expect(decoded[1], equals('sub_xyz'));
        expect((decoded[2] as Map<String, dynamic>)['id'], equals(testId));
      });
    });

    group('isSignal', () {
      test('true for kind=4 content without ?iv=', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          EventKinds.nip04,
          testTags,
          'encrypted_signal_content',
          testSig,
          verify: false,
        );

        expect(event.isSignal, isTrue);
      });

      test('false for kind=4 content with ?iv=', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          EventKinds.nip04,
          testTags,
          'ciphertext?iv=base64iv',
          testSig,
          verify: false,
        );

        expect(event.isSignal, isFalse);
      });
    });

    group('isNip4', () {
      test('true for kind=4 content with ?iv=', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          EventKinds.nip04,
          testTags,
          'ciphertext?iv=base64iv',
          testSig,
          verify: false,
        );

        expect(event.isNip4, isTrue);
      });

      test('false for kind=4 content without ?iv=', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          EventKinds.nip04,
          testTags,
          'signal_content',
          testSig,
          verify: false,
        );

        expect(event.isNip4, isFalse);
      });
    });

    group('encryptType', () {
      test('nip17 for kind=1059', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          EventKinds.nip17,
          testTags,
          testContent,
          testSig,
          verify: false,
        );

        expect(event.encryptType, equals(MessageEncryptType.nip17));
      });

      test('signal for kind=4 without ?iv=', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          EventKinds.nip04,
          testTags,
          'signal_content',
          testSig,
          verify: false,
        );

        expect(event.encryptType, equals(MessageEncryptType.signal));
      });

      test('nip04 for kind=4 with ?iv=', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          EventKinds.nip04,
          testTags,
          'ciphertext?iv=base64iv',
          testSig,
          verify: false,
        );

        expect(event.encryptType, equals(MessageEncryptType.nip04));
      });
    });

    group('getTagsByKey', () {
      test('returns values for matching tag', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          testKind,
          testTags,
          testContent,
          testSig,
          verify: false,
        );

        final result = event.getTagsByKey('p');
        expect(result, equals(['abc123', 'wss://relay.example.com']));
      });

      test('returns null for missing tag', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          testKind,
          testTags,
          testContent,
          testSig,
          verify: false,
        );

        expect(event.getTagsByKey('z'), isNull);
      });
    });

    group('getTagByKey', () {
      test('returns first value of matching tag', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          testKind,
          testTags,
          testContent,
          testSig,
          verify: false,
        );

        expect(event.getTagByKey('e'), equals('def456'));
      });

      test('returns null for missing tag', () {
        final event = NostrEventModel(
          testId,
          testPubkeyLower,
          testCreatedAt,
          testKind,
          testTags,
          testContent,
          testSig,
          verify: false,
        );

        expect(event.getTagByKey('x'), isNull);
      });
    });
  });
}
