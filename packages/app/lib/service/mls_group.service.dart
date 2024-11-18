import 'dart:convert' show base64, jsonDecode, jsonEncode;

import 'package:app/constants.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/embedded/msg_reply.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/keychat/keychat_message.dart';
import 'package:app/models/keychat/room_profile.dart';
import 'package:app/models/message.dart';
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
import 'package:app/service/room.service.dart';
import 'package:app/service/storage.dart';
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

  Future<Room> acceptJoinGroup(
      Identity identity, Room room, String mlsInfo) async {
    logger.d('sendHelloMessage, version: ${room.version}');
    List<dynamic> info = jsonDecode(mlsInfo);
    List<int> groupJoinConfig = base64.decode(info[0]).toList();
    List<int> welcome = base64.decode(info[1]).toList();
    await rust_mls.joinMlsGroup(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        welcome: welcome,
        groupJoinConfig: groupJoinConfig);
    room = await replaceListenPubkey(room, identity.secp256k1PKHex);

    // update a new mls pk
    await MlsGroupService.instance.uploadPKByIdentity(room.getIdentity());
    KeychatMessage sm = KeychatMessage(
        c: MessageType.mls, type: KeyChatEventKinds.groupHelloMessage)
      ..name = identity.displayName
      ..msg = '${identity.displayName} joined group';

    await sendMessage(room, sm.toString(), realMessage: sm.msg);
    return room;
  }

  bool adminOnlyMiddleware(RoomMember from, int type) {
    const Set<int> adminTypes = {
      KeyChatEventKinds.groupAdminRemoveMembers,
      KeyChatEventKinds.inviteNewMember,
      KeyChatEventKinds.groupUpdateKeys,
      KeyChatEventKinds.groupDissolve,
      KeyChatEventKinds.groupChangeRoomName
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
    room = await replaceListenPubkey(room, identity.secp256k1PKHex);
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

  Future<Room> replaceListenPubkey(Room room, String secp256k1PKHex) async {
    Uint8List secret = await rust_mls.getExportSecret(
        nostrId: secp256k1PKHex, groupId: room.toMainPubkey);
    String newPubkey =
        await rust_nostr.generateSeedFromKey(seedKey: List<int>.from(secret));
    if (newPubkey == room.onetimekey) return room;
    return await room.replaceListenPubkey(
        newPubkey, room.version, room.onetimekey);
  }

  Future<String> createKeyMessages(String pubkey) async {
    Uint8List pk = await rust_mls.createKeyPackage(nostrId: pubkey);
    return base64.encode(pk);
  }

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
    RoomProfile roomProfile = await GroupService().inviteToJoinGroup(
        room, users,
        mlsWelcome: jsonEncode([mlsGroupInfo, welcomeMsg]));

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
        await _processGroupSelfExit(room, event, km, fromIdPubkey!);
        return;
      case KeyChatEventKinds.groupSelfLeaveConfirm:
        // self exit group
        if (fromIdPubkey == room.myIdPubkey) {
          return;
        }
        await room.removeMember(event.pubkey);
        RoomService.getController(room.id)?.resetMembers();
      case KeyChatEventKinds.groupDissolve:
        room.status = RoomStatus.dissolved;
        await RoomService().updateRoom(room);
        break;
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
        await proccessUpdateKeys(groupRoom, roomProfile);

        break;
      case KeyChatEventKinds.groupChangeRoomName:
        if (km.name != null) {
          room.name = km.name;
          await RoomService().updateRoomAndRefresh(room);
          Get.find<HomeController>().loadIdentityRoomList(room.id);
        }
        break;
      case KeyChatEventKinds.groupChangeNickname:
        if (km.name != null && fromIdPubkey != null) {
          await room.updateMemberName(fromIdPubkey, km.name!);
          RoomService.getController(room.id)?.resetMembers();
        }
        break;
      case KeyChatEventKinds.groupUpdateKeys:
        await memberProccessUpdateKey(room, km);
        break;
      default:
        return await RoomService().receiveDM(room, event,
            sourceEvent: sourceEvent,
            km: km,
            fromIdPubkey: fromIdPubkey,
            encryptType: MessageEncryptType.mls);
    }
    await RoomService().receiveDM(room, event,
        decodedContent: km.toString(),
        realMessage: km.msg,
        isSystem: true,
        fromIdPubkey: fromIdPubkey,
        encryptType: MessageEncryptType.mls);
  }

  Future<Room> proccessUpdateKeys(
      Room groupRoom, RoomProfile roomProfile) async {
    Identity identity = groupRoom.getIdentity();

    // clear signalid session and config
    await DBProvider.database.writeTxn(() async {
      // update room members
      await groupRoom.updateAllMemberTx(roomProfile.users);

      groupRoom.status = RoomStatus.enabled;
      groupRoom.version = roomProfile.updatedAt;
      groupRoom = await GroupTx().updateRoom(groupRoom);
    });
    groupRoom = await replaceListenPubkey(groupRoom, identity.secp256k1PKHex);

    RoomService.getController(groupRoom.id)?.setRoom(groupRoom).resetMembers();
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
          '[System] Admin remove ${names.length > 1 ? 'members' : 'member'}: ${names.join(',')}';

    await sendMessage(room, sm.toString(), realMessage: sm.msg);
    await rust_mls.selfCommit(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    room = await replaceListenPubkey(room, identity.secp256k1PKHex);
    RoomService.getController(room.id)?.setRoom(room).resetMembers();
  }

  Future adminUpdateKey(Room room) async {
    Identity identity = room.getIdentity();
    var queuedMsg = await rust_mls.selfUpdate(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    KeychatMessage sm = KeychatMessage(
        c: MessageType.mls, type: KeyChatEventKinds.groupUpdateKeys)
      ..name = base64.encode(queuedMsg)
      ..msg =
          '[System] Admin update the shared-key, all members\'s keys will be updated.';

    await sendMessage(room, sm.toString(), realMessage: sm.msg);
    await rust_mls.selfCommit(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    room = await replaceListenPubkey(room, identity.secp256k1PKHex);
  }

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
    if (room.onetimekey == null) {
      throw Exception('MLS Group\'s receiving pubkey is null');
    }
    var randomAccount = await rust_nostr.generateSimple();
    var smr = await NostrAPI().sendNip4Message(
        room.onetimekey!, base64.encode(enctypted.$1),
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
    RoomUtil.messageReceiveCheck(
            room, smr.events[0], const Duration(milliseconds: 500), 3)
        .then((res) {
      if (res == false) {
        logger.e('MLS Message Send failed: $message');
      }
    });
    return smr;
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

    if (toRemoveIdPubkeys.contains(identity.secp256k1PKHex)) {
      room.status = RoomStatus.removedFromGroup;
      RoomService().receiveDM(room, event,
          decodedContent: '🤖 You have been removed by admin.',
          isSystem: true,
          fromIdPubkey: fromIdPubkey,
          encryptType: MessageEncryptType.mls);
      await RoomService().updateChatRoomPage(room);
      return;
    }
    for (String memberIdPubkey in toRemoveIdPubkeys) {
      await room.setMemberDisableByPubkey(memberIdPubkey);
    }

    await rust_mls.othersCommitNormal(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        queuedMsg: welcome);
    room = await replaceListenPubkey(room, identity.secp256k1PKHex);
    await RoomService().receiveDM(room, event,
        decodedContent: km.toString(),
        realMessage: km.msg,
        encryptType: MessageEncryptType.mls,
        fromIdPubkey: fromIdPubkey);
    await RoomService.getController(room.id)?.setRoom(room).resetMembers();
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

    await RoomService().receiveDM(room, event,
        decodedContent: km.toString(),
        realMessage: km.msg,
        isSystem: true,
        fromIdPubkey: fromIdPubkey,
        encryptType: MessageEncryptType.mls);
    RoomMember? adminMember = await room.getAdmin();
    if (room.myIdPubkey != adminMember?.idPubkey) return;
    // admin task
    RoomMember? rm = await room.getMemberByIdPubkey(fromIdPubkey);
    if (rm == null) return;
    await removeMembers(room, [rm]);

    // var commitData = await rust_mls.adminProposalLeave(
    //     nostrId: room.myIdPubkey, groupId: room.toMainPubkey);

    // String toSendMessage = KeychatMessage.getFeatureMessageString(
    //     MessageType.mls,
    //     room,
    //     '[Commit]: ${km.msg}',
    //     KeyChatEventKinds.groupSelfLeaveConfirm,
    //     data: base64.encode(commitData));
    // var smr = await MlsGroupService.instance
    //     .sendMessage(room, toSendMessage, realMessage: '[Commit]: ${km.msg}');
    // await RoomUtil.messageReceiveCheck(
    //         room, smr.events[0], const Duration(milliseconds: 300), 3)
    //     .then((res) async {
    //   if (res) {
    //     await rust_mls.adminCommitLeave(
    //         nostrId: room.myIdPubkey, groupId: room.toMainPubkey);
    //     await room.removeMember(fromIdPubkey);
    //     RoomService.getController(room.id)?.resetMembers();
    //   }
    // });
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

  Future memberProccessUpdateKey(Room room, KeychatMessage km) async {
    Uint8List welcome = base64.decode(km.name!);
    await rust_mls.othersCommitNormal(
        nostrId: room.myIdPubkey,
        groupId: room.toMainPubkey,
        queuedMsg: welcome);
    await replaceListenPubkey(room, room.myIdPubkey);
  }
}
