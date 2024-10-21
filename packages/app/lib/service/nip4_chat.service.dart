import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr_event.dart';

import 'package:app/service/chat.service.dart';

import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import '../constants.dart';
import '../models/db_provider.dart';
import '../nostr-core/nostr.dart';

import '../utils.dart';
import 'contact.service.dart';
import 'identity.service.dart';
import 'message.service.dart';
import 'room.service.dart';

class Nip4ChatService extends BaseChatService {
  static final Nip4ChatService _singleton = Nip4ChatService._internal();
  static final DBProvider dbProvider = DBProvider();
  static final NostrAPI nostrAPI = NostrAPI();
  RoomService roomService = RoomService();
  ContactService contactService = ContactService();
  IdentityService identityService = IdentityService();

  factory Nip4ChatService() {
    return _singleton;
  }

  Nip4ChatService._internal();

  @override
  proccessMessage(
      {required Room room,
      required NostrEventModel event,
      required KeychatMessage km,
      NostrEventModel? sourceEvent,
      Function(String error)? failedCallback,
      String? msgKeyHash,
      String? fromIdPubkey}) async {
    switch (km.type) {
      case KeyChatEventKinds.dm:
        await RoomService().receiveDM(
          room,
          event,
          sourceEvent: sourceEvent,
          km: km,
        );
        break;
      default:
    }
  }

  Future<Message> receiveNip4Message(NostrEventModel event, String content,
      [NostrEventModel? sourceEvent]) async {
    Room room = await roomService.getOrCreateRoom(
        event.pubkey, event.tags[0][1], RoomStatus.init);

    return await MessageService().saveMessageToDB(
        room: room,
        events: [sourceEvent ?? event],
        idPubkey: room.toMainPubkey,
        from: event.pubkey,
        encryptType: (sourceEvent ?? event).encryptType,
        to: event.tags[0][1],
        content: content,
        isMeSend: false,
        sent: SendStatusType.success);
  }

  Future saveSystemMessage(
      {required Room room,
      required NostrEventModel event,
      required String message,
      required bool isMeSend,
      required SendStatusType sent,
      required String idPubkey,
      bool isSystem = true,
      String? from,
      String? to}) async {
    Message toSaveMsg = Message(
        identityId: room.identityId,
        msgid: event.id,
        eventIds: [event.id],
        roomId: room.id,
        from: from ?? event.pubkey,
        idPubkey: idPubkey,
        to: to ?? event.tags[0][1],
        encryptType: event.isSignal
            ? MessageEncryptType.signal
            : MessageEncryptType.nip4,
        isMeSend: isMeSend,
        sent: sent,
        isSystem: isSystem,
        content: message,
        createdAt: timestampToDateTime(event.createdAt),
        rawEvents: [event.toJsonString()]);
    await MessageService().saveMessageModel(toSaveMsg, room: room);
  }

  // Send pseudonymous messages. The messages are nested in two layers, the first layer is pseudonymous messages, and the second layer is real messages.
  Future<SendMessageResponse> sendIncognitoNip4Message(
      Room room, String message,
      {bool isSystem = false,
      bool save = true,
      String? realMessage,
      String? toAddress}) async {
    Identity identity = room.getIdentity();

    String mainSign = await rust_nostr.getEncryptEvent(
        senderKeys: await identity.getSecp256k1SKHex(),
        receiverPubkey: room.toMainPubkey,
        content: message);

    mainSign = "[\"EVENT\",$mainSign]";

    var secp256K1Account = await rust_nostr.generateSimple();
    return await nostrAPI.sendNip4Message(
        toAddress ?? room.toMainPubkey, mainSign,
        prikey: secp256K1Account.prikey,
        from: secp256K1Account.pubkey,
        room: room,
        isSystem: isSystem,
        encryptType: MessageEncryptType.nip4WrapNip4,
        save: save,
        realMessage: realMessage);
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
    Identity identity = room.getIdentity();
    return await nostrAPI.sendNip4Message(
      room.toMainPubkey,
      message,
      room: room,
      save: save,
      encryptType: MessageEncryptType.nip4,
      prikey: await identity.getSecp256k1SKHex(),
      from: identity.secp256k1PKHex,
      realMessage: realMessage,
    );
  }
}
