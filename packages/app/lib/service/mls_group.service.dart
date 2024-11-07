// KDF group is a shared key group
// Use signal protocol to encrypt message
// Every Member in the group has the same signal id key pair, it's a virtual Member in group
// Every member send message to virtual member

import 'dart:convert' show base64, base64Decode, jsonDecode, jsonEncode, utf8;

import 'package:app/constants.dart';
import 'package:app/global.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/embedded/msg_reply.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/keychat/keychat_message.dart';
import 'package:app/models/keychat/room_profile.dart';
import 'package:app/models/message.dart';
import 'package:app/models/mykey.dart';
import 'package:app/models/nostr_event_status.dart';
import 'package:app/models/room.dart';
import 'package:app/models/room_member.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/service/chat.service.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/group_tx.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;
import 'package:keychat_rust_ffi_plugin/api_mls.dart' as rust_mls;
import 'package:keychat_rust_ffi_plugin/api_signal.dart';

class MlsGroupService extends BaseChatService {
  static MlsGroupService? _instance;
  static MlsGroupService get instance => _instance ??= MlsGroupService._();
  static String? dbPath;
  // Avoid self instance
  MlsGroupService._();

  bool adminOnlyMiddleware(RoomMember from, int type) {
    const Set<int> adminTypes = {
      KeyChatEventKinds.kdfAdminRemoveMembers,
      KeyChatEventKinds.inviteNewMember,
      KeyChatEventKinds.kdfUpdateKeys,
      KeyChatEventKinds.groupDissolve
    };
    if (adminTypes.contains(type)) {
      if (from.isAdmin) return true;
      throw Exception('Permission denied');
    }
    return true;
  }

  Future appendMessageOrCreate(String error, Room room, String content,
      NostrEventModel signalEvent, NostrEventModel nostrEvent) async {
    Message? message = await DBProvider.database.messages
        .filter()
        .msgidEqualTo(nostrEvent.id)
        .findFirst();
    if (message == null) {
      await RoomService().receiveDM(room, signalEvent,
          decodedContent: '''
$error

track: $content''',
          sourceEvent: nostrEvent);
      return;
    }
    message.content = '''${message.content}

$error ''';
    await MessageService().updateMessageAndRefresh(message);
  }

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

