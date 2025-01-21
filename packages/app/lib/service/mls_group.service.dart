import 'dart:convert' show base64, jsonDecode, jsonEncode;

import 'package:app/constants.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/embedded/msg_reply.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/keychat/group_invitation_model.dart';
import 'package:app/models/keychat/group_invitation_request_model.dart';
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
import 'package:flutter/foundation.dart' show Uint8List;
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
      KeyChatEventKinds.groupDissolve,
      KeyChatEventKinds.groupChangeRoomName
    };
    if (adminTypes.contains(type)) {
      if (from.isAdmin) return true;
      throw Exception('Permission denied');
    }
    return true;
  }

  Future appendMessageOrCreate(
      String error, Room room, String content, NostrEventModel nostrEvent,
      {String? fromIdPubkey}) async {
    Message? message = await DBProvider.database.messages
        .filter()
        .msgidEqualTo(nostrEvent.id)
        .findFirst();
    if (message == null) {
      await RoomService.instance.receiveDM(room, nostrEvent,
          decodedContent: '''
$error

track: $content''',
          fromIdPubkey: fromIdPubkey);
      return;
    }
    message.content = '''${message.content}

$error ''';
    await MessageService.instance.updateMessageAndRefresh(message);
  }

  Future<Room> createGroup(String groupName, Identity identity,
      List<Map<String, dynamic>> toUsers) async {
    Room room = await GroupService.instance
        .createGroup(groupName, identity, GroupType.mls);
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

    await GroupService.instance.inviteToJoinGroup(room, users,
        mlsWelcome: jsonEncode([mlsGroupInfo, welcomeMsg]));

    return room;
  }

  Future<String> createKeyMessages(String pubkey) async {
    Uint8List pk = await rust_mls.createKeyPackage(nostrId: pubkey);
    return base64.encode(pk);
  }

  Future decryptMessage(Room room, NostrEventModel nostrEvent,
      {required Function(String) failedCallback}) async {
    Identity identity = room.getIdentity();
    List<int> decoded = base64.decode(nostrEvent.content).toList();
    var exist =
        await MessageService.instance.getMessageByEventId(nostrEvent.id);
    if (exist != null) {
      logger.d('Event may sent by me: ${nostrEvent.id}');
      return;
    }

    (String, String, Uint8List?)? decryptedMsg;
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
    String? msgKeyHash =
        decryptedMsg.$3 != null ? base64.encode(decryptedMsg.$3!) : null;
    // try km message
    KeychatMessage? km;
    try {
      Map<String, dynamic>? decodedContentMap = jsonDecode(decodeString);
      km = KeychatMessage.fromJson(decodedContentMap!);
      // ignore: empty_catches
    } catch (e) {}
    if (km == null) {
      await RoomService.instance.receiveDM(room, nostrEvent,
          decodedContent: decodeString,
          fromIdPubkey: fromIdPubkey,
          encryptType: MessageEncryptType.mls,
          msgKeyHash: msgKeyHash);
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
          room: room,
          km: km,
          event: nostrEvent,
          fromIdPubkey: fromIdPubkey,
          msgKeyHash: msgKeyHash);
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      logger.e('decryptPreKeyMessage error: $msg', error: e, stackTrace: s);
      await appendMessageOrCreate(
          msg, room, 'mls km processMessage', nostrEvent,
          fromIdPubkey: fromIdPubkey);
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

  Future<Map> getPKs(List<String> pubkeys) async {
    try {
      var res = await Dio().post('${KeychatGlobal.mlsPKServer}batch',
          data: {'pubkeys': pubkeys});
      return res.data['data'] ?? {};
    } catch (e, s) {
      logger.e('getPK failed', error: e, stackTrace: s);
    }
    return {};
  }

  Future<String> getShareInfo(Room room) async {
    var map = {
      'name': room.name,
      'pubkey': room.toMainPubkey,
      'type': room.groupType.name,
      'myPubkey': room.myIdPubkey,
      'time': DateTime.now().millisecondsSinceEpoch
    };

    String contentToSign =
        jsonEncode([map['pubkey'], map['type'], map['myPubkey'], map['time']]);
    String signature = await rust_nostr.signSchnorr(
        senderKeys: await room.getIdentity().getSecp256k1SKHex(),
        content: contentToSign);
    map['signature'] = signature;

    return jsonEncode(map);
  }

  Future initDB(String path) async {
    dbPath = path;
    await initIdentities();
  }

  Future initIdentities([List<Identity>? identities]) async {
    if (dbPath == null) {
      throw Exception('MLS dbPath is null');
    }
    identities ??= await IdentityService.instance.getIdentityList();
    await Future.wait(identities.map((identity) async {
      await rust_mls.initMlsDb(
          dbPath: '$dbPath${KeychatGlobal.mlsDBFile}',
          nostrId: identity.secp256k1PKHex);
      logger.i('MLS init for identity: ${identity.secp256k1PKHex}');
      _uploadPKMessage(identity);
    }));
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
    RoomProfile roomProfile = await GroupService.instance.inviteToJoinGroup(
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
    await sendMessage(room, sm.toString(), realMessage: sm.msg);
    await rust_mls.selfCommit(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    // self update keys
    await proccessUpdateKeys(room, roomProfile);
  }

  Future memberProccessUpdateKey(Room room, KeychatMessage km) async {
    Uint8List welcome = base64.decode(km.name!);
    await rust_mls.othersCommitNormal(
        nostrId: room.myIdPubkey,
        groupId: room.toMainPubkey,
        queuedMsg: welcome);
    try {
      await replaceListenPubkey(room, room.myIdPubkey);
    } catch (e) {
      logger.e(e.toString(), error: e);
    }
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
    MessageMediaType? mediaType;
    String? requestId;
    switch (km.type) {
      case KeyChatEventKinds.groupHelloMessage:
        await _proccessHelloMessage(room, event, km,
            msgKeyHash: msgKeyHash, fromIdPubkey: fromIdPubkey!);
        return;
      case KeyChatEventKinds.groupSelfLeave:
        await _processGroupSelfExit(room, event, km, fromIdPubkey!,
            msgKeyHash: msgKeyHash);
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
        await RoomService.instance.updateRoom(room);
        break;
      case KeyChatEventKinds.groupAdminRemoveMembers:
        await _proccessAdminRemoveMembers(room, event, km, fromIdPubkey!,
            msgKeyHash: msgKeyHash);
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
        if (groupRoom.status == RoomStatus.removedFromGroup) {}
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
          await RoomService.instance.updateRoomAndRefresh(room);
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
      case KeyChatEventKinds.groupInvitationInfo:
        mediaType = MessageMediaType.groupInvitationInfo;
        break;
      case KeyChatEventKinds.groupInvitationRequesting:
        mediaType = MessageMediaType.groupInvitationRequesting;
        GroupInvitationRequestModel gir =
            GroupInvitationRequestModel.fromJson(jsonDecode(km.name!));
        requestId = gir.roomPubkey;

        break;
      default:
        return await RoomService.instance.receiveDM(room, event,
            sourceEvent: sourceEvent,
            km: km,
            fromIdPubkey: fromIdPubkey,
            encryptType: MessageEncryptType.mls,
            msgKeyHash: msgKeyHash);
    }
    await RoomService.instance.receiveDM(room, event,
        decodedContent: km.toString(),
        realMessage: km.msg,
        isSystem: true,
        fromIdPubkey: fromIdPubkey,
        encryptType: MessageEncryptType.mls,
        msgKeyHash: msgKeyHash,
        mediaType: mediaType,
        requestId: requestId);
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
      groupRoom = await GroupTx.instance.updateRoom(groupRoom);
    });
    groupRoom = await replaceListenPubkey(groupRoom, identity.secp256k1PKHex);

    await RoomService.getController(groupRoom.id)
        ?.setRoom(groupRoom)
        .resetMembers();
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

  Future<Room> replaceListenPubkey(Room room, String secp256k1PKHex) async {
    Uint8List secret = await rust_mls.getExportSecret(
        nostrId: secp256k1PKHex, groupId: room.toMainPubkey);
    String newPubkey =
        await rust_nostr.generateSeedFromKey(seedKey: List<int>.from(secret));
    if (newPubkey == room.onetimekey) return room;
    return await room.replaceListenPubkey(
        newPubkey, room.version, room.onetimekey);
  }

  Future selfUpdateKey(Room room) async {
    String key = 'mlsUpdate:${room.toMainPubkey}';
    int lastUpdate = await Storage.getIntOrZero(key);
    if (DateTime.now().millisecondsSinceEpoch - lastUpdate < 86400000) {
      throw Exception('You can only update your key once per day.');
    }
    await Storage.setInt(key, DateTime.now().millisecondsSinceEpoch);
    Identity identity = room.getIdentity();
    var queuedMsg = await rust_mls.selfUpdate(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    KeychatMessage sm = KeychatMessage(
        c: MessageType.mls, type: KeyChatEventKinds.groupUpdateKeys)
      ..name = base64.encode(queuedMsg)
      ..msg = '[System] Update my mls-group-key.';

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
    if (room.onetimekey == null) {
      throw Exception('Receiving pubkey is null');
    }
    Identity identity = room.getIdentity();
    var enctypted = await rust_mls.sendMsg(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        msg: message);

    // refresh onetime key
    if (realMessage != null) {
      room = await RoomService.instance.getRoomByIdOrFail(room.id);
    }
    var randomAccount = await rust_nostr.generateSimple();
    var smr = await NostrAPI.instance.sendNip4Message(
        room.onetimekey!, base64.encode(enctypted.$1),
        prikey: randomAccount.prikey,
        from: randomAccount.pubkey,
        room: room,
        encryptType: MessageEncryptType.mls,
        msgKeyHash: enctypted.$2 == null ? null : base64.encode(enctypted.$2!),
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

  Future shareToFriends(
      Room room, List<Room> toUsers, String realMessage) async {
    GroupInvitationModel gim = GroupInvitationModel(
        name: room.name ?? room.toMainPubkey,
        pubkey: room.toMainPubkey,
        sender: room.myIdPubkey,
        time: DateTime.now().millisecondsSinceEpoch,
        sig: '');
    KeychatMessage sm = KeychatMessage(
        c: MessageType.mls, type: KeyChatEventKinds.groupInvitationInfo)
      ..name = gim.toString()
      ..msg = realMessage;
    await RoomService.instance.sendMessageToMultiRooms(
        message: sm.toString(),
        realMessage: sm.msg!,
        rooms: toUsers,
        identity: room.getIdentity(),
        mediaType: MessageMediaType.groupInvitationInfo);
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
    String mlkPK = await createKeyMessages(identity.secp256k1PKHex);
    bool success = await updateMlsPK(identity, mlkPK);
    if (success) {
      await Storage.setInt('mlspk:${identity.secp256k1PKHex}',
          DateTime.now().millisecondsSinceEpoch);
    }
  }

  // If the deleted person includes himself, mark the room as kicked.
  // If it is not included, it will not be processed and the message will be displayed directly.
  Future _proccessAdminRemoveMembers(
      Room room, NostrEventModel event, KeychatMessage km, String fromIdPubkey,
      {String? msgKeyHash}) async {
    Identity identity = room.getIdentity();
    List list = jsonDecode(km.name!);
    List toRemoveIdPubkeys = list[0];
    Uint8List welcome = base64.decode(list[1]);

    if (toRemoveIdPubkeys.contains(identity.secp256k1PKHex)) {
      room.status = RoomStatus.removedFromGroup;
      await RoomService.instance.receiveDM(room, event,
          decodedContent: '[System] You have been removed by admin.',
          isSystem: true,
          fromIdPubkey: fromIdPubkey,
          encryptType: MessageEncryptType.mls,
          msgKeyHash: msgKeyHash);
      await RoomService.instance.updateRoomAndRefresh(room);
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
    await RoomService.instance.receiveDM(room, event,
        decodedContent: km.toString(),
        realMessage: km.msg,
        encryptType: MessageEncryptType.mls,
        fromIdPubkey: fromIdPubkey,
        msgKeyHash: msgKeyHash);
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
    await RoomService.instance.receiveDM(room, event,
        km: km,
        msgKeyHash: msgKeyHash,
        isSystem: true,
        decodedContent: km.toString(),
        fromIdPubkey: fromIdPubkey,
        realMessage: km.msg,
        encryptType: MessageEncryptType.mls);
  }

  Future _processGroupSelfExit(
      Room room, NostrEventModel event, KeychatMessage km, String fromIdPubkey,
      {String? msgKeyHash}) async {
    // self exit group
    if (fromIdPubkey == room.myIdPubkey) {
      return;
    }

    await RoomService.instance.receiveDM(room, event,
        decodedContent: km.toString(),
        realMessage: km.msg,
        isSystem: true,
        fromIdPubkey: fromIdPubkey,
        encryptType: MessageEncryptType.mls,
        msgKeyHash: msgKeyHash);
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

  Future sendJoinGroupRequest(
      GroupInvitationModel gim, Identity identity) async {
    if (gim.pubkey == identity.secp256k1PKHex) {
      throw Exception('You are already in this group');
    }
    String mlkPK = await createKeyMessages(identity.secp256k1PKHex);
    GroupInvitationRequestModel girm = GroupInvitationRequestModel(
        name: gim.name,
        roomPubkey: gim.pubkey,
        myPubkey: identity.secp256k1PKHex,
        myName: identity.displayName,
        time: DateTime.now().millisecondsSinceEpoch,
        mlsPK: mlkPK,
        sig: '');
    Room? room =
        await RoomService.instance.getRoomByIdentity(gim.sender, identity.id);
    if (room == null) {
      room = await RoomService.instance.createRoomAndsendInvite(gim.sender,
          identity: identity, autoJump: false);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (room == null) {
      throw Exception('Room not found or create failed');
    }
    KeychatMessage sm = KeychatMessage(
        c: MessageType.mls, type: KeyChatEventKinds.groupInvitationRequesting)
      ..name = girm.toString()
      ..msg = 'Request to join group: ${gim.name}';
    await RoomService.instance
        .sendTextMessage(room, sm.toString(), realMessage: sm.msg);
  }
}
