import 'package:app/models/identity.dart';
import 'package:app/models/keychat/prekey_message_model.dart';
import 'package:app/models/room.dart';
import 'package:app/service/SignerService.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class SignalChatUtil {
  static String getToSignMessage({
    required String nostrId,
    required String signalId,
    required int time,
  }) {
    return 'Keychat-$nostrId-$signalId-$time';
  }

  static Future<String?> signByIdentity(
      {required Identity identity, required String content, String? id}) async {
    if (identity.isFromSigner == false) {
      return rust_nostr.signSchnorr(
          privateKey: await identity.getSecp256k1SKHex(), content: content);
    }

    return SignerService.instance
        .signMessage(content: content, pubkey: identity.secp256k1PKHex, id: id);
  }

  static Future verifySignedMessage(
      {required PrekeyMessageModel pmm, required String signalIdPubkey}) async {
    final source = SignalChatUtil.getToSignMessage(
        nostrId: pmm.nostrId, signalId: signalIdPubkey, time: pmm.time);
    final verify = await rust_nostr.verifySchnorr(
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
    final time = DateTime.now().millisecondsSinceEpoch;
    final identity = room.getIdentity();

    final content = SignalChatUtil.getToSignMessage(
        nostrId: identity.secp256k1PKHex, signalId: signalPubkey, time: time);
    final sig = await SignalChatUtil.signByIdentity(
        identity: identity, content: content);
    final avatarRemoteUrl = await identity.getRemoteAvatarUrl();

    if (sig == null) throw Exception('Sign failed or User denied');
    return PrekeyMessageModel(
        signalId: signalPubkey,
        nostrId: identity.secp256k1PKHex,
        time: time,
        name: identity.displayName,
        lightning: identity.lightning,
        sig: sig,
        message: message,
        avatar: avatarRemoteUrl);
  }

  static String getPrekeySigContent(List<String> ids) {
    ids.sort((a, b) => a.compareTo(b));
    final sourceContent = ids.join(',');
    return sourceContent;
  }
}
