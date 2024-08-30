// KDF group is a shared key group
// Use signal protocol to encrypt message
// Every Member in the group has the same signal id key pair, it's a virtual Member in group
// Every member send message to virtual member

import 'dart:convert' show base64, base64Decode, jsonDecode, jsonEncode, utf8;
import 'dart:typed_data' show Uint8List;
import 'package:app/global.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/keychat/room_profile.dart';
import 'package:app/models/mykey.dart';
import 'package:app/models/room_member.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/group_tx.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
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

  // nip4 wrap signal message
  @override
  Future<SendMessageResponse> sendMessage(Room room, String message,
      {MessageMediaType? mediaType,
      bool save = false,
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
    KeychatIdentityKeyPair keyPair = await room.getKeyPair();
    SignalId sharedSignalID = room.getGroupSharedSignalId();
    KeychatProtocolAddress? kpa = await cs.getSignalSession(
        sharedSignalRoomId: getKDFRoomIdentityForShared(room.id),
        toCurve25519PkHex: sharedSignalID.pubkey,
        keyPair: keyPair);
    if (kpa == null) throw Exception('kdf group session not found');
    if (meMember!.messageCount < KeychatGlobal.kdfGroupPrekeyMessageCount) {
      notPrekey = false;
    }

    (Uint8List, String?, String, List<String>?) enResult =
        await rust_signal.encryptSignal(
            keyPair: keyPair,
            ptext: message0,
            remoteAddress: kpa,
            isPrekey: notPrekey);
    String encryptedContent = base64.encode(enResult.$1);
    String receiverPubkey = room.mykey.value!.pubkey;
    String unEncryptedEvent = await rust_nostr.getUnencryptEvent(
        senderKeys: await identity.getSecp256k1SKHex(),
        receiverPubkey: room.toMainPubkey,
        content: encryptedContent);

    var randomAccount = await rust_nostr.generateSimple();

    return await NostrAPI().sendNip4Message(receiverPubkey, unEncryptedEvent,
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
      case KeyChatEventKinds.kdfHelloMessage:
        return await _processHelloMessage(room, event, km,
            sourceEvent: sourceEvent, msgKeyHash: msgKeyHash);
      case KeyChatEventKinds.groupExist:
        // self exit group
        if (event.pubkey == room.myIdPubkey) {
          return;
        }
        await room.removeMember(event.pubkey);
        RoomService.getController(room.id)?.resetMembers();
        return RoomService().receiveDM(room, event,
            sourceEvent: sourceEvent, realMessage: km.msg);
      case KeyChatEventKinds.groupDissolve:
        await room.checkAdminByIdPubkey(event.pubkey);
        room.status = RoomStatus.dissolved;
        return await RoomService().updateRoom(room);
      case KeyChatEventKinds.kdfAdminRemoveMembers:
        return await _proccessAdminRemoveMembers(room, event, km, sourceEvent);
      case KeyChatEventKinds.inviteNewMember:
      case KeyChatEventKinds.kdfUpdateKeys:
        RoomProfile roomProfile = RoomProfile.fromJson(jsonDecode(km.name!));
        Room groupRoom = await getGroupRoomByIdRoom(room, roomProfile);
        // check sender is admin
        await groupRoom.checkAdminByIdPubkey(event.pubkey);

        await proccessUpdateKeys(groupRoom, roomProfile);
        await RoomService().receiveDM(groupRoom, event,
            sourceEvent: sourceEvent, decodedContent: km.msg!);
        return;
      default:
    }
    logger.d(km.toString());
    await RoomService()
        .receiveDM(room, event, sourceEvent: sourceEvent, km: km);
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
    var prekey = await rust_signal.parseIdentityFromPrekeySignalMessage(
        ciphertext: ciphertext);
    String signalIdPubkey = prekey.$1;

    var (plaintext, msgKeyHash, _) = await rust_signal.decryptSignal(
        keyPair: keyPair,
        ciphertext: ciphertext,
        remoteAddress: KeychatProtocolAddress(
            name: signalIdPubkey,
            deviceId: getKDFRoomIdentityForShared(room.id)),
        roomId: 0,
        isPrekey: true);

    // update room member
    fromMember.curve25519PkHex = signalIdPubkey;
    await room.updateMember(fromMember);

    // proccess message
    String decryptedContent = utf8.decode(plaintext);

    KeychatMessage? km;
    try {
      km = KeychatMessage.fromJson(jsonDecode(decryptedContent));
      // ignore: empty_catches
    } catch (e) {}
    if (km != null) {
      return await km.service.processMessage(
          room: room,
          km: km,
          msgKeyHash: msgKeyHash,
          event: event,
          sourceEvent: sourceEvent,
          relay: relay);
    }

    await RoomService().receiveDM(room, event,
        sourceEvent: sourceEvent,
        km: km,
        decodedContent: decryptedContent,
        msgKeyHash: msgKeyHash,
        realMessage: km?.msg);
    return;
  }

  // shared key receive message then decrypt message
  // message struct: nip4 wrap signal
  Future decryptMessage(Room room, NostrEventModel nostrEvent, Relay relay,
      {required String nip4DecodedContent, EventLog? eventLog}) async {
    if (room.sharedSignalID == null) throw Exception('sharedSignalID is null');

    // sub event
    NostrEventModel signalEvent =
        NostrEventModel.fromJson(jsonDecode(nip4DecodedContent));
    String from = signalEvent.pubkey;
    RoomMember? roomMember = await room.getMemberByNostrPubkey(from);

    if (roomMember == null) throw Exception('roomMember is null');
    room.incrMessageCountForMemeber(roomMember);

    // setup shared signal id
    ChatxService chatxService = Get.find<ChatxService>();
    SignalId signalId = room.getGroupSharedSignalId();
    var keyPair = (await room.getSharedKeyPair())!;
    await chatxService.setupSignalStoreBySignalId(signalId.pubkey, signalId);

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
    rust_signal.KeychatProtocolAddress? kpa = await Get.find<ChatxService>()
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
      (plaintext, msgKeyHash, _) = await rust_signal.decryptSignal(
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
      } catch (e, s) {
        String msg = Utils.getErrorMessage(e);
        logger.e(msg, error: e, stackTrace: s);
      }
      String msg = Utils.getErrorMessage(e);
      logger.e(msg, error: e, stackTrace: s);
      await RoomService().receiveDM(room, signalEvent,
          decodedContent: 'Decrypt error: $msg', sourceEvent: nostrEvent);
      return;
    }

    String decodeString = utf8.decode(plaintext);

    // try km message
    KeychatMessage? km;
    try {
      Map<String, dynamic>? decodedContentMap = jsonDecode(decodeString);
      km = KeychatMessage.fromJson(decodedContentMap!);
      // ignore: empty_catches
    } catch (e) {}
    if (km != null) {
      return await km.service.processMessage(
          room: room,
          km: km,
          msgKeyHash: msgKeyHash,
          event: signalEvent,
          sourceEvent: nostrEvent,
          relay: relay);
    }

    await RoomService().receiveDM(room, signalEvent,
        decodedContent: decodeString,
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
  Future<Room> createGroup(
      String groupName, Identity identity, Map<String, String> toUsers) async {
    SignalId signalId =
        await SignalIdService.instance.createSignalId(identity.id, true);
    Room room =
        await GroupService().createGroup(groupName, identity, GroupType.kdf);
    room.sharedSignalID = signalId.pubkey;
    await RoomService().updateRoom(room);
    if (toUsers.isNotEmpty) {
      await GroupService().inviteToJoinGroup(room, toUsers, signalId: signalId);
    }
    await sendHelloMessage(identity, signalId, room);

    return room;
  }

  // create my signal session with sharedSignalId
  Future<void> sendHelloMessage(
      Identity identity, SignalId sharedSignalId, Room room) async {
    // update my signalId
    SignalId userSignalId =
        await SignalIdService.instance.createSignalId(room.identityId);
    room.signalIdPubkey = userSignalId.pubkey;
    await RoomService().updateRoom(room);
    RoomService.getController(room.id)?.setRoom(room);

    await Get.find<ChatxService>().addKPAByRoomSignalId(
        userSignalId,
        sharedSignalId.pubkey,
        sharedSignalId.keys!,
        getKDFRoomIdentityForShared(room.id));
    // send hello message
    KeychatMessage sm = KeychatMessage(
        c: MessageType.kdfGroup, type: KeyChatEventKinds.kdfHelloMessage)
      ..name = identity.displayName
      ..msg = '${identity.displayName} joined group';

    await KdfGroupService.instance
        .sendMessage(room, notPrekey: false, sm.toString());
  }

  _processHelloMessage(Room room, NostrEventModel event, KeychatMessage km,
      {String? msgKeyHash, NostrEventModel? sourceEvent}) async {
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
        msgKeyHash: msgKeyHash,
        decodedContent: km.toString(),
        realMessage: km.msg);
  }

  Future inviteToJoinGroup(Room room, Map<String, String> users) async {
    SignalId signalId =
        await SignalIdService.instance.createSignalId(room.identityId, true);
    Mykey mykey = await GroupTx().createMykey(room.identityId);
    RoomProfile roomProfile = await GroupService()
        .inviteToJoinGroup(room, users, signalId: signalId, mykey: mykey);

    String names = users.values.toList().join(',');
    KeychatMessage sm = KeychatMessage(
        c: MessageType.kdfGroup, type: KeyChatEventKinds.inviteNewMember)
      ..name = roomProfile.toString()
      ..msg =
          '''Invite ${names.isNotEmpty ? names : users.keys.join(',').toString()} to join group.
All members will update the shared-secret-keys and initial signal ratchet''';

    await KdfGroupService.instance.sendMessage(room, sm.toString());
  }

  deleteExpiredGroupKeys() {
    throw UnimplementedError();
  }

  // 1. The group owner locally updates the group member list and creates a new group QR code
  // 2. 1-to-1 messages are sent to the active group members, and the recipients change the new group QR code.
  // 3. Send a message to the kicked users, and the recipient will change the local group status.
  Future removeMembers(Room room, List<RoomMember> list) async {
    // Send a message to the users who need to be deleted
    List<String> idPubkeys = [];
    List<String> names = [];
    for (RoomMember rm in list) {
      await room.setMemberDisable(rm);
      idPubkeys.add(rm.idPubkey);
      names.add(rm.name);
    }
    KeychatMessage sm = KeychatMessage(
        c: MessageType.kdfGroup, type: KeyChatEventKinds.kdfAdminRemoveMembers)
      ..name = jsonEncode(idPubkeys)
      ..msg = 'Admin remove members: ${names.join(',')}';

    await KdfGroupService.instance.sendMessage(room, sm.toString());
    await Future.delayed(const Duration(seconds: 1));
    // create new group info and send to all active members
    await sendNewKeysToActiveMembers(room);
  }

  Future sendNewKeysToActiveMembers(Room room) async {
    SignalId signalId =
        await SignalIdService.instance.createSignalId(room.identityId, true);
    Mykey mykey = await GroupTx().createMykey(room.identityId);
    RoomProfile roomProfile = await GroupService()
        .getRoomProfile(room, signalId: signalId, mykey: mykey);

    KeychatMessage km = KeychatMessage(
        c: MessageType.kdfGroup, type: KeyChatEventKinds.kdfUpdateKeys)
      ..name = roomProfile.toString()
      ..msg = 'Update signal and nostr\'s keys for group [${room.name}]';
    // self update keys
    await proccessUpdateKeys(room, roomProfile);

    List<RoomMember> members = await room.getActiveMembers();
    await GroupService().sendPrivateMessageToMembers(
        km.msg!, members, room.getIdentity(),
        groupRoom: room, km: km);
  }

  // If the deleted person includes himself, mark the room as kicked.
  // If it is not included, it will not be processed and the message will be displayed directly.
  Future _proccessAdminRemoveMembers(Room room, NostrEventModel event,
      KeychatMessage km, NostrEventModel? sourceEvent) async {
    List toRemoveIdPubkeys = jsonDecode(km.name!);
    Identity identity = room.getIdentity();
    String toSaveMsg = km.msg!;
    if (toRemoveIdPubkeys.contains(identity.secp256k1PKHex)) {
      room.status = RoomStatus.removedFromGroup;
      await RoomService().updateRoom(room);
      room.status = RoomStatus.removedFromGroup;
      toSaveMsg = '🤖 You have been removed by admin.';
      RoomService().receiveDM(room, event,
          decodedContent: toSaveMsg, sourceEvent: sourceEvent);
      room = await RoomService().updateRoom(room);
      RoomService.getController(room.id)?.setRoom(room);
      return;
    }

    RoomService().receiveDM(room, event,
        sourceEvent: sourceEvent, decodedContent: km.msg);
  }

  Future<Room> proccessUpdateKeys(
      Room groupRoom, RoomProfile roomProfile) async {
    if (roomProfile.updatedAt! < groupRoom.version) {
      throw Exception('The invitation has expired');
    }

    var keychain = rust_nostr.Secp256k1Account(
        prikey: roomProfile.prikey!,
        pubkey: roomProfile.pubkey,
        pubkeyBech32: '',
        prikeyBech32: '');

    SignalId? toDeleteSharedSignalId = await SignalIdService.instance
        .getSignalIdByPubkey(groupRoom.sharedSignalID);
    SignalId? toDeleteMySignalId = await SignalIdService.instance
        .getSignalIdByPubkey(groupRoom.signalIdPubkey);

    List<RoomMember> members = await groupRoom.getMembers();
    Mykey toDeleteMykey = groupRoom.mykey.value!;
    Identity identity = groupRoom.getIdentity();

    await DBProvider.database.writeTxn(() async {
      // clear signalid session and config
      if (toDeleteSharedSignalId != null) {
        int deviceId = getKDFRoomIdentityForShared(groupRoom.id);
        final sharedKeyAddress = KeychatProtocolAddress(
            name: toDeleteSharedSignalId.pubkey, deviceId: deviceId);

        await rust_signal.deleteSession(
            keyPair: await groupRoom.getKeyPair(), address: sharedKeyAddress);

        KeychatIdentityKeyPair? sharedKeypair =
            await groupRoom.getSharedKeyPair();
        if (sharedKeypair != null) {
          for (var member in members) {
            if (member.curve25519PkHex == null) continue;

            final memberAddress = KeychatProtocolAddress(
                name: member.curve25519PkHex!, deviceId: deviceId);

            await rust_signal.deleteSession(
                keyPair: sharedKeypair, address: memberAddress);
          }
        }
      }
      // import new signalId
      SignalId sharedSignalId = await SignalIdService.instance
          .importOrGetSignalId(identity.id, roomProfile);

      // update room members
      await groupRoom.updateAllMemberTx(roomProfile.users);
      // delete old mykey and import new one

      Mykey mykey = await GroupTx().importMykeyTx(identity.id, keychain);
      groupRoom.sharedSignalID = sharedSignalId.pubkey;
      groupRoom.mykey.value = mykey;
      groupRoom.status = RoomStatus.enabled;
      groupRoom.version =
          roomProfile.updatedAt ?? DateTime.now().millisecondsSinceEpoch;
      await GroupTx().updateRoom(groupRoom, updateMykey: true);

      await DBProvider.database.mykeys
          .filter()
          .idEqualTo(toDeleteMykey.id)
          .deleteFirst();

      bool deleteResult1 =
          await SignalIdService.instance.deleteSignalId(toDeleteSharedSignalId);
      bool deleteResult2 =
          await SignalIdService.instance.deleteSignalId(toDeleteMySignalId);
      logger.d('delete signalId result: $deleteResult1, $deleteResult2');
    });
    RoomService.getController(groupRoom.id)?.setRoom(groupRoom).resetMembers();

    // start listen
    await Get.find<WebsocketService>().listenPubkey([keychain.pubkey],
        since: DateTime.fromMillisecondsSinceEpoch(
            roomProfile.updatedAt! - 10 * 1000));
    NotifyService.addPubkeys([keychain.pubkey]);

    await Future.delayed(
        const Duration(seconds: 1)); // message delay for multi task

    await sendHelloMessage(
        identity, groupRoom.getGroupSharedSignalId(), groupRoom);
    return groupRoom;
  }

  Future<Room> getGroupRoomByIdRoom(Room room, RoomProfile roomProfile) async {
    if (room.type == RoomType.group) return room;

    String pubkey = roomProfile.oldToRoomPubKey ?? roomProfile.pubkey;
    var group = await DBProvider.database.rooms
        .filter()
        .toMainPubkeyEqualTo(pubkey)
        .identityIdEqualTo(room.identityId)
        .findFirst();
    if (group == null) throw Exception('GroupRoom not found');
    return group;
  }
}
