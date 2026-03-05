import 'package:keychat/models/identity.dart';
import 'package:keychat/models/keychat/prekey_message_model.dart';
import 'package:keychat/models/room.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/service/SignerService.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class SignalChatUtil {
  /// Constructs the canonical payload string used for Schnorr signing during
  /// the Signal prekey exchange.
  ///
  /// Format: `Keychat-<nostrId>-<signalId>-<time>`
  static String getToSignMessage({
    required String nostrId,
    required String signalId,
    required int time,
  }) {
    return 'Keychat-$nostrId-$signalId-$time';
  }

  /// Signs [content] with the identity's secp256k1 private key using Schnorr.
  ///
  /// When [identity.isFromSigner] is true, delegates to the external [SignerService]
  /// (e.g. an Amber / NIP-55 signer app) so the private key never leaves the signer.
  /// Otherwise signs directly with the stored hex private key via [rust_nostr.signSchnorr].
  ///
  /// [id] — optional Nostr event ID forwarded to the external signer for context.
  /// Returns the hex-encoded Schnorr signature, or `null` if the user denies signing.
  static Future<String?> signByIdentity({
    required Identity identity,
    required String content,
    String? id,
  }) async {
    if (!identity.isFromSigner) {
      return rust_nostr.signSchnorr(
        privateKey: await identity.getSecp256k1SKHex(),
        content: content,
      );
    }

    return SignerService.instance.signMessage(
      content: content,
      pubkey: identity.secp256k1PKHex,
      id: id,
    );
  }

  /// Verifies the Schnorr signature embedded in [pmm] against the sender's Nostr pubkey.
  ///
  /// Reconstructs the canonical sign string via [getToSignMessage] and verifies it
  /// against [pmm.sig] using [pmm.nostrId] as the public key.
  ///
  /// Throws an [Exception] if signature verification fails, preventing session setup
  /// with an unauthenticated sender.
  static Future<void> verifySignedMessage({
    required PrekeyMessageModel pmm,
    required String signalIdPubkey,
  }) async {
    final source = SignalChatUtil.getToSignMessage(
      nostrId: pmm.nostrId,
      signalId: signalIdPubkey,
      time: pmm.time,
    );
    final verify = await rust_nostr.verifySchnorr(
      pubkey: pmm.nostrId,
      content: source,
      sig: pmm.sig,
      hash: true,
    );
    if (!verify) throw Exception('Signature verification failed');
  }

  /// Builds a signed [PrekeyMessageModel] for the initial Signal handshake.
  ///
  /// Signs the canonical string `Keychat-<nostrId>-<signalPubkey>-<time>` with the
  /// identity's Schnorr key and bundles sender metadata (display name, avatar, lightning).
  /// The model is embedded in the first encrypted Signal message so the recipient can
  /// verify the sender's Nostr identity alongside the Signal prekey bundle.
  ///
  /// Throws if signing fails or the user denies the signing request.
  static Future<PrekeyMessageModel> getSignalPrekeyMessage({
    required Room room,
    required String message,
    required String signalPubkey,
  }) async {
    final time = RoomUtil.getValidateTime();
    final identity = room.getIdentity();

    final content = SignalChatUtil.getToSignMessage(
      nostrId: identity.secp256k1PKHex,
      signalId: signalPubkey,
      time: time,
    );
    final sig = await SignalChatUtil.signByIdentity(
      identity: identity,
      content: content,
    );
    final avatarRemoteUrl = await identity.getRemoteAvatarUrl();

    if (sig == null) throw Exception('Sign failed or User denied');
    return PrekeyMessageModel(
      signalId: signalPubkey,
      nostrId: identity.secp256k1PKHex,
      time: time,
      name: identity.displayName,
      sig: sig,
      message: message,
      lightning: identity.lightning ?? '',
      avatar: avatarRemoteUrl ?? '',
    );
  }

  // DEPRECATED: no callers found after prekey signature format change - candidate for removal
  static String getPrekeySigContent(List<String> ids) {
    ids.sort((a, b) => a.compareTo(b));
    final sourceContent = ids.join(',');
    return sourceContent;
  }
}
