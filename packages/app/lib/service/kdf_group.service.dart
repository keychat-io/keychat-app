// KDF group is a shared key group
// Use signal protocol to encrypt message
// Every Member in the group has the same signal id key pair, it's a virtual Member in group
// Every member send message to virtual member

import 'dart:convert' show jsonDecode;

import 'package:app/constants.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/embedded/msg_reply.dart';
import 'package:app/models/event_log.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/keychat/group_message.dart';
import 'package:app/models/keychat/keychat_message.dart';
import 'package:app/models/message.dart';
import 'package:app/models/mykey.dart';
import 'package:app/models/relay.dart';
import 'package:app/models/room.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/service/chat.service.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;

class KdfGroupService extends BaseChatService {
  static KdfGroupService? _instance;
  // Avoid self instance
  KdfGroupService._();
  static KdfGroupService get instance => _instance ??= KdfGroupService._();

  Future joinGroup() async {}

  Future leaveGroup() async {}

  @override
  Future<SendMessageResponse> sendMessage(Room room, String message,
      {MessageMediaType? mediaType,
      bool save = true,
      MsgReply? reply,
      String? realMessage,
      Function(bool)? sentCallback}) async {
    Mykey roomKey = room.mykey.value!;
    String toEncryptedMessage = message;
    if (reply != null) {
      GroupMessage gm =
          RoomUtil.getGroupMessage(room, message, pubkey: '', reply: reply);
      toEncryptedMessage = gm.toString();
      realMessage ??= message;
    }
    Identity identity = room.getIdentity();

    String encryptedEvent = await rustNostr.getEncryptEvent(
        senderKeys: identity.secp256k1SKHex,
        receiverPubkey: roomKey.pubkey,
        content: toEncryptedMessage);

    NostrEventModel event =
        NostrEventModel.fromJson(jsonDecode(encryptedEvent), verify: false);

    List<String> relays = await Get.find<WebsocketService>().writeNostrEvent(
        event: event,
        encryptedEvent: encryptedEvent,
        roomId: room.id,
        sentCallback: sentCallback);

    await DBProvider().saveMyEventLog(event: event, relays: relays);

    Message? model = await MessageService().saveMessageToDB(
        events: [event],
        room: room,
        reply: reply,
        content: message,
        from: identity.secp256k1PKHex,
        idPubkey: identity.secp256k1PKHex,
        to: room.toMainPubkey,
        realMessage: realMessage,
        isMeSend: true,
        encryptType: MessageEncryptType.nip4,
        mediaType: mediaType,
        isRead: true);

    return SendMessageResponse(relays: relays, events: [event], message: model);
  }

  Future<SendMessageResponse> sendFeatureMessage(Room room, String message,
      {MessageMediaType? mediaType,
      bool save = true,
      MsgReply? reply,
      String? realMessage,
      int? subtype,
      String? ext,
      Function(bool)? sentCallback}) async {
    Mykey roomKey = room.mykey.value!;

    GroupMessage gm = RoomUtil.getGroupMessage(room, message,
        pubkey: '', reply: reply, subtype: subtype, ext: ext);
    String subEncryptedEvent = await rustNostr.getEncryptEvent(
        senderKeys: room.getIdentity().secp256k1SKHex,
        receiverPubkey: roomKey.pubkey,
        content: gm.toString());

    KeychatMessage km = KeychatMessage(
        c: MessageType.group,
        type: KeyChatEventKinds.groupSharedKeyMessage,
        msg: subEncryptedEvent);

    String encryptedEvent = await rustNostr.getEncryptEvent(
        senderKeys: roomKey.prikey,
        receiverPubkey: roomKey.pubkey,
        content: km.toString());

    NostrEventModel event =
        NostrEventModel.fromJson(jsonDecode(encryptedEvent), verify: false);

    List<String> relays = await Get.find<WebsocketService>().writeNostrEvent(
        event: event,
        encryptedEvent: encryptedEvent,
        roomId: room.id,
        sentCallback: sentCallback);

    Message? model;
    if (subtype == null && ext == null) {
      await DBProvider().saveMyEventLog(event: event, relays: relays);
      Identity identity = room.getIdentity();

      model = await MessageService().saveMessageToDB(
          events: [event],
          room: room,
          reply: reply,
          content: message,
          from: identity.secp256k1PKHex,
          idPubkey: identity.secp256k1PKHex,
          to: room.toMainPubkey,
          realMessage: realMessage,
          isMeSend: true,
          encryptType: MessageEncryptType.nip4WrapNip4,
          mediaType: mediaType,
          isRead: true);
    }
    return SendMessageResponse(relays: relays, events: [event], message: model);
  }

  Future receiveMessage() async {}

  Future getGroupMembers() async {}

  @override
  Future processMessage(
      {required Room room,
      required NostrEventModel event,
      NostrEventModel? sourceEvent,
      String? msgKeyHash,
      required KeychatMessage km,
      required Relay relay}) {
    // TODO: implement processMessage
    throw UnimplementedError();
  }

  Future decryptMessage(Room kdfRoom, NostrEventModel event, Relay relay,
      {EventLog? eventLog}) async {
    String prikey = kdfRoom.mykey.value!.prikey;

    String decodedContent = await rustNostr.decrypt(
        senderKeys: prikey,
        receiverPubkey: event.pubkey,
        content: event.content);
    logger.d('from ${event.pubkey}, decodedContent: $decodedContent');
    await RoomService().receiveDM(
      kdfRoom,
      event,
      null,
      decodedContent: decodedContent,
    );
  }

  // create a group
  // setup room's sharedSignalID
  // setup room's signal session
  // show shared signalID's QRCode
  // inti identity's signal session
  // send hello message to group shared key but not save
  // shared signal init signal session
  Future<Room> createGroup(String groupName, Identity identity) async {
    IdentityService identityService = IdentityService();
    Room room =
        await GroupService().createGroup(groupName, identity, GroupType.kdf);
    SignalId signalId = await identityService.createSignalId(identity.id,
        isGroupSharedKey: true);
    room.sharedSignalID = signalId.pubkey;
    await RoomService().updateRoom(room);
  }
}
