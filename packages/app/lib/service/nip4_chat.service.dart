import 'dart:convert';
import 'package:keychat/constants.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/nostr-core/nostr.dart';
import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat/service/SignerService.dart';
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
    if (identity.isFromSigner) {
      final to = room.toMainPubkey;
      final plaintext = message;
      final ciphertext = await SignerService.instance.nip04Encrypt(
        plaintext: plaintext,
        currentUser: identity.secp256k1PKHex,
        to: to,
      );

      final model = NostrEventModel.partial(
        id: generate64RandomHexChars(),
        pubkey: identity.secp256k1PKHex,
        kind: 4,
        content: ciphertext,
        tags: [
          ['p', to],
        ],
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final eventString = await SignerService.instance.signEvent(
        eventJson: jsonEncode(model.toJson()),
        pubkey: identity.secp256k1PKHex,
      );
      if (eventString == null) throw Exception('Sig is null');
      return NostrAPI.instance.sendAndSaveNostrEvent(
        to: room.toMainPubkey,
        plainContent: plaintext,
        from: identity.secp256k1PKHex,
        encryptedEvent: eventString,
        room: room,
        mediaType: mediaType,
        realMessage: realMessage,
      );
    }
    return NostrAPI.instance.sendEventMessage(
      room.toMainPubkey,
      message,
      room: room,
      save: save,
      encryptType: MessageEncryptType.nip04,
      prikey: await identity.getSecp256k1SKHex(),
      from: identity.secp256k1PKHex,
      realMessage: realMessage,
      mediaType: mediaType,
    );
  }
}
