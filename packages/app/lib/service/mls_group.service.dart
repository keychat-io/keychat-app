import 'dart:convert' show base64, jsonDecode, jsonEncode, utf8;

import 'package:app/constants.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/nostr-core/nostr_nip4_req.dart';
import 'package:app/nostr-core/relay_websocket.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/service/chat.service.dart';
import 'package:app/service/group.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/signal_chat_util.dart';
import 'package:app/service/storage.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_mls.dart' as rust_mls;
import 'package:keychat_rust_ffi_plugin/api_mls/types.dart'
    show DecryptedMessage, GroupExtensionResult, MessageResult;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class MlsGroupService extends BaseChatService {
  static MlsGroupService? _instance;
  static String? dbPath;
  static MlsGroupService get instance => _instance ??= MlsGroupService._();
  // Avoid self instance
  MlsGroupService._();

  Future addMemeberToGroup(Room groupRoom, List<Map<String, dynamic>> toUsers,
      [String? sender]) async {
    Identity identity = groupRoom.getIdentity();
    Map<String, String> userNameMap = {};
    List<Uint8List> keyPackages = [];
    for (var user in toUsers) {
      userNameMap[user['pubkey']] = user['name'];
      String? pk = user['mlsPK'];
      if (pk != null) {
        keyPackages.add(base64.decode(pk));
      }
    }
    if (keyPackages.isEmpty) {
      throw Exception('keyPackages is empty');
    }

    var data = await rust_mls.addMembers(
        nostrId: identity.secp256k1PKHex,
        groupId: groupRoom.toMainPubkey,
        keyPackages: keyPackages);
    String welcomePrososal = base64.encode(data.queuedMsg);
    String welcomeMsg = base64.encode(data.welcome);
    // send sync message to other member
    await sendEncryptedMessage(groupRoom, welcomePrososal,
        additionalTags: [
          [EventKindTags.pubkey, groupRoom.onetimekey!],
          [EventKindTags.customMessage, MLSPrososalType.add.name]
        ],
        realMessage: 'Invite ${userNameMap.values.join(', ')} to join group');
    await rust_mls.selfCommit(
        nostrId: identity.secp256k1PKHex, groupId: groupRoom.toMainPubkey);
    await proccessUpdateKeys(groupRoom);

    // send invitation message
    await _sendInviteMessage(
        groupRoom: groupRoom, users: userNameMap, mlsWelcome: welcomeMsg);
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
      {required List<Map<String, dynamic>> toUsers,
      required List<String> groupRelays}) async {
    Room room = await GroupService.instance
        .createGroup(groupName, identity, GroupType.mls);

    await rust_mls.createMlsGroup(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        groupName: groupName,
        adminPubkeysHex: [identity.secp256k1PKHex],
        description: '',
        groupRelays: groupRelays);
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

    String welcomeMsg = base64.encode(welcome.welcome);
    // String mlsGroupInfo = base64.encode(groupJoinConfig);

    Map<String, String> result = {};
    for (var user in toUsers) {
      result[user['pubkey']] = user['name'];
    }

    await _sendInviteMessage(
        groupRoom: room, users: result, mlsWelcome: welcomeMsg);

    return room;
  }

  Future<Room> createGroupFromInvitation(
      NostrEventModel event, Identity identity, Message message,
      {required String groupId}) async {
    Room room = Room(
        toMainPubkey: groupId,
        npub: rust_nostr.getBech32PubkeyByHex(hex: groupId),
        identityId: identity.id,
        status: RoomStatus.enabled,
        type: RoomType.group)
      ..name = groupId.substring(0, 8)
      ..groupType = GroupType.mls
      ..version = event.createdAt;
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.messages.put(message);
      room.id = await DBProvider.database.rooms.put(room);
    });
    List<int> welcome = base64.decode(event.content).toList();
    await rust_mls.joinMlsGroup(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        welcome: welcome);
    GroupExtension info = await getGroupExtension(room);
    logger.d('GroupExtension: ${info.toMap()}');
    room.name = info.name;
    room.description = info.description;
    room.sendingRelays = info.relays;
    room.receivingRelays = info.relays;
    if (info.relays.isNotEmpty) {
      await RelayService.instance.addOrActiveRelay(info.relays);
    }
    await Utils.waitRelayOnline();
    await replaceListenPubkey(room, identity.secp256k1PKHex);
    return room;
  }

  Future<String> createKeyMessages(String pubkey) async {
    Uint8List pk = await rust_mls.createKeyPackage(nostrId: pubkey);
    return base64.encode(pk);
  }

  // kind 445
  Future decryptMessage(Room room, NostrEventModel event,
      {required Function(String) failedCallback}) async {
    Identity identity = room.getIdentity();
    List<int> decoded = base64.decode(event.content).toList();
    var exist = await MessageService.instance.getMessageByEventId(event.id);
    if (exist != null) {
      logger.d('Event may sent by me: ${event.id}');
      return;
    }
    String? method = event.getTagByKey(EventKindTags.customMessage);
    if (method != null) {
      MLSPrososalType type = MLSPrososalType.values.firstWhere(
          (e) => e.name == method,
          orElse: () => MLSPrososalType.custom);
      await proccessMLSProsoalMessage(room, event,
          type: type, failedCallback: failedCallback);
      return;
    }
    DecryptedMessage? decryptedMsg;
    try {
      decryptedMsg = await rust_mls.decryptMessage(
          nostrId: identity.secp256k1PKHex,
          groupId: room.toMainPubkey,
          msg: decoded);
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      failedCallback(msg);
      logger.e(msg, error: e, stackTrace: s);
      await appendMessageOrCreate(msg, room, 'mls decrypt failed', event);
      return;
    }
    String fromIdPubkey = decryptedMsg.sender;
    String decodeString = decryptedMsg.decryptMsg;
    String? msgKeyHash = decryptedMsg.ratchetKey != null
        ? base64.encode(decryptedMsg.ratchetKey!)
        : null;

    await RoomService.instance.receiveDM(room, event,
        decodedContent: decodeString,
        fromIdPubkey: fromIdPubkey,
        encryptType: MessageEncryptType.mls,
        msgKeyHash: msgKeyHash);
  }

  Future<String> getAdmin(Room room) async {
    return '';
  }

  Future<GroupExtension> getGroupExtension(Room room) async {
    GroupExtensionResult ger = await rust_mls.getGroupExtension(
        nostrId: room.getIdentity().secp256k1PKHex, groupId: room.toMainPubkey);

    return GroupExtension(
      name: utf8.decode(ger.name),
      description: utf8.decode(ger.description),
      admins: ger.adminPubkeys.map((e) => utf8.decode(e)).toList(),
      relays: ger.relays.map((e) => utf8.decode(e)).toList(),
    );
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

  Future<Map<String, String>> getKeyPackagesFromRelay(
      List<String> pubkeys) async {
    var ws = Get.find<WebsocketService>();
    if (pubkeys.isEmpty) return {};

    NostrReqModel req = NostrReqModel(
        reqId: generate64RandomHexChars(16),
        authors: pubkeys,
        kinds: [EventKinds.nip104KP],
        limit:
            10, // Increased limit to get multiple results per pubkey if available
        since: DateTime.now().subtract(Duration(days: 365)));
    List<RelayWebsocket> relays = ws.getConnectedNip104Relay();
    List<NostrEventModel> list = await ws.fetchInfoFromRelay(
        req.reqId, req.toString(),
        waitTimeToFill: true, sockets: relays);

    // Process results to get latest content per pubkey
    Map<String, NostrEventModel> result = {};

    for (var event in list) {
      if (!result.containsKey(event.pubkey)) {
        result[event.pubkey] = event;
      } else {
        if (result[event.pubkey]!.createdAt < event.createdAt) {
          result[event.pubkey] = event;
        }
      }
    }

    Map<String, String> result2 = {};
    for (var event in result.entries) {
      result2[event.key] = event.value.content;
    }

    logger.d('PKs: $result2');
    return result2;
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
    String? signature = await SignalChatUtil.signByIdentity(
        identity: room.getIdentity(), content: contentToSign);
    if (signature == null) {
      throw Exception('Sign failed or User denied');
    }
    map['signature'] = signature;

    return jsonEncode(map);
  }

  // kind 444
  Future handleWelcomeEvent(
      {required NostrEventModel subEvent,
      required NostrEventModel sourceEvent,
      required Relay relay}) async {
    logger.d('subEvent $subEvent');
    String senderIdPubkey = subEvent.pubkey;
    String myIdPubkey = sourceEvent.getTagByKey(EventKindTags.pubkey)!;
    Room idRoom = await RoomService.instance
        .getOrCreateRoom(subEvent.pubkey, myIdPubkey, RoomStatus.enabled);
    Identity identity = idRoom.getIdentity();
    if (senderIdPubkey == identity.secp256k1PKHex) {
      logger.d('Event sent by me: ${subEvent.id}');
      return;
    }
    String? pubkey = subEvent.getTagByKey(EventKindTags.pubkey);
    if (pubkey == null) {
      throw Exception('Tag p is null');
    }
    await MessageService.instance.saveMessageToDB(
        from: sourceEvent.pubkey,
        to: sourceEvent.tags[0][1],
        idPubkey: idRoom.toMainPubkey,
        events: [sourceEvent],
        subEvent: subEvent.toString(),
        room: idRoom,
        isMeSend: false,
        isSystem: true,
        encryptType: RoomUtil.getEncryptMode(sourceEvent),
        sent: SendStatusType.success,
        mediaType: MessageMediaType.groupInvite,
        requestConfrim: RequestConfrimEnum.request,
        content: subEvent.toString(),
        realMessage: 'Invite you to join group');
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

    for (Identity identity in identities) {
      try {
        await rust_mls.initMlsDb(
            dbPath: '$dbPath${KeychatGlobal.mlsDBFile}',
            nostrId: identity.secp256k1PKHex);
        logger.i('MLS init for identity: ${identity.secp256k1PKHex}');
      } catch (e, s) {
        logger.e(
            'Failed to initialize MLS for identity: ${identity.secp256k1PKHex} ${e.toString()}',
            error: e,
            stackTrace: s);
      }
    }
    uploadKeyPackages(identities);
  }

  @Deprecated('use proccessMLSPrososalMessage instead')
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

  Future proccessMLSProsoalMessage(Room room, NostrEventModel event,
      {required MLSPrososalType type,
      Function(String p1)? failedCallback}) async {
    Identity identity = room.getIdentity();
    try {
      Uint8List queuedMsg = base64.decode(event.content);
      String? realMessage;
      switch (type) {
        // other commit : added a new member
        case MLSPrososalType.add:
          if (event.createdAt < room.version) {
            throw Exception('The invitation has expired');
          }
          await rust_mls.othersCommitNormal(
              nostrId: identity.secp256k1PKHex,
              groupId: room.toMainPubkey,
              queuedMsg: queuedMsg);
          await proccessUpdateKeys(room, event.createdAt);
          // TODO get sender
          realMessage = 'xx added xx to the group';
          break;
        case MLSPrososalType.update:
          await rust_mls.othersCommitNormal(
              nostrId: room.myIdPubkey,
              groupId: room.toMainPubkey,
              queuedMsg: queuedMsg);

          await replaceListenPubkey(room, room.myIdPubkey);
          realMessage = 'xx added xx to the group';

          break;
        case MLSPrososalType.remove:
          await rust_mls.othersCommitNormal(
              nostrId: identity.secp256k1PKHex,
              groupId: room.toMainPubkey,
              queuedMsg: queuedMsg);
          room = await replaceListenPubkey(room, identity.secp256k1PKHex);
          realMessage = 'The admin removed member: xx';

          break;
        case MLSPrososalType.preSharedKey:
          break;
        case MLSPrososalType.reInit:
          break;
        case MLSPrososalType.externalInit:
          break;
        case MLSPrososalType.groupContextExtensions:
          break;
        case MLSPrososalType.appAck:
          break;
        case MLSPrososalType.selfRemove:
          break;
        case MLSPrososalType.custom:
          // Handle custom proposal type (might need to implement this based on your requirements)
          logger.w('Custom MLS proposal type not implemented');
          break;
      }

      await RoomService.instance.receiveDM(room, event,
          fromIdPubkey: identity.secp256k1PKHex,
          encryptType: MessageEncryptType.mls,
          realMessage: realMessage);
    } catch (e, s) {
      String msg = Utils.getErrorMessage(e);
      if (failedCallback != null) {
        failedCallback(msg);
      }
      logger.e('Error processing MLS proposal: $msg', error: e, stackTrace: s);
      await appendMessageOrCreate(
          msg, room, 'MLS proposal processing failed', event);
    }
  }

  Future<Room> proccessUpdateKeys(Room groupRoom, [int? version]) async {
    Identity identity = groupRoom.getIdentity();
    if (version != null) {
      groupRoom.version = version;
    }
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

    String realMessage =
        '[System] Admin remove ${names.length > 1 ? 'members' : 'member'}: ${names.join(',')}';

    await sendEncryptedMessage(room, base64.encode(queuedMsg),
        realMessage: realMessage,
        additionalTags: [
          [EventKindTags.pubkey, room.onetimekey!],
          [EventKindTags.customMessage, MLSPrososalType.remove.name]
        ]);
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
    return await room.replaceListenPubkey(newPubkey, room.version,
        toDeletePubkey: room.onetimekey, kinds: [EventKinds.nip104GroupEvent]);
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
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        extensions: []);

    await sendEncryptedMessage(room, base64.encode(queuedMsg),
        realMessage: '[System] Update my mls-group-key');
    await rust_mls.selfCommit(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    room = await replaceListenPubkey(room, identity.secp256k1PKHex);
  }

  Future<SendMessageResponse> sendEncryptedMessage(Room room, String message,
      {bool save = true,
      MessageMediaType? mediaType,
      String? realMessage,
      List<List<String>>? additionalTags}) async {
    if (room.onetimekey == null) {
      throw Exception('Receiving pubkey is null');
    }

    var randomAccount = await rust_nostr.generateSimple();
    var smr = await NostrAPI.instance.sendNip4Message(room.onetimekey!, message,
        prikey: randomAccount.prikey,
        from: randomAccount.pubkey,
        room: room,
        mediaType: mediaType,
        encryptType: MessageEncryptType.mls,
        kind: EventKinds.nip104GroupEvent,
        save: save,
        sourceContent: message,
        realMessage: realMessage,
        isEncryptedMessage: true,
        additionalTags: additionalTags);
    RoomUtil.messageReceiveCheck(
            room, smr.events[0], const Duration(milliseconds: 500), 3)
        .then((res) {
      if (res == false) {
        logger.e('MLS Message Send failed: $message');
      }
    });
    return smr;
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
    MessageResult enctypted = await rust_mls.createMessage(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        msg: message);

    // refresh onetime key
    if (realMessage != null) {
      room = await RoomService.instance.getRoomByIdOrFail(room.id);
    }
    var randomAccount = await rust_nostr.generateSimple();
    var smr = await NostrAPI.instance.sendNip4Message(
        room.onetimekey!, base64.encode(enctypted.encryptMsg),
        prikey: randomAccount.prikey,
        from: randomAccount.pubkey,
        room: room,
        encryptType: MessageEncryptType.mls,
        kind: EventKinds.nip104GroupEvent,
        msgKeyHash: enctypted.ratchetKey == null
            ? null
            : base64.encode(enctypted.ratchetKey!),
        save: save,
        mediaType: mediaType,
        sourceContent: message,
        realMessage: realMessage,
        reply: reply,
        isEncryptedMessage: true);
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

  Future uploadKeyPackages([List<Identity>? identities]) async {
    List<String> relys = await Utils.waitRelayOnline();

    if (relys.isEmpty) {
      logger.e('No relays available');
      throw Exception('No relays available');
    }
    // TODO delete old key packages
    identities ??= await IdentityService.instance.getIdentityList();
    for (Identity identity in identities) {
      String mlkPK = await MlsGroupService.instance
          .createKeyMessages(identity.secp256k1PKHex);

      String event = await rust_nostr.signEvent(
          senderKeys: await identity.getSecp256k1SKHex(),
          content: mlkPK,
          createdAt: BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
          kind: EventKinds.nip104KP,
          tags: [
            ["mls_protocol_version", "1.0"],
            ["relay", ...relys]
          ]);
      Get.find<WebsocketService>().sendMessageWithCallback(event, callback: (
          {required String relay,
          required String eventId,
          required bool status,
          String? errorMessage}) async {
        NostrAPI.instance.removeOKCallback(eventId);
        await RelayService.instance.updateP104(relay, status);
        var map = {
          'relay': relay,
          'status': status,
          'errorMessage': errorMessage,
        };
        logger.d('uploadKeyPackages callback: $map');
      });
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
    String? adminMember = await room.getAdmin();
    if (room.myIdPubkey != adminMember) return;
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

  Future _sendInviteMessage(
      {required Room groupRoom,
      required Map<String, String> users,
      required String mlsWelcome}) async {
    if (users.isEmpty) return;
    Identity identity = groupRoom.getIdentity();
    await RoomService.instance.checkRoomStatus(groupRoom);
    String realMessage =
        'Invite ${users.values.join(',')} to join group ${groupRoom.name}';

    await GroupService.instance.sendPrivateMessageToMembers(
        realMessage, users.keys.toList(), identity,
        content: mlsWelcome,
        groupRoom: groupRoom,
        nip17: true,
        nip17Kind: EventKinds.nip104Welcome,
        additionalTags: [
          // group id
          [EventKindTags.pubkey, groupRoom.toMainPubkey],
        ]);

    RoomService.getController(groupRoom.id)?.resetMembers();
  }
}

enum MLSPrososalType {
  add,
  update,
  remove,
  preSharedKey,
  reInit,
  externalInit,
  groupContextExtensions,
  appAck,
  selfRemove,
  custom,
}
