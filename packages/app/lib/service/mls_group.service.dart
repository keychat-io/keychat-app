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
      String pk = user['pk'];
      keyPackages.add(base64.decode(pk));
    }
    if (keyPackages.isEmpty) {
      throw Exception('keyPackages is empty');
    }
    var welcome = await rust_mls.addMembers(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        keyPackages: keyPackages);
    await rust_mls.adderSelfCommit(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    String welcomeMsg = base64.encode(welcome.$2);
    String mlsGroupInfo = base64.encode(groupJoinConfig);
    await MlsGroupService.instance.inviteToJoinGroup(
        room, toUsers, jsonEncode([mlsGroupInfo, welcomeMsg]));

    return room;
  }

  // shared key receive message then decrypt message
  // message struct: nip4 wrap signal
  Future decryptMessage(Room room, NostrEventModel nostrEvent,
      {required Function(String) failedCallback}) async {
    Identity identity = room.getIdentity();
    List<int> decoded = base64.decode(nostrEvent.content).toList();
    var decryptedMsg = await rust_mls.decryptMsg(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        msg: decoded);
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
      await RoomService()
          .receiveDM(room, nostrEvent, decodedContent: decodeString);
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

  Future inviteToJoinGroup(
      Room room, List<Map<String, dynamic>> toUsers, String welcomeMsg,
      {String? sender}) async {
    Map<String, String> users = {};
    for (var user in toUsers) {
      users[user['pubkey']] = user['displayName'];
    }
    RoomProfile roomProfile = await GroupService()
        .inviteToJoinGroup(room, users, mlsWelcome: welcomeMsg);
    logger.d('create group: $roomProfile');
//     String names = users.values.toList().join(',');
//     KeychatMessage sm = KeychatMessage(
//         c: MessageType.mls, type: KeyChatEventKinds.inviteNewMember)
//       ..name = roomProfile.toString()
//       ..msg =
//           '''${sender == null ? 'Invite' : '[$sender] invite'} [${names.isNotEmpty ? names : users.keys.join(',').toString()}] to join group.
// Let's create a new group.''';

//     await MlsGroupService.instance.sendMessage(room, sm.toString());
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
            sourceEvent: sourceEvent,
            msgKeyHash: msgKeyHash,
            fromIdPubkey: fromIdPubkey!);
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
        return;
      default:
        await RoomService().receiveDM(room, event,
            sourceEvent: sourceEvent, km: km, fromIdPubkey: fromIdPubkey);
    }
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
  Future sendHelloMessage(Identity identity, Room room, String mlsInfo) async {
    logger.d('sendHelloMessage, version: ${room.version}');
    List<dynamic> info = jsonDecode(mlsInfo);
    List<int> groupJoinConfig = base64.decode(info[0]);
    List<int> welcome = base64.decode(info[1]);
    await rust_mls.joinMlsGroup(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        welcome: welcome,
        groupJoinConfig: groupJoinConfig);
    KeychatMessage sm = KeychatMessage(
        c: MessageType.mls, type: KeyChatEventKinds.kdfHelloMessage)
      ..name = identity.displayName
      ..msg = '${identity.displayName} joined group';

    await MlsGroupService.instance.sendMessage(room, sm.toString());
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
    var enctypted = await rust_mls.sendMsg(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        msg: message);

    String unEncryptedEvent = await rust_nostr.getUnencryptEvent(
        senderKeys: await identity.getSecp256k1SKHex(),
        receiverPubkey: room.toMainPubkey,
        content: base64.encode(enctypted.$1));

    var randomAccount = await rust_nostr.generateSimple();

    return await NostrAPI().sendNip4Message(room.toMainPubkey, unEncryptedEvent,
        prikey: randomAccount.prikey,
        from: randomAccount.pubkey,
        room: room,
        encryptType: MessageEncryptType.nip4WrapSignal,
        save: false,
        mediaType: mediaType,
        sourceContent: message,
        realMessage: realMessage,
        isSignalMessage: true);
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
      {String? msgKeyHash,
      NostrEventModel? sourceEvent,
      required String fromIdPubkey}) async {
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
      await Future.delayed(const Duration(milliseconds: 100));
      await _uploadPKMessage(identity);
    }
    logger.i('MLS initIdentities success');
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

  Future<String> createKeyMessages(String pubkey) async {
    Uint8List pk = await rust_mls.createKeyPackage(nostrId: pubkey);
    return base64.encode(pk);
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
}
