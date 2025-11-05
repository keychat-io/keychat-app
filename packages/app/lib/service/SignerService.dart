import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:keychat/constants.dart';
import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:amberflutter/amberflutter.dart';
import 'package:keychat/utils.dart';

class SignerService {
  // Avoid self instance
  SignerService._();
  static SignerService? _instance;
  final amber = Amberflutter();
  static SignerService get instance => _instance ??= SignerService._();

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
      logger.i(res);
      return res['event'] as String?;
    } catch (e, s) {
      logger.e('signEvent error', error: e, stackTrace: s);
      return null;
    }
  }

  Future<String> getNip59EventString({
    required String content,
    required String from,
    required String to,
    int nip17Kind = EventKinds.nip17,
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
      final randomTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final id2 = generate64RandomHexChars();
      final secondEvent = {
        'id': '',
        'pubkey': from,
        'created_at': randomTime,
        'kind': 13,
        'tags': [],
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
        content: res['event'],
        senderKeys: randomSecp256k1.prikey,
        receiverPubkey: to,
      );
      return await rust_nostr.signEvent(
        senderKeys: randomSecp256k1.prikey,
        tags: [
          ['p', to],
        ],
        createdAt: BigInt.from(randomTime),
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
      final subEvent = jsonDecode(res['signature']);
      final res2 = await SignerService.instance.amber.nip44Decrypt(
        ciphertext: subEvent['content'],
        currentUser: to,
        pubKey: subEvent['pubkey'],
        id: subEvent['id'],
      );
      final plainEvent = jsonDecode(res2['signature']);
      final tags = (plainEvent['tags'] as List)
          .map((e) => (e as List).map((e2) => e2.toString()).toList())
          .toList();
      final resEvent = NostrEventModel(
        plainEvent['id'],
        plainEvent['pubkey'],
        plainEvent['created_at'].toInt(),
        plainEvent['kind'].toInt(),
        tags,
        plainEvent['content'],
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
