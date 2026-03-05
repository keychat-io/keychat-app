import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/models/models.dart';

/// Base class for all chat protocol services (Signal, MLS, NIP-04, NIP-17).
///
/// Implementors handle encryption, decryption, and transport for a specific protocol.
abstract class BaseChatService {
  /// Processes an incoming decrypted message and persists it to the database.
  ///
  /// [room] is the conversation context.
  /// [event] is the inner (decrypted) Nostr event.
  /// [km] is the parsed keychat message payload.
  /// [sourceEvent] is the outer wrapper event (e.g. a NIP-59 gift-wrap), if any.
  /// [msgKeyHash] is the Signal ratchet key hash, used for decrypt-failure recovery.
  /// [failedCallback] is called with an error string if processing fails non-fatally.
  Future<void> proccessMessage({
    required Room room,
    required NostrEventModel event,
    required KeychatMessage km,
    NostrEventModel? sourceEvent,
    String? msgKeyHash,
    String? fromIdPubkey,
    Function(String error)? failedCallback,
  });

  /// Encrypts and sends a message to [room].
  ///
  /// Returns a [SendMessageResponse] containing the published Nostr events and
  /// the saved [Message] model.
  /// [save] controls whether the outgoing message is persisted locally.
  Future<SendMessageResponse> sendMessage(
    Room room,
    String message, {
    MessageMediaType? mediaType,
    bool save = true,
    MsgReply? reply,
    String? realMessage,
  });
}
