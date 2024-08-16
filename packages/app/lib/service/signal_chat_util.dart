import 'package:app/models/identity.dart';
import 'package:app/models/keychat/prekey_message_model.dart';
import 'package:app/models/room.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;

class SignalChatUtil {
  static Future<PrekeyMessageModel> getSignalPrekeyMessageContent(
      Room room, Identity identity, String message) async {
    String sourceContent = getPrekeySigContent(
        [identity.secp256k1PKHex, room.toMainPubkey, message]);

    String sig = await rustNostr.signSchnorr(
        senderKeys: await identity.getSecp256k1SKHex(), content: sourceContent);
    return PrekeyMessageModel(
        nostrId: identity.secp256k1PKHex,
        name: identity.displayName,
        sig: sig,
        message: message);
  }

  static String getPrekeySigContent(List ids) {
    ids.sort((a, b) => a.compareTo(b));
    String sourceContent = ids.join(',');
    return sourceContent;
  }

  static Future<void> verifyPrekeyMessage(
      PrekeyMessageModel prekeyMessageModel, String receivePubkey) async {
    String sourceContent = SignalChatUtil.getPrekeySigContent([
      prekeyMessageModel.nostrId,
      receivePubkey,
      prekeyMessageModel.message
    ]);
    bool verify = await rustNostr.verifySchnorr(
      pubkey: prekeyMessageModel.nostrId,
      content: sourceContent,
      sig: prekeyMessageModel.sig,
      hash: true,
    );
    if (!verify) throw Exception('Signature verification failed');
  }
}
