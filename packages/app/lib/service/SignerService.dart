import 'dart:convert' show jsonEncode, jsonDecode;
import 'package:app/constants.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:amberflutter/amberflutter.dart';
import 'package:app/utils.dart';

class SignerService {
  static SignerService? _instance;
  final amber = Amberflutter();
  // Avoid self instance
  SignerService._();
  static SignerService get instance => _instance ??= SignerService._();

  Future<bool> checkAvailable() async {
    return amber.isAppInstalled();
  }

  Future<String?> getPublicKey() async {
    var available = await checkAvailable();
    if (!available) {
      logger.e("Amber app not installed");
      return null;
    }
    var res = await amber.getPublicKey(
      permissions: [
        const Permission(
          type: "sign_message",
        ),
      ],
    );
    logger.d(res);
    return res['signature'];
  }

  Future<String?> signMessage(
      {required String content, required String pubkey, String? id}) async {
    var available = await checkAvailable();
    if (!available) {
      logger.e("Amber app not installed");
      return null;
    }
    var res =
        await amber.signMessage(currentUser: pubkey, content: content, id: id);
    logger.d(res);
    return res['signature'];
  }

  Future<String?> signEvent(
      {required String eventJson, required String pubkey, String? id}) async {
    var available = await checkAvailable();
    if (!available) {
      logger.e("Amber app not installed");
      return null;
    }
    var res = await amber.signEvent(
        currentUser: pubkey, eventJson: eventJson, id: id);
    logger.d(res);
    return res['event'];
  }

  Future<String> getNip59EventString(
      {required String content,
      required String from,
      required String to,
      int nip17Kind = EventKinds.nip17,
      List<List<String>>? additionalTags}) async {
    String id1 = generate64RandomHexChars();
    List tags = [
      ["p", to]
    ];
    if (additionalTags != null) {
      tags = additionalTags;
    }
    var subEvent = {
      "id": id1,
      "pubkey": from,
      "created_at": DateTime.now().millisecondsSinceEpoch ~/ 1000,
      "kind": nip17Kind,
      "tags": tags,
      "content": content,
    };
    Map encryptedSubEvent = await amber.nip44Encrypt(
        plaintext: jsonEncode(subEvent),
        currentUser: from,
        pubKey: to,
        id: id1);
    int randomTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String id2 = generate64RandomHexChars();
    var secondEvent = {
      "id": '',
      "pubkey": from,
      "created_at": randomTime,
      "kind": 13,
      "tags": [],
      "content": encryptedSubEvent['signature'],
      "sig": ""
    };

    var res = await amber.signEvent(
        currentUser: from, eventJson: jsonEncode(secondEvent), id: id2);
    var randomSecp256k1 = await rust_nostr.generateSecp256K1();
    String encrypteSecondRes = await rust_nostr.encryptNip44(
        content: res['event'],
        senderKeys: randomSecp256k1.prikey,
        receiverPubkey: to);
    return await rust_nostr.signEvent(
        senderKeys: randomSecp256k1.prikey,
        tags: [
          ["p", to]
        ],
        createdAt: BigInt.from(randomTime),
        content: encrypteSecondRes,
        kind: 1059);
  }

  Future<NostrEventModel> nip44Decrypt(NostrEventModel event) async {
    String to = event.tags[0][1];
    var res = await SignerService.instance.amber.nip44Decrypt(
        ciphertext: event.content,
        currentUser: to,
        pubKey: event.pubkey,
        id: event.id);
    var subEvent = jsonDecode(res["signature"]);
    var res2 = await SignerService.instance.amber.nip44Decrypt(
        ciphertext: subEvent['content'],
        currentUser: to,
        pubKey: subEvent['pubkey'],
        id: subEvent['id']);
    var plainEvent = jsonDecode(res2["signature"]);
    List<List<String>> tags = (plainEvent['tags'] as List)
        .map((e) => (e as List).map((e2) => e2.toString()).toList())
        .toList();
    var resEvent = NostrEventModel(
        plainEvent['id'],
        plainEvent['pubkey'],
        plainEvent['created_at'].toInt(),
        plainEvent['kind'].toInt(),
        tags,
        plainEvent['content'],
        '',
        verify: false);
    return resEvent;
  }

  Future<String> nip04Encrypt(
      {required String plaintext,
      required String currentUser,
      required String to}) async {
    var res = await amber.nip04Encrypt(
        plaintext: plaintext, currentUser: currentUser, pubKey: to);
    return res['event'];
  }

  Future<String> nip04Decrypt(
      {required String ciphertext,
      required String from,
      required String currentUser}) async {
    var res = await amber.nip04Decrypt(
        ciphertext: ciphertext, currentUser: currentUser, pubKey: from);
    return res['event'];
  }
}
