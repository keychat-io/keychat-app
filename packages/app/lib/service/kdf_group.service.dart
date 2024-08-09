// KDF group is a shared key group
// Use signal protocol to encrypt message
// Every Member in the group has the same signal id key pair, it's a virtual Member in group
// Every member send message to virtual member

import 'dart:convert' show base64, base64Decode, jsonDecode, utf8;
import 'dart:typed_data' show Uint8List;
import 'package:app/models/keychat/prekey_message_model.dart';
import 'package:app/models/room_member.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/service/signal_chat_util.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rustSignal;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;
import 'package:app/constants.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/embedded/msg_reply.dart';
import 'package:app/models/event_log.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/keychat/keychat_message.dart';
import 'package:app/models/message.dart';
import 'package:app/models/mykey.dart';
import 'package:app/models/relay.dart';
import 'package:app/models/room.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/service/chat.service.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart';

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
      bool isPrekey = false,
      Function(bool)? sentCallback}) async {
    Mykey roomKey = room.mykey.value!;
    Identity identity = room.getIdentity();
    ChatxService cs = Get.find<ChatxService>();

    String message0 = message;
    SignalId sharedSignalID = room.getGroupSharedSignalId();
    KeychatIdentityKeyPair keyPair = cs.getKeyPairByIdentity(identity);
    KeychatProtocolAddress? kpa = await cs.getSignalSession(
        myCurve25519PkHex: identity.curve25519PkHex,
        toCurve25519PkHex: sharedSignalID.pubkey,
        keyPair: keyPair,
        deviceId: room.identityId);
    if (kpa == null) throw Exception('kdf group session not found');
    PrekeyMessageModel? pmm;
    if (isPrekey) {
      pmm = await SignalChatUtil.getSignalPrekeyMessageContent(
          room, room.getIdentity(), message);
    }

    (Uint8List, String?, String, List<String>?) enResult =
        await rustSignal.encryptSignal(
            keyPair: keyPair,
            ptext: pmm?.toString() ?? message0,
            remoteAddress: kpa);
    String encryptedContent = base64.encode(enResult.$1);

    String unEncryptedEvent = await rustNostr.getUnencryptEvent(
        senderKeys: identity.secp256k1SKHex,
        receiverPubkey: roomKey.pubkey,
        content: encryptedContent);

    NostrEventModel event =
        NostrEventModel.fromJson(jsonDecode(unEncryptedEvent), verify: false);

    List<String> relays = await Get.find<WebsocketService>().writeNostrEvent(
        event: event,
        eventString: unEncryptedEvent,
        roomId: room.id,
        sentCallback: sentCallback);

    if (!save) {
      return SendMessageResponse(
          relays: relays, events: [event], message: null);
    }

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

  // Future<SendMessageResponse> sendFeatureMessage(Room room, String message,
  //     {MessageMediaType? mediaType,
  //     bool save = true,
  //     MsgReply? reply,
  //     String? realMessage,
  //     int? subtype,
  //     String? ext,
  //     Function(bool)? sentCallback}) async {
  //   Mykey roomKey = room.mykey.value!;

  //   GroupMessage gm = RoomUtil.getGroupMessage(room, message,
  //       pubkey: '', reply: reply, subtype: subtype, ext: ext);
  //   String subEncryptedEvent = await rustNostr.getEncryptEvent(
  //       senderKeys: room.getIdentity().secp256k1SKHex,
  //       receiverPubkey: roomKey.pubkey,
  //       content: gm.toString());

  //   KeychatMessage km = KeychatMessage(
  //       c: MessageType.group,
  //       type: KeyChatEventKinds.groupSharedKeyMessage,
  //       msg: subEncryptedEvent);

  //   String encryptedEvent = await rustNostr.getEncryptEvent(
  //       senderKeys: roomKey.prikey,
  //       receiverPubkey: roomKey.pubkey,
  //       content: km.toString());

  //   NostrEventModel event =
  //       NostrEventModel.fromJson(jsonDecode(encryptedEvent), verify: false);

  //   List<String> relays = await Get.find<WebsocketService>().writeNostrEvent(
  //       event: event,
  //       encryptedEvent: encryptedEvent,
  //       roomId: room.id,
  //       sentCallback: sentCallback);

  //   Message? model;
  //   if (subtype == null && ext == null) {
  //     await DBProvider().saveMyEventLog(event: event, relays: relays);
  //     Identity identity = room.getIdentity();

  //     model = await MessageService().saveMessageToDB(
  //         events: [event],
  //         room: room,
  //         reply: reply,
  //         content: message,
  //         from: identity.secp256k1PKHex,
  //         idPubkey: identity.secp256k1PKHex,
  //         to: room.toMainPubkey,
  //         realMessage: realMessage,
  //         isMeSend: true,
  //         encryptType: MessageEncryptType.nip4WrapNip4,
  //         mediaType: mediaType,
  //         isRead: true);
  //   }
  //   return SendMessageResponse(relays: relays, events: [event], message: model);
  // }

  Future getGroupMembers() async {}

  @override
  Future processMessage(
      {required Room room,
      required NostrEventModel event,
      NostrEventModel? sourceEvent,
      String? msgKeyHash,
      required KeychatMessage km,
      required Relay relay}) async {
    switch (km.type) {
      case KeyChatEventKinds.dm: // commom chat, may be contain: reply
        await RoomService().receiveDM(room, event,
            sourceEvent: sourceEvent, km: km, msgKeyHash: msgKeyHash);
        break;
      case KeyChatEventKinds.kdfHelloMessage:
        await _processHelloMessage(room, event, km, sourceEvent);
        break;

      default:
    }
  }

  // decrypt the first signal message
  Future decryptPreKeyMessage(
      {required RoomMember fromMember,
      required Room room,
      required NostrEventModel event,
      required Relay relay,
      required SignalId sharedSignalId,
      required KeychatIdentityKeyPair keyPair,
      NostrEventModel? sourceEvent,
      EventLog? eventLog}) async {
    var ciphertext = Uint8List.fromList(base64Decode(event.content));
    var prekey = await rustSignal.parseIdentityFromPrekeySignalMessage(
        ciphertext: ciphertext);
    String signalIdPubkey = prekey.$1;
    if (fromMember.curve25519PkHex == null) {
      await fromMember.updateCurve25519PkHex(signalIdPubkey);
    }
    var (plaintext, msgKeyHash, _) = await rustSignal.decryptSignal(
        keyPair: keyPair,
        ciphertext: ciphertext,
        remoteAddress: KeychatProtocolAddress(
            name: signalIdPubkey, deviceId: 10000 + room.id),
        roomId: 0,
        isPrekey: true);
    String decryptedContent = utf8.decode(plaintext);
    PrekeyMessageModel prekeyMessageModel =
        PrekeyMessageModel.fromJson(jsonDecode(decryptedContent));
    logger.i(
        'decryptPreKeyMessage, plainrtext: $prekeyMessageModel, msgKeyHash: $msgKeyHash');

    await SignalChatUtil.verifyPrekeyMessage(
        prekeyMessageModel, room.toMainPubkey);
    KeychatMessage? km;
    try {
      km = KeychatMessage.fromJson(jsonDecode(prekeyMessageModel.message));
    } catch (e) {}

    await RoomService().receiveDM(room, event,
        sourceEvent: null,
        km: km,
        decodedContent: prekeyMessageModel.message,
        realMessage: km?.msg);
    return;
  }

  // shared key receive message then decrypt message
  Future decryptMessage(Room room, NostrEventModel event, Relay relay,
      {NostrEventModel? sourceEvent, EventLog? eventLog}) async {
    if (room.sharedSignalID == null) throw Exception('sharedSignalID is null');

    // setup shared signal id
    ChatxService chatxService = Get.find<ChatxService>();
    SignalId signalId = room.getGroupSharedSignalId();
    var keyPair = chatxService.getKeyPairBySignalId(signalId);
    await chatxService.setupSignalStoreBySignalId(signalId.pubkey, signalId);

    RoomMember? roomMember = await room.getMemberByNostrPubkey(event.pubkey);
    if (roomMember == null) throw Exception('roomMember is null');

    if (roomMember.curve25519PkHex == null) {
      return await decryptPreKeyMessage(
          fromMember: roomMember,
          sharedSignalId: signalId,
          keyPair: keyPair,
          room: room,
          event: event,
          relay: relay,
          eventLog: eventLog);
    }

    rustSignal.KeychatProtocolAddress? kpa = await Get.find<ChatxService>()
        .getSignalSession(
            myCurve25519PkHex: signalId.pubkey,
            toCurve25519PkHex: roomMember.curve25519PkHex!,
            keyPair: keyPair);

    if (kpa == null) {
      return await decryptPreKeyMessage(
          fromMember: roomMember,
          sharedSignalId: signalId,
          keyPair: keyPair,
          room: room,
          event: event,
          relay: relay,
          eventLog: eventLog);
    }

    Uint8List message = Uint8List.fromList(base64Decode(event.content));

    late Uint8List plaintext;
    String? msgKeyHash;
    try {
      (plaintext, msgKeyHash, _) = await rustSignal.decryptSignal(
          keyPair: keyPair,
          ciphertext: message,
          remoteAddress: kpa,
          roomId: room.id,
          isPrekey: false);
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      logger.e(msg, error: e, stackTrace: s);
      await RoomService().receiveDM(room, event,
          decodedContent: 'Decrypt error: $msg', sourceEvent: sourceEvent);
      return;
    }

    String decodeString = utf8.decode(plaintext);

    Map<String, dynamic> decodedContent;
    KeychatMessage? km;
    try {
      decodedContent = jsonDecode(decodeString);
      km = KeychatMessage.fromJson(decodedContent);
      // ignore: empty_catches
    } catch (e) {}

    if (km != null) {
      await processMessage(
          room: room,
          event: event,
          km: km,
          msgKeyHash: msgKeyHash,
          sourceEvent: sourceEvent,
          relay: relay);
      return decodeString;
    }
    await RoomService().receiveDM(room, event,
        decodedContent: decodeString,
        sourceEvent: sourceEvent,
        msgKeyHash: msgKeyHash);
    return decodeString;
  }

  // create a group
  // setup room's sharedSignalID
  // setup room's signal session
  // show shared signalID's QRCode
  // inti identity's signal session
  // send hello message to group shared key but not save
  // shared signal init signal session
  Future<Room> createGroup(String groupName, Identity identity,
      {List<String> toUsers = const []}) async {
    SignalId signalId =
        await SignalIdService.instance.createSignalId(identity.id, true);
    Room room =
        await GroupService().createGroup(groupName, identity, GroupType.kdf);
    room.sharedSignalID = signalId.pubkey;
    await RoomService().updateRoom(room);
    if (toUsers.isNotEmpty) {
      await GroupService()
          .inviteToJoinGroup(room, toUsers: toUsers, signalId: signalId);
    }
    await sendHelloMessage(identity, signalId, room);

    return room;
  }

  // create my signal session with sharedSignalId
  Future<void> sendHelloMessage(
      Identity identity, SignalId signalId, Room room) async {
    await Get.find<ChatxService>()
        .addKPAForSharedSignalId(identity, signalId.pubkey, signalId.keys!);
    // send hello message
    KeychatMessage sm = KeychatMessage(
        c: MessageType.signal, type: KeyChatEventKinds.kdfHelloMessage)
      ..name = identity.displayName
      ..msg = '${identity.displayName} joined group';

    await KdfGroupService.instance
        .sendMessage(room, isPrekey: true, sm.toString(), save: false);
  }

  _processHelloMessage(Room room, NostrEventModel event, KeychatMessage km,
      NostrEventModel? sourceEvent) async {
    if (km.name == null) return;

    await RoomService().receiveDM(room, event,
        sourceEvent: sourceEvent,
        km: km,
        decodedContent: km.toString(),
        realMessage: km.msg);
    // QRUserModel um = QRUserModel.fromJson(jsonDecode(km.name!));

    // TODO update contact name
  }
}
