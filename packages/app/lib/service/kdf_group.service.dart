// KDF group is a shared key group
// Use signal protocol to encrypt message
// Every Member in the group has the same signal id key pair, it's a virtual Member in group
// Every member send message to virtual member

import 'dart:convert' show base64, base64Decode, jsonDecode, utf8;
import 'dart:typed_data' show Uint8List;
import 'package:app/models/keychat/prekey_message_model.dart';
import 'package:app/models/room_member.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/service/signal_chat_util.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rustSignal;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;
import 'package:app/constants.dart';
import 'package:app/models/embedded/msg_reply.dart';
import 'package:app/models/event_log.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/keychat/keychat_message.dart';
import 'package:app/models/message.dart';
import 'package:app/models/relay.dart';
import 'package:app/models/room.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/service/chat.service.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart';

class KdfGroupService extends BaseChatService {
  static KdfGroupService? _instance;
  // Avoid self instance
  KdfGroupService._();
  static KdfGroupService get instance => _instance ??= KdfGroupService._();
  static int prekeyMessageCount = 5;
  Future joinGroup() async {}

  Future leaveGroup() async {}

  // nip4 wrap signal message
  @override
  Future<SendMessageResponse> sendMessage(Room room, String message,
      {MessageMediaType? mediaType,
      bool save = true,
      MsgReply? reply,
      String? realMessage,
      bool notPrekey = true,
      Function(bool)? sentCallback}) async {
    Identity identity = room.getIdentity();
    ChatxService cs = Get.find<ChatxService>();
    RoomMember? meMember =
        await room.getMemberByNostrPubkey(identity.secp256k1PKHex);
    meMember ??= await room.createMember(
        identity.secp256k1PKHex, identity.displayName, UserStatusType.invited);
    String message0 = message;
    SignalId sharedSignalID = room.getGroupSharedSignalId();
    KeychatIdentityKeyPair keyPair = await cs.getKeyPairByIdentity(identity);
    KeychatProtocolAddress? kpa = await cs.getSignalSession(
        sharedSignalRoomId: getKDFRoomIdentityForShared(room.id),
        toCurve25519PkHex: sharedSignalID.pubkey,
        keyPair: keyPair);
    if (kpa == null) throw Exception('kdf group session not found');
    PrekeyMessageModel? pmm;
    if (meMember!.messageCount < prekeyMessageCount) {
      notPrekey = false;
    }
    if (!notPrekey) {
      logger.d('send prekey message ${meMember.messageCount}');
      pmm = await SignalChatUtil.getSignalPrekeyMessageContent(
          room, identity, message);
    }

    (Uint8List, String?, String, List<String>?) enResult =
        await rustSignal.encryptSignal(
            keyPair: keyPair,
            ptext: pmm?.toString() ?? message0,
            remoteAddress: kpa,
            isPrekey: notPrekey);
    String encryptedContent = base64.encode(enResult.$1);

    String unEncryptedEvent = await rustNostr.getUnencryptEvent(
        senderKeys: await identity.getSecp256k1SKHex(),
        receiverPubkey: room.toMainPubkey,
        content: encryptedContent);

    var randomAccount = await rustNostr.generateSimple();

    return await NostrAPI().sendNip4Message(room.toMainPubkey, unEncryptedEvent,
        prikey: randomAccount.prikey,
        from: randomAccount.pubkey,
        room: room,
        encryptType: MessageEncryptType.nip4WrapSignal,
        save: false,
        mediaType: mediaType,
        sourceContent: message0,
        realMessage: realMessage);
  }

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
    room.checkAndCleanSignalKeys();
    var (plaintext, msgKeyHash, _) = await rustSignal.decryptSignal(
        keyPair: keyPair,
        ciphertext: ciphertext,
        remoteAddress: KeychatProtocolAddress(
            name: signalIdPubkey,
            deviceId: getKDFRoomIdentityForShared(room.id)),
        roomId: 0,
        isPrekey: true);

    String decryptedContent = utf8.decode(plaintext);
    PrekeyMessageModel? prekeyMessageModel;
    KeychatMessage? km;
    try {
      prekeyMessageModel =
          PrekeyMessageModel.fromJson(jsonDecode(decryptedContent));
      logger.i('decryptPreKeyMessage, plainrtext: $prekeyMessageModel');
    } catch (e) {}
    if (prekeyMessageModel != null) {
      await SignalChatUtil.verifyPrekeyMessage(
          prekeyMessageModel, room.toMainPubkey);
      try {
        km = KeychatMessage.fromJson(jsonDecode(prekeyMessageModel.message));
        // ignore: empty_catches
      } catch (e) {}
      if (km != null) {
        return await processMessage(
            room: room,
            km: km,
            msgKeyHash: msgKeyHash,
            event: event,
            sourceEvent: sourceEvent,
            relay: relay);
      }
    }

