import 'package:app/models/identity.dart';
import 'package:app/models/keychat/prekey_message_model.dart';
import 'package:app/models/room.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;

class SignalChatUtil {
  static Future<PrekeyMessageModel> getSignalPrekeyMessageContent(
      Room room, Identity identity, String message) async {
    String sourceContent =
        getPrekeySigContent([room.myIdPubkey, room.toMainPubkey, message]);
    String sig = await rustNostr.signSchnorr(
        senderKeys: identity.secp256k1SKHex, content: sourceContent);
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
}
