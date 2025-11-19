import 'package:keychat/constants.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/nostr-core/nostr.dart';
import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat/service/chat.service.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/utils.dart';

class Nip4ChatService extends BaseChatService {
  // Avoid self instance
  Nip4ChatService._();
  static Nip4ChatService? _instance;
  static Nip4ChatService get instance => _instance ??= Nip4ChatService._();

  @override
  Future<void> proccessMessage({
    required Room room,
    required NostrEventModel event,
    required KeychatMessage km,
    NostrEventModel? sourceEvent,
    Function(String error)? failedCallback,
    String? msgKeyHash,
    String? fromIdPubkey,
  }) async {
    switch (km.type) {
      case KeyChatEventKinds.dm:
        await RoomService.instance.receiveDM(
          room,
          event,
          sourceEvent: sourceEvent,
          km: km,
        );
      default:
    }
  }

  Future<Message> receiveNip4Message(
    NostrEventModel event,
    String content, {
    required int createdAt,
    required EncryptMode encryptMode,
    NostrEventModel? sourceEvent,
    Room? room,
  }) async {
    final to = (sourceEvent ?? event).tags[0][1];
    room ??= await RoomService.instance.getOrCreateRoom(
      event.pubkey,
      to,
      RoomStatus.init,
      encryptMode: encryptMode,
    );

    return MessageService.instance.saveMessageToDB(
      room: room,
      events: [sourceEvent ?? event],
      senderPubkey: room.toMainPubkey,
      from: event.pubkey,
      encryptType: (sourceEvent ?? event).encryptType,
      to: to,
      content: content,
      isMeSend: false,
      sent: SendStatusType.success,
      createdAt: createdAt,
    );
  }

  Future<void> saveSystemMessage({
    required Room room,
    required NostrEventModel event,
    required String message,
    required bool isMeSend,
    required SendStatusType sent,
    required String idPubkey,
    bool isSystem = true,
    String? from,
    String? to,
  }) async {
    final toSaveMsg = Message(
      identityId: room.identityId,
      msgid: event.id,
      eventIds: [event.id],
      roomId: room.id,
      from: from ?? event.pubkey,
      idPubkey: idPubkey,
      to: to ?? event.tags[0][1],
      encryptType: event.isSignal
          ? MessageEncryptType.signal
          : MessageEncryptType.nip17,
      isMeSend: isMeSend,
      sent: sent,
      isSystem: isSystem,
      content: message,
      createdAt: timestampToDateTime(event.createdAt),
      rawEvents: [event.toString()],
    );
    await MessageService.instance.saveMessageModel(toSaveMsg, room: room);
  }

  @override
  Future<SendMessageResponse> sendMessage(
    Room room,
    String message, {
    bool save = true,
    MsgReply? reply,
    String? realMessage,
    MessageMediaType? mediaType,
  }) async {
    final identity = room.getIdentity();
    return NostrAPI.instance.sendEventMessage(
      room.toMainPubkey,
      message,
      room: room,
      save: save,
      encryptType: MessageEncryptType.nip04,
      prikey: await identity.getSecp256k1SKHex(),
      from: identity.secp256k1PKHex,
      realMessage: realMessage,
    );
  }
}