  // shared key receive message then decrypt message
  // message struct: nip4 wrap signal
  Future decryptMessage(Room room, NostrEventModel nostrEvent,
      {required String nip4DecodedContent,
      required Function(String) failedCallback}) async {
    if (room.sharedSignalID == null) throw Exception('sharedSignalID is null');

    // sub event
    NostrEventModel signalEvent =
        NostrEventModel.fromJson(jsonDecode(nip4DecodedContent));
    String from = signalEvent.pubkey;
    RoomMember? fromMember = await room.getMemberByNostrPubkey(from);

    if (fromMember == null) {
      String msg = 'roomMember is null';
      failedCallback(room.getDebugInfo(msg));
      throw Exception('roomMember is null');
    }

    // setup shared signal id
    SignalId signalId = room.getGroupSharedSignalId();
    KeychatIdentityKeyPair keyPair = await Get.find<ChatxService>()
        .setupSignalStoreBySignalId(signalId.pubkey, signalId);

    Uint8List ciphertext =
        Uint8List.fromList(base64Decode(signalEvent.content));
    bool isPrekey =
        await rust_signal.parseIsPrekeySignalMessage(ciphertext: ciphertext);
    if (isPrekey) {
      try {
        await _decryptPreKeyMessage(
            fromMember: fromMember,
            sharedSignalId: signalId,
            keyPair: keyPair,
            room: room,
            event: signalEvent,
            ciphertext: ciphertext,
            sourceEvent: nostrEvent);
      } catch (e, s) {
        String msg = Utils.getErrorMessage(e);
        if (msg.contains(ErrorMessages.signedPrekeyNotfound)) {
          msg = '[Error]The sender\'s signal session expired, please reinvite';
        }
        logger.e('decryptPreKeyMessage error: $msg', error: e, stackTrace: s);
        await appendMessageOrCreate(
            msg, room, 'decryptPreKeyMessage', signalEvent, nostrEvent);
      }
      return;
    }
    KeychatProtocolAddress? kpa =
        await _checkIsPrekeyByRoom(fromMember.curve25519PkHex, room, keyPair);
    if (kpa == null) {
      await appendMessageOrCreate('session is null', room,
          'decryptMessageError', signalEvent, nostrEvent);
      return;
    }
    late Uint8List plaintext;
    String? msgKeyHash;
    try {
      (plaintext, msgKeyHash, _) = await rust_signal.decryptSignal(
          keyPair: keyPair,
          ciphertext: ciphertext,
          remoteAddress: kpa,
          roomId: room.id,
          isPrekey: false);

      await room.incrMessageCountForMember(fromMember);
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      if (msg != ErrorMessages.signalDecryptError) {
        logger.e(msg, error: e, stackTrace: s);
      } else {
        loggerNoLine.e(msg);
      }
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
    if (km == null) {
      await RoomService().receiveDM(room, signalEvent,
          decodedContent: decodeString,
          sourceEvent: nostrEvent,
          msgKeyHash: msgKeyHash);
      return;
    }
    try {
      adminOnlyMiddleware(fromMember, km.type);
      await km.service.proccessMessage(
          room: room,
          km: km,
          msgKeyHash: msgKeyHash,
          event: signalEvent,
          sourceEvent: nostrEvent,
          fromIdPubkey: fromMember.idPubkey);
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      logger.e('decryptPreKeyMessage error: $msg', error: e, stackTrace: s);
      await appendMessageOrCreate(
          msg, room, 'kdf km processMessage', signalEvent, nostrEvent);
    }
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

  int getKDFRoomIdentityForShared(int identityId) => 10000 + identityId;

  Future inviteToJoinGroup(Room room, Map<String, String> users,
      [String? sender]) async {
    SignalId signalId =
        await SignalIdService.instance.createSignalId(room.identityId, true);
    Mykey mykey = await GroupTx().createMykey(room.identityId, room.id);
    RoomProfile roomProfile = await GroupService()
        .inviteToJoinGroup(room, users, signalId: signalId, mykey: mykey);

    String names = users.values.toList().join(',');
    KeychatMessage sm = KeychatMessage(
        c: MessageType.kdfGroup, type: KeyChatEventKinds.inviteNewMember)
      ..name = roomProfile.toString()
      ..msg =
          '''${sender == null ? 'Invite' : '[$sender] invite'} [${names.isNotEmpty ? names : users.keys.join(',').toString()}] to join group.
Let's create a new group.''';

    await MlsGroupService.instance.sendMessage(room, sm.toString());
  }

  @override
  Future proccessMessage(
      {required Room room,
      required NostrEventModel event,
      NostrEventModel? sourceEvent,
      Function(String error)? failedCallback,
      String? msgKeyHash,
      String? fromIdPubkey,
      required KeychatMessage km}) async {
    switch (km.type) {
      case KeyChatEventKinds.kdfHelloMessage:
        await _proccessHelloMessage(room, event, km,
            sourceEvent: sourceEvent, msgKeyHash: msgKeyHash);
        return;
      case KeyChatEventKinds.groupExist:
        // self exit group
        if (event.pubkey == room.myIdPubkey) {
          return;
        }
        await room.removeMember(event.pubkey);
        RoomService.getController(room.id)?.resetMembers();
        await RoomService().receiveDM(room, event,
            sourceEvent: sourceEvent,
            realMessage: km.msg,
            isSystem: true,
            fromIdPubkey: fromIdPubkey);
        return;
      case KeyChatEventKinds.groupDissolve:
        room.status = RoomStatus.dissolved;
        await RoomService().updateRoom(room);
        await RoomService().receiveDM(room, event,
            sourceEvent: sourceEvent,
            decodedContent: km.msg!,
            isSystem: true,
            fromIdPubkey: fromIdPubkey);
      case KeyChatEventKinds.kdfAdminRemoveMembers:
        await _proccessAdminRemoveMembers(room, event, km, sourceEvent);
        return;
      case KeyChatEventKinds.inviteNewMember:
      case KeyChatEventKinds.kdfUpdateKeys:
        RoomProfile roomProfile = RoomProfile.fromJson(jsonDecode(km.name!));
        Room groupRoom = await getGroupRoomByIdRoom(room, roomProfile);
        if (roomProfile.updatedAt < groupRoom.version) {
          throw Exception('The invitation has expired');
        }
        await RoomService().receiveDM(groupRoom, event,
            sourceEvent: sourceEvent,
            decodedContent: km.msg!,
            isSystem: true,
            fromIdPubkey: fromIdPubkey);
        await proccessUpdateKeys(groupRoom, roomProfile);
        return;
      default:
        await RoomService().receiveDM(room, event,
            sourceEvent: sourceEvent, km: km, fromIdPubkey: fromIdPubkey);
    }
  }

  Future<Room> proccessUpdateKeys(
      Room groupRoom, RoomProfile roomProfile) async {
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
    KeychatIdentityKeyPair myKeyPair = await groupRoom.getKeyPair();
    KeychatIdentityKeyPair? sharedKeypair = await groupRoom.getSharedKeyPair();

    // clear signalid session and config
    await DBProvider.database.writeTxn(() async {
      if (toDeleteSharedSignalId != null) {
        int deviceId = getKDFRoomIdentityForShared(groupRoom.id);
        final sharedKeyAddress = KeychatProtocolAddress(
            name: toDeleteSharedSignalId.pubkey, deviceId: deviceId);

        await rust_signal.deleteSession(
            keyPair: myKeyPair, address: sharedKeyAddress);

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

      Mykey mykey =
          await GroupTx().importMykeyTx(identity.id, keychain, groupRoom.id);
      groupRoom.sharedSignalID = sharedSignalId.pubkey;
      groupRoom.mykey.value = mykey;
      groupRoom.status = RoomStatus.enabled;
      groupRoom.version = roomProfile.updatedAt;
      groupRoom = await GroupTx().updateRoom(groupRoom, updateMykey: true);

      // proccess shared nostr pubkey
      Get.find<WebsocketService>()
          .removePubkeyFromSubscription(toDeleteMykey.pubkey);
      NotifyService.removePubkeys([toDeleteMykey.pubkey]);
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

    // String toSaveSystemMessage =
    //     '''Reset room's session success. ${groupRoom.sharedSignalID}''';
    // await MessageService().saveSystemMessage(groupRoom, toSaveSystemMessage);
    // start listen
    await Get.find<WebsocketService>().listenPubkey([keychain.pubkey],
        since: DateTime.fromMillisecondsSinceEpoch(
            roomProfile.updatedAt - 10 * 1000));
    NotifyService.addPubkeys([keychain.pubkey]);

    await sendHelloMessage(
        identity, groupRoom.getGroupSharedSignalId(), groupRoom);
    await Future.delayed(const Duration(milliseconds: 100));
    return groupRoom;
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

    await MlsGroupService.instance.sendMessage(room, sm.toString());
    await Future.delayed(const Duration(seconds: 1));
    // create new group info and send to all active members
    await sendNewKeysToActiveMembers(room);
  }

  // create my signal session with sharedSignalId
  Future sendHelloMessage(
      Identity identity, SignalId sharedSignalId, Room room) async {
    logger.d('sendHelloMessage, version: ${room.version}');
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
    SendMessageResponse smr = await MlsGroupService.instance
        .sendMessage(room, notPrekey: false, sm.toString());

    var toSendEvent = smr.events[0];
    DateTime createdAt =
        DateTime.fromMillisecondsSinceEpoch(toSendEvent.createdAt * 1000);
    _messageReceiveCheck(
            room, toSendEvent, const Duration(milliseconds: 500), 3)
        .then((success) async {
      if (success) return;
      Room exist = await RoomService().getRoomByIdOrFail(room.id);
      String msg = exist.version == room.version
          ? 'Send hello_message failed, but the receive key changed, ignore this message, version: ${room.version}'
          : 'The receive key changed, ignore this message';
      MessageService().saveSystemMessage(room, msg, createdAt: createdAt);
    });
  }

  // nip4 wrap signal message
  @override
  Future<SendMessageResponse> sendMessage(Room room, String message,
      {MessageMediaType? mediaType,
      bool save = false,
      MsgReply? reply,
      String? realMessage,
      bool notPrekey = true}) async {
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

  Future sendNewKeysToActiveMembers(Room room) async {
    SignalId signalId =
        await SignalIdService.instance.createSignalId(room.identityId, true);
    Mykey mykey = await GroupTx().createMykey(room.identityId, room.id);
    RoomProfile roomProfile = await GroupService()
        .getRoomProfile(room, signalId: signalId, mykey: mykey);

    KeychatMessage km = KeychatMessage(
        c: MessageType.kdfGroup, type: KeyChatEventKinds.kdfUpdateKeys)
      ..name = roomProfile.toString()
      ..msg = 'Let\'s reset the status of group [${room.name}]';

    List<RoomMember> members = await room.getActiveMembers();
    await GroupService().sendPrivateMessageToMembers(
        km.msg!, members, room.getIdentity(),
        groupRoom: room, km: km);
    await Future.delayed(const Duration(seconds: 1));
    // myself update keys
    await proccessUpdateKeys(room, roomProfile);
  }

  Future<KeychatProtocolAddress?> _checkIsPrekeyByRoom(String? memberPubkey,
      Room room, rust_signal.KeychatIdentityKeyPair keyPair) async {
    if (memberPubkey == null) {
      logger.d('memberPubkey is null');
      return null;
    }

    rust_signal.KeychatProtocolAddress? kpa = await Get.find<ChatxService>()
        .getSignalSession(
            sharedSignalRoomId: getKDFRoomIdentityForShared(room.id),
            toCurve25519PkHex: memberPubkey,
            keyPair: keyPair);
    return kpa;
  }

  // decrypt the first signal message
  Future _decryptPreKeyMessage(
      {required RoomMember fromMember,
      required Room room,
      required NostrEventModel event,
      required SignalId sharedSignalId,
      required KeychatIdentityKeyPair keyPair,
      required Uint8List ciphertext,
      NostrEventModel? sourceEvent}) async {
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
    await room.incrMessageCountForMember(fromMember);

    // proccess message
    String decryptedContent = utf8.decode(plaintext);

    KeychatMessage? km;
    try {
      km = KeychatMessage.fromJson(jsonDecode(decryptedContent));
      // ignore: empty_catches
    } catch (e) {}
    if (km == null) {
      await RoomService().receiveDM(room, event,
          sourceEvent: sourceEvent,
          km: km,
          decodedContent: decryptedContent,
          msgKeyHash: msgKeyHash,
          realMessage: km?.msg);
      return;
    }

    adminOnlyMiddleware(fromMember, km.type);
    await km.service.proccessMessage(
        room: room,
        km: km,
        msgKeyHash: msgKeyHash,
        event: event,
        sourceEvent: sourceEvent,
        fromIdPubkey: fromMember.idPubkey);
  }

  Future<bool> _messageReceiveCheck(
      Room room, NostrEventModel event, Duration delay, int maxRetry) async {
    if (maxRetry == 0) return false;
    maxRetry--;
    await Future.delayed(delay);
    String id = event.id;
    NostrEventStatus? nes = await DBProvider.database.nostrEventStatus
        .filter()
        .eventIdEqualTo(id)
        .sendStatusEqualTo(EventSendEnum.success)
        .findFirst();
    if (nes != null) {
      return true;
    }
    Get.find<WebsocketService>().writeNostrEvent(
        event: event,
        eventString: event.toJsonString(),
        roomId: room.id,
        toRelays: room.sendingRelays);
    logger.i('_messageReceiveCheck: ${event.id}, maxRetry: $maxRetry');
    return await _messageReceiveCheck(room, event, delay, maxRetry);
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
          decodedContent: toSaveMsg, sourceEvent: sourceEvent, isSystem: true);
      room = await RoomService().updateRoom(room);
      RoomService.getController(room.id)?.setRoom(room);
      return;
    }

    RoomService().receiveDM(room, event,
        sourceEvent: sourceEvent, decodedContent: km.msg);
  }

  _proccessHelloMessage(Room room, NostrEventModel event, KeychatMessage km,
      {String? msgKeyHash, NostrEventModel? sourceEvent}) async {
    if (km.name == null) {
      throw Exception('_proccessHelloMessage: km.name is null');
    }
    // update room member
    RoomMember? rm = await room.getMemberByIdPubkey(event.pubkey);
    rm ??=
        await room.createMember(event.pubkey, km.name!, UserStatusType.invited);

    // receive message
    await RoomService().receiveDM(room, event,
        sourceEvent: sourceEvent,
        km: km,
        msgKeyHash: msgKeyHash,
        isSystem: true,
        decodedContent: km.toString(),
        realMessage: km.msg);
  }

  Future<void> _initMlsDB(String dbpath) async {
    try {
      print("_initMlsDB");
      String path = './mls.sqlite';
      String groupId = "G11";
      String signalPath = '$dbpath$path';
      await rust_mls.initMlsDb(dbPath: signalPath, nostrId: "A");
      await rust_mls.initMlsDb(dbPath: signalPath, nostrId: "B");
      await rust_mls.initMlsDb(dbPath: signalPath, nostrId: "C");
      var bPk = await rust_mls.createKeyPackage(nostrId: "B");
      var cPk = await rust_mls.createKeyPackage(nostrId: "C");
      var groupJoinConfig =
          await rust_mls.createMlsGroup(nostrId: "A", groupId: groupId);
      print("groupJoinConfig is $groupJoinConfig");

      // A add B
      var welcome = await rust_mls.addMembers(
          nostrId: "A", groupId: groupId, keyPackages: [bPk].toList());
      // A commit
      await rust_mls.adderSelfCommit(nostrId: "A", groupId: groupId);
      // b join in the group
      await rust_mls.joinMlsGroup(
          nostrId: "B",
          groupId: groupId,
          welcome: welcome.$2,
          groupJoinConfig: groupJoinConfig);

      // A send msg to B
      var msg = await rust_mls.sendMsg(
          nostrId: "A", groupId: groupId, msg: "hello, B");
      // B decrypt A's msg
      var text = await rust_mls.decryptMsg(
          nostrId: "B", groupId: groupId, msg: msg.$1);
      print("B decryptMsg is $text");

      // A add C
      var welcome2 = await rust_mls.addMembers(
          nostrId: "A", groupId: groupId, keyPackages: [cPk].toList());
      // A commit
      await rust_mls.adderSelfCommit(nostrId: "A", groupId: groupId);
      // B commit
      await rust_mls.othersCommitNormal(
          nostrId: "B", groupId: groupId, queuedMsg: welcome2.$1);
      // C join in the group
      await rust_mls.joinMlsGroup(
          nostrId: "C",
          groupId: groupId,
          welcome: welcome2.$2,
          groupJoinConfig: groupJoinConfig);

      // A send msg to B C
      var msg2 = await rust_mls.sendMsg(
          nostrId: "A", groupId: groupId, msg: "hello, B C");
      // B decrypt A's msg
      var textB = await rust_mls.decryptMsg(
          nostrId: "B", groupId: groupId, msg: msg2.$1);
      print("B decryptMsg is $textB");
      // B decrypt A's msg
      var textC = await rust_mls.decryptMsg(
          nostrId: "C", groupId: groupId, msg: msg2.$1);
      print("C decryptMsg is $textC");
      var aHash =
          await rust_mls.getExportSecret(nostrId: "A", groupId: groupId);
      print("a_hash: $aHash");
      var bHash =
          await rust_mls.getExportSecret(nostrId: "B", groupId: groupId);
      print("b_hash: $bHash");
      var cHash =
          await rust_mls.getExportSecret(nostrId: "C", groupId: groupId);
      print("c_hash: $cHash");

      // get B leaf node
      var bLeafNode =
          await rust_mls.getLeadNodeIndex(nostrId: "B", groupId: groupId);

      // A remove B
      var queuedMsg = await rust_mls.removeMembers(
          nostrId: "A", groupId: groupId, members: [bLeafNode].toList());

      // B commit
      await rust_mls.othersCommitNormal(
          nostrId: "B", groupId: groupId, queuedMsg: queuedMsg);

      // C commit
      await rust_mls.othersCommitNormal(
          nostrId: "C", groupId: groupId, queuedMsg: queuedMsg);

      var aHash2 =
          await rust_mls.getExportSecret(nostrId: "A", groupId: groupId);
      print("a_hash2: $aHash2");

      var cHash2 =
          await rust_mls.getExportSecret(nostrId: "C", groupId: groupId);
      print("c_hash2: $cHash2");

      // admin update
      var queuedMsg2 =
          await rust_mls.selfUpdate(nostrId: "A", groupId: groupId);

      // C commit
      await rust_mls.othersCommitNormal(
          nostrId: "C", groupId: groupId, queuedMsg: queuedMsg2);

      var aHash3 =
          await rust_mls.getExportSecret(nostrId: "A", groupId: groupId);
      print("a_hash3: $aHash3");

      var cHash3 =
          await rust_mls.getExportSecret(nostrId: "C", groupId: groupId);
      print("c_hash3: $cHash3");
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  initDB(String dbpath) {
    MlsGroupService.dbPath = dbPath;
    initIdentities();
  }

  Future initIdentities([List<Identity>? identities]) async {
    identities ??= await IdentityService().getIdentityList();
    for (Identity identity in identities) {
      await rust_mls.initMlsDb(
          dbPath: '$dbPath${KeychatGlobal.mlsDBFile}',
          nostrId: identity.secp256k1PKHex);
      await _uploadPKMessage(identity);
    }
  }

  Future _uploadPKMessage(Identity identity) async {
    int exist = await Storage.getIntOrZero('mlspk:${identity.secp256k1PKHex}');
    if (exist == 0 ||
        DateTime.now().millisecondsSinceEpoch - exist > 86400000) {
      String mlkPK = await MlsGroupService.instance
          .createKeyMessages(identity.secp256k1PKHex);
      bool success = await updateMlsPK(identity, mlkPK);
      if (success) {
        await Storage.setInt('mlspk:${identity.secp256k1PKHex}',
            DateTime.now().millisecondsSinceEpoch);
      }
    }
  }

  Future updateMlsPK(Identity identity, String pk) async {
    // var rawEvent = await rust_nostr.setMetadata(
    //     senderKeys: await identity.getSecp256k1SKHex(), content: content);

    // await Get.find<WebsocketService>().sendMessage(rawEvent);
    //
    try {
      String sig = await rust_nostr.signSchnorr(
          senderKeys: await identity.getSecp256k1SKHex(), content: pk);
      var res = await Dio().post(KeychatGlobal.mlsPKServer,
          data: {'pubkey': identity.curve25519PkHex, 'pk': pk, 'sig': sig});
      logger.i('updateMlsPK success: ${res.data}');
      return true;
    } catch (e, s) {
      logger.e('updateMlsPK failed', error: e, stackTrace: s);
    }
    return false;
  }

  Future initDBByIdentity(Identity identity) async {
    await rust_mls.initMlsDb(
        dbPath: '${MlsGroupService.dbPath}${KeychatGlobal.mlsDBFile}',
        nostrId: identity.secp256k1PKHex);
  }

  Future<String> createKeyMessages(String pubkey) async {
    Uint8List pk = await rust_mls.createKeyPackage(nostrId: pubkey);
    return base64.encode(pk);
  }
}