    await RoomService().receiveDM(room, event,
        sourceEvent: sourceEvent,
        km: km,
        decodedContent: prekeyMessageModel?.message ?? decryptedContent,
        msgKeyHash: msgKeyHash,
        realMessage: km?.msg);
    return;
  }

  // shared key receive message then decrypt message
  // message struct: nip4 wrap signal
  Future decryptMessage(Room room, NostrEventModel nostrEvent, Relay relay,
      {required String nip4DecodedContent, EventLog? eventLog}) async {
    if (room.sharedSignalID == null) throw Exception('sharedSignalID is null');

    // setup shared signal id
    ChatxService chatxService = Get.find<ChatxService>();
    SignalId signalId = room.getGroupSharedSignalId();
    var keyPair = chatxService.getKeyPairBySignalId(signalId);
    await chatxService.setupSignalStoreBySignalId(signalId.pubkey, signalId);

    // sub event
    NostrEventModel signalEvent =
        NostrEventModel.fromJson(jsonDecode(nip4DecodedContent));
    String from = signalEvent.pubkey;
    RoomMember? roomMember = await room.getMemberByNostrPubkey(from);

    if (roomMember == null) throw Exception('roomMember is null');
    room.incrMessageCountForMemeber(roomMember);
    if (roomMember.curve25519PkHex == null) {
      return await decryptPreKeyMessage(
          fromMember: roomMember,
          sharedSignalId: signalId,
          keyPair: keyPair,
          room: room,
          event: signalEvent,
          sourceEvent: nostrEvent,
          relay: relay,
          eventLog: eventLog);
    }

    rustSignal.KeychatProtocolAddress? kpa = await Get.find<ChatxService>()
        .getSignalSession(
            sharedSignalRoomId: getKDFRoomIdentityForShared(room.id),
            toCurve25519PkHex: roomMember.curve25519PkHex!,
            keyPair: keyPair);

    if (kpa == null) {
      return await decryptPreKeyMessage(
          fromMember: roomMember,
          sharedSignalId: signalId,
          keyPair: keyPair,
          room: room,
          event: signalEvent,
          sourceEvent: nostrEvent,
          relay: relay,
          eventLog: eventLog);
    }

    Uint8List message = Uint8List.fromList(base64Decode(signalEvent.content));

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
      try {
        await decryptPreKeyMessage(
            fromMember: roomMember,
            sharedSignalId: signalId,
            keyPair: keyPair,
            room: room,
            event: signalEvent,
            sourceEvent: nostrEvent,
            relay: relay,
            eventLog: eventLog);
        return;
      } catch (e) {
        String msg = Utils.getErrorMessage(e);
        logger.e(msg, error: e);
      }
      String msg = Utils.getErrorMessage(e);
      logger.e(msg, error: e, stackTrace: s);
      await RoomService().receiveDM(room, signalEvent,
          decodedContent: 'Decrypt error: $msg', sourceEvent: nostrEvent);
      return;
    }

    String decodeString = utf8.decode(plaintext);

    // try km message
    Map<String, dynamic>? decodedContentMap;
    KeychatMessage? km;
    try {
      decodedContentMap = jsonDecode(decodeString);
      km = KeychatMessage.fromJson(decodedContentMap!);
    } catch (e) {}
    if (km != null) {
      return await processMessage(
          room: room,
          km: km,
          msgKeyHash: msgKeyHash,
          event: signalEvent,
          sourceEvent: nostrEvent,
          relay: relay);
    }

    // try prekey message
    PrekeyMessageModel? prekeyMessageModel;
    if (decodedContentMap != null && km == null) {
      try {
        prekeyMessageModel = PrekeyMessageModel.fromJson(decodedContentMap);
        logger.i('decryptPreKeyMessage, plainrtext: $prekeyMessageModel');
        // ignore: empty_catches
      } catch (e) {}
      if (prekeyMessageModel != null) {
        await SignalChatUtil.verifyPrekeyMessage(
            prekeyMessageModel, room.toMainPubkey);
      }
    }

    await RoomService().receiveDM(room, signalEvent,
        decodedContent: prekeyMessageModel?.message ?? decodeString,
        sourceEvent: nostrEvent,
        msgKeyHash: msgKeyHash);
  }

  int getKDFRoomIdentityForShared(int identityId) => 10000 + identityId;

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
    await Get.find<ChatxService>().addKPAForSharedSignalId(identity,
        signalId.pubkey, signalId.keys!, getKDFRoomIdentityForShared(room.id));
    // send hello message
    KeychatMessage sm = KeychatMessage(
        c: MessageType.signal, type: KeyChatEventKinds.kdfHelloMessage)
      ..name = identity.displayName
      ..msg = '${identity.displayName} joined group';

    await KdfGroupService.instance
        .sendMessage(room, notPrekey: false, sm.toString(), save: false);
  }

  _processHelloMessage(Room room, NostrEventModel event, KeychatMessage km,
      NostrEventModel? sourceEvent) async {
    if (km.name == null) return;

    // update room member
    RoomMember? rm = await room.getMemberByIdPubkey(event.pubkey);
    rm ??=
        await room.createMember(event.pubkey, km.name!, UserStatusType.invited);
    if (rm != null) {
      if (rm.status != UserStatusType.invited) {
        rm.status = UserStatusType.invited;
        rm.name = km.name!;
        await room.updateMember(rm);
        RoomService.getController(room.id)?.resetMembers();
      }
    }

    // receive message
    await RoomService().receiveDM(room, event,
        sourceEvent: sourceEvent,
        km: km,
        decodedContent: km.toString(),
        realMessage: km.msg);
  }
}
