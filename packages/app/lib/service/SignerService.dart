import 'dart:convert';
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

  Future getNip17Event(
      {required String content,
      required String from,
      required String to}) async {
    String id1 = generate64RandomHexChars();
    var subEvent = {
      "id": id1,
      "pubkey": from,
      "created_at": DateTime.now().millisecondsSinceEpoch ~/ 1000,
      "kind": 14,
      "tags": [
        ["p", to],
      ],
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
    logger.d("res $res");

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
}
