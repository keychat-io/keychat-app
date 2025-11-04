import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/models/models.dart';

abstract class BaseChatService {
  Future<void> proccessMessage({
    required Room room,
    required NostrEventModel event,
    required KeychatMessage km,
    NostrEventModel? sourceEvent,
    String? msgKeyHash,
    String? fromIdPubkey,
    Function(String error)? failedCallback,
  });

  Future<SendMessageResponse> sendMessage(
    Room room,
    String message, {
    MessageMediaType? mediaType,
    bool save = true,
    MsgReply? reply,
    String? realMessage,
  });
}
