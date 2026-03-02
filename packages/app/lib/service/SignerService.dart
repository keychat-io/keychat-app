import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:amberflutter/amberflutter.dart';

import 'package:keychat/constants.dart';
import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class SignerService {
  // Avoid self instance
  SignerService._();
  static SignerService? _instance;
  final amber = Amberflutter();
  static SignerService get instance => _instance ??= SignerService._();

  /// Generate a random timestamp up to 2 days in the past (NIP-59 spec)
  int _randomizedTimestamp() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const twoDaysInSeconds = 2 * 24 * 60 * 60;
    final randomOffset = Random.secure().nextInt(twoDaysInSeconds);
    return now - randomOffset;
  }

  Future<bool> checkAvailable() async {
    try {
      return await amber.isAppInstalled();
    } catch (e, s) {
      logger.e('checkAvailable error', error: e, stackTrace: s);
      return false;
    }
  }

  Future<String?> getPublicKey() async {
    try {
      final available = await checkAvailable();
      if (!available) {
        logger.e('Amber app not installed');
        return null;
      }
      final res = await amber.getPublicKey(
        permissions: [
          const Permission(
            type: 'sign_message',
          ),
        ],
      );
      logger.i(res);
      return res['signature'] as String?;
    } catch (e, s) {
      logger.e('getPublicKey error', error: e, stackTrace: s);
      return null;
    }
  }

  Future<String?> signMessage({
    required String content,
    required String pubkey,
    String? id,
  }) async {
    try {
      final available = await checkAvailable();
      if (!available) {
        logger.e('Amber app not installed');
        return null;
      }
      final res = await amber.signMessage(
        currentUser: pubkey,
        content: content,
        id: id,
      );
      logger.i(res);
      return res['signature'] as String?;
    } catch (e, s) {
      logger.e('signMessage error', error: e, stackTrace: s);
      return null;
    }
  }

  Future<String?> signEvent({
    required String eventJson,
    required String pubkey,
    String? id,
  }) async {
    try {
      final available = await checkAvailable();
      if (!available) {
        logger.e('Amber app not installed');
        return null;
      }
      final res = await amber.signEvent(
        currentUser: pubkey,
        eventJson: eventJson,
        id: id,
      );
      logger.i('signed: $res');
      return res['event'] as String?;
    } catch (e, s) {
      logger.e('signEvent error', error: e, stackTrace: s);
      return null;
    }
  }

  /// Creates two gift wrap events (one for recipient, one for sender for multi-device sync)
  Future<Map<String, String>> getNip59EventStringsWithSenderCopy({
    required String content,
    required String from,
    required String to,
    int nip17Kind = EventKinds.chatRumor,
    List<List<String>>? additionalTags,
  }) async {
    try {
      // Create event for recipient
      final toReceiverEvent = await _createNip59Event(
        content: content,
        from: from,
        to: to,
        nip17Kind: nip17Kind,
        additionalTags: additionalTags,
      );

      // Create event for sender (self)
      final toSenderEvent = await _createNip59Event(
        content: content,
        from: from,
        to: from, // Send to self
        nip17Kind: nip17Kind,
        additionalTags: additionalTags,
      );

      return {
        'to_receiver': toReceiverEvent,
        'to_sender': toSenderEvent,
      };
    } catch (e, s) {
      logger.e(
        'getNip59EventStringsWithSenderCopy error',
        error: e,
        stackTrace: s,
      );
      rethrow;
    }
  }

  /// Creates a single NIP-59 gift wrap event (internal helper method)
  Future<String> _createNip59Event({
    required String content,
    required String from,
    required String to,
    required int nip17Kind,
    List<List<String>>? additionalTags,
  }) async {
    final id1 = generate64RandomHexChars();
    var tags = [
      ['p', to],
    ];
    if (additionalTags != null) {
      tags = additionalTags;
    }

    // Create Rumor (kind 14)
    final subEvent = {
      'id': id1,
      'pubkey': from,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'kind': nip17Kind, // Should be 14
      'tags': tags,
      'content': content,
    };

    // Encrypt Rumor with NIP-44
    final encryptedSubEvent = await amber.nip44Encrypt(
      plaintext: jsonEncode(subEvent),
      currentUser: from,
      pubKey: to,
      id: id1,
    );

    // Create Seal (kind 13) with randomized timestamp
    final sealTime = _randomizedTimestamp();
    final id2 = generate64RandomHexChars();
    final secondEvent = {
      'id': '',
      'pubkey': from,
      'created_at': sealTime,
      'kind': 13,
      'tags': <List<String>>[],
      'content': encryptedSubEvent['signature'],
      'sig': '',
    };

    final res = await amber.signEvent(
      currentUser: from,
      eventJson: jsonEncode(secondEvent),
      id: id2,
    );

    // Encrypt Seal with NIP-44
    final randomSecp256k1 = await rust_nostr.generateSecp256K1();
    final encrypteSecondRes = await rust_nostr.encryptNip44(
      content: res['event'] as String,
      senderKeys: randomSecp256k1.prikey,
      receiverPubkey: to,
    );

    // Create Gift Wrap (kind 1059) with independent randomized timestamp
    return rust_nostr.signEvent(
      senderKeys: randomSecp256k1.prikey,
      tags: [
        ['p', to],
      ],
      createdAt: BigInt.from(_randomizedTimestamp()),
      content: encrypteSecondRes,
      kind: 1059, // Outer layer remains 1059
    );
  }

  /// Builds a rumor event map for tests without invoking Amber SDK.
  @visibleForTesting
  Map<String, dynamic> buildRumorEventForTesting({
    required String content,
    required String from,
    required String to,
    int nip17Kind = EventKinds.chatRumor,
    List<List<String>>? additionalTags,
    int? createdAt,
    String? id,
  }) {
    var tags = <List<String>>[
      ['p', to],
    ];
    if (additionalTags != null) {
      tags = additionalTags;
    }
    return {
      'id': id ?? generate64RandomHexChars(),
      'pubkey': from,
      'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'kind': nip17Kind,
      'tags': tags,
      'content': content,
    };
  }

  Future<String> getNip59EventString({
    required String content,
    required String from,
    required String to,
    int nip17Kind = EventKinds.chatRumor,
    List<List<String>>? additionalTags,
  }) async {
    try {
      final id1 = generate64RandomHexChars();
      var tags = [
        ['p', to],
      ];
      if (additionalTags != null) {
        tags = additionalTags;
      }
      final subEvent = {
        'id': id1,
        'pubkey': from,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': nip17Kind,
        'tags': tags,
        'content': content,
      };
      final encryptedSubEvent = await amber.nip44Encrypt(
        plaintext: jsonEncode(subEvent),
        currentUser: from,
        pubKey: to,
        id: id1,
      );
      // Create Seal (kind 13) with randomized timestamp
      final sealTime = _randomizedTimestamp();
      final id2 = generate64RandomHexChars();
      final secondEvent = {
        'id': '',
        'pubkey': from,
        'created_at': sealTime,
        'kind': 13,
        'tags': <List<String>>[],
        'content': encryptedSubEvent['signature'],
        'sig': '',
      };

      final res = await amber.signEvent(
        currentUser: from,
        eventJson: jsonEncode(secondEvent),
        id: id2,
      );
      final randomSecp256k1 = await rust_nostr.generateSecp256K1();
      final encrypteSecondRes = await rust_nostr.encryptNip44(
        content: res['event'] as String,
        senderKeys: randomSecp256k1.prikey,
        receiverPubkey: to,
      );
      // Gift Wrap (kind 1059) with independent randomized timestamp
      return await rust_nostr.signEvent(
        senderKeys: randomSecp256k1.prikey,
        tags: [
          ['p', to],
        ],
        createdAt: BigInt.from(_randomizedTimestamp()),
        content: encrypteSecondRes,
        kind: 1059,
      );
    } catch (e, s) {
      logger.e('getNip59EventString error', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<String> nip44Decrypt(
    String ciphertext,
    String pubkey,
    String currentUser,
  ) async {
    try {
      final res = await SignerService.instance.amber.nip44Decrypt(
        ciphertext: ciphertext,
        currentUser: currentUser,
        pubKey: pubkey,
      );
      return res['event'] as String;
    } catch (e, s) {
      logger.e('nip44Decrypt error', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<String> nip44Encrypt(
    String plaintext,
    String pubkey,
    String currentUser,
  ) async {
    try {
      final res = await SignerService.instance.amber.nip44Encrypt(
        plaintext: plaintext,
        currentUser: currentUser,
        pubKey: pubkey,
      );
      return res['event'] as String;
    } catch (e, s) {
      logger.e('nip44Encrypt error', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<NostrEventModel> nip44DecryptEvent(NostrEventModel event) async {
    try {
      final to = event.tags[0][1];
      final res = await SignerService.instance.amber.nip44Decrypt(
        ciphertext: event.content,
        currentUser: to,
        pubKey: event.pubkey,
        id: event.id,
      );
      final subEvent = jsonDecode(res['signature'] as String);
      final res2 = await SignerService.instance.amber.nip44Decrypt(
        ciphertext: subEvent['content'] as String,
        currentUser: to,
        pubKey: subEvent['pubkey'] as String,
        id: subEvent['id'] as String,
      );
      final plainEvent = jsonDecode(res2['signature'] as String);

      // NIP-59: verify seal pubkey matches rumor pubkey
      final sealPubkey = subEvent['pubkey'] as String;
      final rumorPubkey = plainEvent['pubkey'] as String;
      if (sealPubkey != rumorPubkey) {
        throw Exception(
          'NIP-59 verification failed: seal pubkey does not match rumor pubkey',
        );
      }

      final tags = (plainEvent['tags'] as List)
          .map((e) => (e as List).map((e2) => e2.toString()).toList())
          .toList();
      final resEvent = NostrEventModel(
        plainEvent['id'] as String,
        plainEvent['pubkey'] as String,
        plainEvent['created_at'] as int,
        plainEvent['kind'] as int,
        tags,
        plainEvent['content'] as String,
        '',
        verify: false,
      );
      return resEvent;
    } catch (e, s) {
      logger.e('nip44DecryptEvent error', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<String> nip04Encrypt({
    required String plaintext,
    required String currentUser,
    required String to,
  }) async {
    try {
      final res = await amber.nip04Encrypt(
        plaintext: plaintext,
        currentUser: currentUser,
        pubKey: to,
      );
      return res['event'] as String;
    } catch (e, s) {
      logger.e('nip04Encrypt error', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<String> nip04Decrypt({
    required String ciphertext,
    required String from,
    required String currentUser,
  }) async {
    try {
      final res = await amber.nip04Decrypt(
        ciphertext: ciphertext,
        currentUser: currentUser,
        pubKey: from,
      );
      return res['event'] as String;
    } catch (e, s) {
      logger.e('nip04Decrypt error', error: e, stackTrace: s);
      rethrow;
    }
  }
}
