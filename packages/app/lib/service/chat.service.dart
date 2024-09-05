import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/service/room.service.dart';
import 'package:app/models/models.dart';

abstract class BaseChatService {
  Future processMessage(
      {required Room room,
      required NostrEventModel event,
      NostrEventModel? sourceEvent,
      String? msgKeyHash,
      Function(String error)? failedCallback,
      required KeychatMessage km,
      required Relay relay});

  Future<SendMessageResponse> sendMessage(Room room, String message,
      {MessageMediaType? mediaType,
      bool save = true,
      MsgReply? reply,
      String? realMessage});
}
