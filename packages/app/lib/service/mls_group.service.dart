// KDF group is a shared key group
// Use signal protocol to encrypt message
// Every Member in the group has the same signal id key pair, it's a virtual Member in group
// Every member send message to virtual member

import 'dart:convert' show base64, jsonDecode, jsonEncode;

import 'package:app/constants.dart';
import 'package:app/global.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/embedded/msg_reply.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/keychat/keychat_message.dart';
import 'package:app/models/keychat/room_profile.dart';
import 'package:app/models/message.dart';
import 'package:app/models/mykey.dart';
import 'package:app/models/room.dart';
import 'package:app/models/room_member.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/service/chat.service.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/group_tx.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_mls.dart' as rust_mls;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class MlsGroupService extends BaseChatService {
  static MlsGroupService? _instance;
  static String? dbPath;
  static MlsGroupService get instance => _instance ??= MlsGroupService._();
  // Avoid self instance
  MlsGroupService._();

  Future acceptJoinGroup(Identity identity, Room room, String mlsInfo) async {
    logger.d('sendHelloMessage, version: ${room.version}');
    List<dynamic> info = jsonDecode(mlsInfo);
    List<int> groupJoinConfig = base64.decode(info[0]).toList();
    List<int> welcome = base64.decode(info[1]).toList();
    await rust_mls.joinMlsGroup(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        welcome: welcome,
        groupJoinConfig: groupJoinConfig);

    // update a new mls pk
    await MlsGroupService.instance.uploadPKByIdentity(room.getIdentity());
    KeychatMessage sm = KeychatMessage(
        c: MessageType.mls, type: KeyChatEventKinds.groupHelloMessage)
      ..name = identity.displayName
      ..msg = '${identity.displayName} joined group';

    await MlsGroupService.instance
        .sendMessage(room, sm.toString(), realMessage: sm.msg);
  }

  bool adminOnlyMiddleware(RoomMember from, int type) {
    const Set<int> adminTypes = {
      KeyChatEventKinds.groupAdminRemoveMembers,
      KeyChatEventKinds.inviteNewMember,
      KeyChatEventKinds.groupUpdateKeys,
      KeyChatEventKinds.groupDissolve
    };
    if (adminTypes.contains(type)) {
      if (from.isAdmin) return true;
      throw Exception('Permission denied');
    }
    return true;
  }

  Future appendMessageOrCreate(String error, Room room, String content,
      NostrEventModel nostrEvent) async {
    Message? message = await DBProvider.database.messages
        .filter()
        .msgidEqualTo(nostrEvent.id)
        .findFirst();
    if (message == null) {
      await RoomService().receiveDM(room, nostrEvent, decodedContent: '''
$error

track: $content''');
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
  Future<Room> createGroup(String groupName, Identity identity,
      List<Map<String, dynamic>> toUsers) async {
    Room room =
        await GroupService().createGroup(groupName, identity, GroupType.mls);
    var groupJoinConfig = await rust_mls.createMlsGroup(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    List<Uint8List> keyPackages = [];
    for (var user in toUsers) {
      String pk = user['mlsPK'];
      keyPackages.add(base64.decode(pk));
    }
    if (keyPackages.isEmpty) {
      throw Exception('keyPackages is empty');
    }
    var welcome = await rust_mls.addMembers(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        keyPackages: keyPackages);
    await rust_mls.selfCommit(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    String welcomeMsg = base64.encode(welcome.$2);
    String mlsGroupInfo = base64.encode(groupJoinConfig);

    Map<String, String> users = {};
    for (var user in toUsers) {
      users[user['pubkey']] = user['name'];
    }

    await GroupService().inviteToJoinGroup(room, users,
        mlsWelcome: jsonEncode([mlsGroupInfo, welcomeMsg]));

    return room;
  }

  Future<String> createKeyMessages(String pubkey) async {
    Uint8List pk = await rust_mls.createKeyPackage(nostrId: pubkey);
    return base64.encode(pk);
  }

  // shared key receive message then decrypt message
  // message struct: nip4 wrap signal
  Future decryptMessage(Room room, NostrEventModel nostrEvent,
      {required Function(String) failedCallback}) async {
    Identity identity = room.getIdentity();
    List<int> decoded = base64.decode(nostrEvent.content).toList();
    var exist = await MessageService().getMessageByEventId(nostrEvent.id);
    if (exist != null) {
      logger.d('Event may sent by me: ${nostrEvent.id}');
      return;
    }

    (String, String)? decryptedMsg;
    try {
      decryptedMsg = await rust_mls.decryptMsg(
          nostrId: identity.secp256k1PKHex,
          groupId: room.toMainPubkey,
          msg: decoded);
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      failedCallback(msg);
      logger.e(msg, error: e, stackTrace: s);
      await appendMessageOrCreate(msg, room, 'mls decrypt failed', nostrEvent);
      return;
    }
    String fromIdPubkey = decryptedMsg.$2;
    String decodeString = decryptedMsg.$1;
    // try km message
    KeychatMessage? km;
    try {
      Map<String, dynamic>? decodedContentMap = jsonDecode(decodeString);
      km = KeychatMessage.fromJson(decodedContentMap!);
      // ignore: empty_catches
    } catch (e) {}
    if (km == null) {
      await RoomService().receiveDM(room, nostrEvent,
          decodedContent: decodeString,
          fromIdPubkey: fromIdPubkey,
          encryptType: MessageEncryptType.mls);
      return;
    }
    try {
      RoomMember? fromMember = await room.getMemberByNostrPubkey(fromIdPubkey);

      if (fromMember == null) {
        String msg = 'roomMember is null';
        failedCallback(room.getDebugInfo(msg));
        throw Exception('roomMember is null');
      }
      adminOnlyMiddleware(fromMember, km.type);
      await km.service.proccessMessage(
          room: room, km: km, event: nostrEvent, fromIdPubkey: fromIdPubkey);
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      logger.e('decryptPreKeyMessage error: $msg', error: e, stackTrace: s);
      await appendMessageOrCreate(
          msg, room, 'mls km processMessage', nostrEvent);
    }
  }

  Future<Room> getGroupRoomByIdRoom(
      Room idRoom, RoomProfile roomProfile) async {
    if (idRoom.type == RoomType.group) return idRoom;

    String pubkey = roomProfile.oldToRoomPubKey ?? roomProfile.pubkey;
    var group = await DBProvider.database.rooms
        .filter()
        .toMainPubkeyEqualTo(pubkey)
        .identityIdEqualTo(idRoom.identityId)
        .findFirst();
    if (group == null) throw Exception('GroupRoom not found');
    return group;
  }

  Future<String?> getPK(String pubkey) async {
    try {
      var res = await Dio().get('${KeychatGlobal.mlsPKServer}?pubkey=$pubkey');
      logger.d(res);
      if (res.data['data'].length == 0) return null;
      return res.data['data'];
    } catch (e, s) {
      logger.e('getPK failed', error: e, stackTrace: s);
    }
    return null;
  }

  initDB(String path) {
    dbPath = path;
    initIdentities();
  }

  Future initIdentities([List<Identity>? identities]) async {
    if (dbPath == null) {
      throw Exception('MLS dbPath is null');
    }
    identities ??= await IdentityService().getIdentityList();
    for (Identity identity in identities) {
      await rust_mls.initMlsDb(
          dbPath: '$dbPath${KeychatGlobal.mlsDBFile}',
          nostrId: identity.secp256k1PKHex);
      logger.i('MLS init success: ${identity.secp256k1PKHex}');
      await _uploadPKMessage(identity);
    }
  }

  Future inviteToJoinGroup(Room room, List<Map<String, dynamic>> toUsers,
      [String? sender]) async {
    Identity identity = room.getIdentity();
    Map<String, String> users = {};
    List<Uint8List> keyPackages = [];
    for (var user in toUsers) {
      users[user['pubkey']] = user['name'];
      String? pk = user['mlsPK'];
      if (pk != null) {
        keyPackages.add(base64.decode(pk));
      }
    }
    if (keyPackages.isEmpty) {
      throw Exception('keyPackages is empty');
    }

    var welcome = await rust_mls.addMembers(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        keyPackages: keyPackages);

    String welcomeMsg = base64.encode(welcome.$2);
    Uint8List groupJoinConfig = await rust_mls.getGroupConfig(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    String mlsGroupInfo = base64.encode(groupJoinConfig);
    // send message to invited users
    Mykey mykey = await GroupTx().createMykey(room.identityId, room.id);
    RoomProfile roomProfile = await GroupService().inviteToJoinGroup(
        room, users,
        mlsWelcome: jsonEncode([mlsGroupInfo, welcomeMsg]), mykey: mykey);

    // send message to group
    roomProfile.ext = base64.encode(welcome.$1);
    String names = users.values.toList().join(',');

    KeychatMessage sm = KeychatMessage(
        c: MessageType.mls, type: KeyChatEventKinds.inviteNewMember)
      ..name = roomProfile.toString()
      ..msg =
          '''${sender == null ? 'Invite' : '[$sender] invite'} [${names.isNotEmpty ? names : users.keys.join(',').toString()}] to join group.''';
    await MlsGroupService.instance
        .sendMessage(room, sm.toString(), realMessage: sm.msg);
    await rust_mls.selfCommit(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    // self update keys
    await proccessUpdateKeys(room, roomProfile);
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
      case KeyChatEventKinds.groupHelloMessage:
        await _proccessHelloMessage(room, event, km,
            msgKeyHash: msgKeyHash, fromIdPubkey: fromIdPubkey!);
        return;
      case KeyChatEventKinds.groupSelfLeave:
        await _processGroupSelfExit(room, event, km, event.pubkey);
        return;
      case KeyChatEventKinds.groupSelfLeaveConfirm:
        // self exit group
        if (fromIdPubkey == room.myIdPubkey) {
          return;
        }
        await room.removeMember(event.pubkey);
        RoomService.getController(room.id)?.resetMembers();
        await RoomService().receiveDM(room, event,
            realMessage: km.msg,
            isSystem: true,
            fromIdPubkey: fromIdPubkey,
            encryptType: MessageEncryptType.mls);
        return;
      case KeyChatEventKinds.groupDissolve:
        room.status = RoomStatus.dissolved;
        await RoomService().updateRoom(room);
        await RoomService().receiveDM(room, event,
            sourceEvent: sourceEvent,
            decodedContent: km.msg!,
            isSystem: true,
            fromIdPubkey: fromIdPubkey,
            encryptType: MessageEncryptType.mls);
      case KeyChatEventKinds.groupAdminRemoveMembers:
        await _proccessAdminRemoveMembers(room, event, km, fromIdPubkey!);
        return;
      case KeyChatEventKinds.inviteNewMember:
        RoomProfile roomProfile = RoomProfile.fromJson(jsonDecode(km.name!));
        Room groupRoom = await getGroupRoomByIdRoom(room, roomProfile);
        if (roomProfile.updatedAt < groupRoom.version) {
          throw Exception('The invitation has expired');
        }
        if (roomProfile.ext == null) {
          throw Exception('roomProfile is null');
        }
        Identity identity = groupRoom.getIdentity();
        await rust_mls.othersCommitNormal(
            nostrId: identity.secp256k1PKHex,
            groupId: groupRoom.toMainPubkey,
            queuedMsg: base64.decode(roomProfile.ext!));

        await RoomService().receiveDM(groupRoom, event,
            sourceEvent: sourceEvent,
            decodedContent: km.msg!,
            isSystem: true,
            fromIdPubkey: fromIdPubkey,
            encryptType: MessageEncryptType.mls);
        await proccessUpdateKeys(groupRoom, roomProfile);

        return;
      default:
        await RoomService().receiveDM(room, event,
            sourceEvent: sourceEvent,
            km: km,
            fromIdPubkey: fromIdPubkey,
            encryptType: MessageEncryptType.mls);
    }
  }

  Future<Room> proccessUpdateKeys(
      Room groupRoom, RoomProfile roomProfile) async {
    var keychain = rust_nostr.Secp256k1Account(
        prikey: roomProfile.prikey!,
        pubkey: roomProfile.pubkey,
        pubkeyBech32: '',
        prikeyBech32: '');

    Mykey toDeleteMykey = groupRoom.mykey.value!;
    Identity identity = groupRoom.getIdentity();

    // clear signalid session and config
    await DBProvider.database.writeTxn(() async {
      // update room members
      await groupRoom.updateAllMemberTx(roomProfile.users);
      // delete old mykey and import new one

      Mykey mykey =
          await GroupTx().importMykeyTx(identity.id, keychain, groupRoom.id);
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
    });
    RoomService.getController(groupRoom.id)?.setRoom(groupRoom).resetMembers();

    await Get.find<WebsocketService>().listenPubkey([keychain.pubkey],
        since: DateTime.fromMillisecondsSinceEpoch(
            roomProfile.updatedAt - 10 * 1000));
    await Get.find<WebsocketService>().listenPubkeyNip17([keychain.pubkey],
        since: DateTime.fromMillisecondsSinceEpoch(
            roomProfile.updatedAt - 10 * 1000));
    NotifyService.addPubkeys([keychain.pubkey]);

    return groupRoom;
  }

  Future removeMembers(Room room, List<RoomMember> list) async {
    Identity identity = room.getIdentity();
    List<String> idPubkeys = [];
    List<String> names = [];
    List<Uint8List> bLeafNodes = [];
    for (RoomMember rm in list) {
      await room.setMemberDisable(rm);
      idPubkeys.add(rm.idPubkey);
      names.add(rm.name);
      var bLeafNode = await rust_mls.getLeadNodeIndex(
          nostrIdAdmin: identity.secp256k1PKHex,
          nostrIdCommon: rm.idPubkey,
          groupId: room.toMainPubkey);
      bLeafNodes.add(bLeafNode);
    }
    var queuedMsg = await rust_mls.removeMembers(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        members: bLeafNodes);
    KeychatMessage sm = KeychatMessage(
        c: MessageType.mls, type: KeyChatEventKinds.groupAdminRemoveMembers)
      ..name = jsonEncode([idPubkeys, base64.encode(queuedMsg)])
      ..msg =
          'Admin remove ${names.length > 1 ? 'members' : 'member'}: ${names.join(',')}';

    await sendMessage(room, sm.toString(), realMessage: sm.msg);
    await rust_mls.selfCommit(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    RoomService.getController(room.id)?.resetMembers();
  }

  // nip4 wrap signal message
  @override
  Future<SendMessageResponse> sendMessage(Room room, String message,
      {MessageMediaType? mediaType,
      bool save = true,
      MsgReply? reply,
      String? realMessage}) async {
    if (reply != null) {
      message = KeychatMessage.getTextMessage(MessageType.mls, message, reply);
    }
    Identity identity = room.getIdentity();
    var enctypted = await rust_mls.sendMsg(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        msg: message);

    var randomAccount = await rust_nostr.generateSimple();
    Mykey mykey = room.mykey.value!;
    return await NostrAPI().sendNip4Message(
        mykey.pubkey, base64.encode(enctypted.$1),
        prikey: randomAccount.prikey,
        from: randomAccount.pubkey,
        room: room,
        encryptType: MessageEncryptType.mls,
        save: save,
        mediaType: mediaType,
        sourceContent: message,
        realMessage: realMessage,
        reply: reply,
        isSignalMessage: true);
  }

  Future updateMlsPK(Identity identity, String pk) async {
    try {
      String sig = await rust_nostr.signSchnorr(
          senderKeys: await identity.getSecp256k1SKHex(), content: pk);
      var res = await Dio().post(KeychatGlobal.mlsPKServer,
          data: {'pubkey': identity.secp256k1PKHex, 'pk': pk, 'sig': sig});
      logger.i('updateMlsPK success: ${res.data}');
      return true;
    } catch (e, s) {
      logger.e('updateMlsPK failed', error: e, stackTrace: s);
    }
    return false;
  }

  Future uploadPKByIdentity(Identity identity) async {
    String mlkPK = await MlsGroupService.instance
        .createKeyMessages(identity.secp256k1PKHex);
    bool success = await updateMlsPK(identity, mlkPK);
    if (success) {
      await Storage.setInt('mlspk:${identity.secp256k1PKHex}',
          DateTime.now().millisecondsSinceEpoch);
    }
  }

  // If the deleted person includes himself, mark the room as kicked.
  // If it is not included, it will not be processed and the message will be displayed directly.
  Future _proccessAdminRemoveMembers(Room room, NostrEventModel event,
      KeychatMessage km, String fromIdPubkey) async {
    Identity identity = room.getIdentity();
    List list = jsonDecode(km.name!);
    List toRemoveIdPubkeys = list[0];
    Uint8List welcome = base64.decode(list[1]);

    String toSaveMsg = km.msg!;
    if (toRemoveIdPubkeys.contains(identity.secp256k1PKHex)) {
      room.status = RoomStatus.removedFromGroup;
      await RoomService().updateRoom(room);
      room.status = RoomStatus.removedFromGroup;
      toSaveMsg = '🤖 You have been removed by admin.';
      RoomService().receiveDM(room, event,
          decodedContent: toSaveMsg,
          isSystem: true,
          fromIdPubkey: fromIdPubkey,
          encryptType: MessageEncryptType.mls);
      room = await RoomService().updateRoom(room);
      RoomService.getController(room.id)?.setRoom(room);
      return;
    }
    for (String memberIdPubkey in toRemoveIdPubkeys) {
      await room.setMemberDisableByPubkey(memberIdPubkey);
    }

    await rust_mls.othersCommitNormal(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        queuedMsg: welcome);

    await RoomService().receiveDM(room, event,
        decodedContent: km.toString(),
        realMessage: km.msg,
        encryptType: MessageEncryptType.mls,
        fromIdPubkey: fromIdPubkey);
    await RoomService.getController(room.id)?.resetMembers();
  }

  _proccessHelloMessage(Room room, NostrEventModel event, KeychatMessage km,
      {String? msgKeyHash, required String fromIdPubkey}) async {
    if (km.name == null) {
      throw Exception('_proccessHelloMessage: km.name is null');
    }
    // update room member
    RoomMember? rm = await room.getMemberByIdPubkey(fromIdPubkey);
    rm ??=
        await room.createMember(fromIdPubkey, km.name!, UserStatusType.invited);

    await room.setMemberInvited(rm!, km.name!);

    // receive message
    await RoomService().receiveDM(room, event,
        km: km,
        msgKeyHash: msgKeyHash,
        isSystem: true,
        decodedContent: km.toString(),
        fromIdPubkey: fromIdPubkey,
        realMessage: km.msg,
        encryptType: MessageEncryptType.mls);
  }

  Future _processGroupSelfExit(Room room, NostrEventModel event,
      KeychatMessage km, String fromIdPubkey) async {
    // self exit group
    if (fromIdPubkey == room.myIdPubkey) {
      return;
    }

    await rust_mls.othersProposalLeave(
        nostrId: room.myIdPubkey,
        groupId: room.toMainPubkey,
        queuedMsg: base64.decode(km.data!));
    await RoomService().receiveDM(room, event,
        decodedContent: km.toString(),
        realMessage: '[Proposal]: ${km.msg}',
        isSystem: true,
        fromIdPubkey: fromIdPubkey,
        encryptType: MessageEncryptType.mls);
    RoomMember? meMember = await room.getAdmin();
    if (room.myIdPubkey != meMember?.idPubkey) return;
    var commitData = await rust_mls.adminProposalLeave(
        nostrId: room.myIdPubkey, groupId: room.toMainPubkey);

    String toSendMessage = KeychatMessage.getFeatureMessageString(
        MessageType.mls,
        room,
        '[Commit]: ${km.msg}',
        KeyChatEventKinds.groupSelfLeaveConfirm,
        data: base64.encode(commitData));
    var smr = await MlsGroupService.instance
        .sendMessage(room, toSendMessage, realMessage: '[Commit]: ${km.msg}');
    await RoomUtil.messageReceiveCheck(
            room, smr.events[0], const Duration(milliseconds: 300), 3)
        .then((res) async {
      if (res) {
        await rust_mls.adminCommitLeave(
            nostrId: room.myIdPubkey, groupId: room.toMainPubkey);
        await room.removeMember(fromIdPubkey);
        RoomService.getController(room.id)?.resetMembers();
      }
    });
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
}
