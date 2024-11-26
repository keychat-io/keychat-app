import 'package:app/models/identity.dart';
import 'package:app/models/keychat/prekey_message_model.dart';
import 'package:app/models/room.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class SignalChatUtil {
  static Future<String> getToSignMessage(
      {required String nostrPrikey,
      required String nostrId,
      required String signalId,
      required int time}) async {
    String source = "Keychat-$nostrId-$signalId-$time";
    return await rust_nostr.signSchnorr(
        senderKeys: nostrPrikey, content: source);
  }

  static Future verifySignedMessage(
      {required PrekeyMessageModel pmm, required String signalIdPubkey}) async {
    String source = "Keychat-${pmm.nostrId}-$signalIdPubkey-${pmm.time}";
    bool verify = await rust_nostr.verifySchnorr(
      pubkey: pmm.nostrId,
      content: source,
      sig: pmm.sig,
      hash: true,
    );
    if (!verify) throw Exception('Signature verification failed');
  }

  static Future<PrekeyMessageModel> getSignalPrekeyMessage(
      {required Room room,
      required String message,
      required String signalPubkey}) async {
    int time = DateTime.now().millisecondsSinceEpoch;
    Identity identity = room.getIdentity();
    String sig = await SignalChatUtil.getToSignMessage(
        nostrPrikey: await identity.getSecp256k1SKHex(),
        nostrId: identity.secp256k1PKHex,
        signalId: signalPubkey,
        time: time);

    return PrekeyMessageModel(
        signalId: signalPubkey,
        nostrId: identity.secp256k1PKHex,
        time: time,
        name: identity.displayName,
        sig: sig,
        message: message);
  }

  static String getPrekeySigContent(List ids) {
    ids.sort((a, b) => a.compareTo(b));
    String sourceContent = ids.join(',');
    return sourceContent;
  }
}
