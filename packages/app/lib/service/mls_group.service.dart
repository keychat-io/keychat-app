import 'dart:convert'
    show base64Decode, base64Encode, jsonDecode, jsonEncode, utf8;

import 'package:app/constants.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/close.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/nostr-core/nostr_nip4_req.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/service/chat.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/message.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/signal_chat_util.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_mls.dart' as rust_mls;
import 'package:keychat_rust_ffi_plugin/api_mls/types.dart';
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
    Map<String, String> userNameMap = {}; // pubkey, name
    List<String> keyPackages = [];
    for (var user in toUsers) {
      userNameMap[user['pubkey']] = user['name'];
      String? pk = user['mlsPK'];
      if (pk != null) {
        keyPackages.add(pk);
      }
    }
    if (keyPackages.isEmpty) {
      throw Exception('keyPackages is empty');
    }

    var data = await rust_mls.addMembers(
        nostrId: identity.secp256k1PKHex,
        groupId: groupRoom.toMainPubkey,
        keyPackages: keyPackages);
    String welcomeMsg = base64Encode(data.welcome);
    // send sync message to other member
    groupRoom = await RoomService.instance.getRoomByIdOrFail(groupRoom.id);
    await sendEncryptedMessage(groupRoom, data.queuedMsg,
        realMessage: 'Invite [${userNameMap.values.join(', ')}] to join group');
    await rust_mls.selfCommit(
        nostrId: identity.secp256k1PKHex, groupId: groupRoom.toMainPubkey);
    groupRoom = await _proccessUpdateKeys(groupRoom);

    // send invitation message
    await _sendInviteMessage(
        groupRoom: groupRoom, users: userNameMap, mlsWelcome: welcomeMsg);
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
          senderPubkey: fromIdPubkey);
      return;
    }
    message.content = '''${message.content}

$error ''';
    await MessageService.instance.updateMessageAndRefresh(message);
  }

  Future<Room> createGroup(String groupName, Identity identity,
      {required List<Map<String, dynamic>> toUsers,
      required List<String> groupRelays,
      String? description}) async {
    var randomKey = await rust_nostr.generateSimple();
    String toMainPubkey = randomKey.pubkey;
    int version = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    Room room = Room(
        toMainPubkey: toMainPubkey,
        npub: rust_nostr.getBech32PubkeyByHex(hex: toMainPubkey),
        identityId: identity.id,
        status: RoomStatus.enabled,
        type: RoomType.group)
      ..name = groupName
      ..groupType = GroupType.mls
      ..sentHelloToMLS = true
      ..sendingRelays = groupRelays
      ..version = version;

    room = await RoomService.instance.updateRoom(room);

    await rust_mls.createMlsGroup(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        groupName: groupName,
        adminPubkeysHex: [identity.secp256k1PKHex],
        description: description ?? '',
        groupRelays: groupRelays,
        status: RoomStatus.enabled.name);
    await _selfUpdateKeyLocal(room);
    await rust_mls.selfCommit(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);

    List<String> keyPackages = [];
    for (var user in toUsers) {
      String pk = user['mlsPK'];
      keyPackages.add(pk);
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
    room = await replaceListenPubkey(room);

    String welcomeMsg = base64Encode(welcome.welcome);

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
    List<int> welcome = base64Decode(event.content).toList();
    await rust_mls.joinMlsGroup(
        nostrId: identity.secp256k1PKHex,
        groupId: room.toMainPubkey,
        welcome: welcome);
    GroupExtension info = await getGroupExtension(room);
    room.name = info.name;
    room.description = info.description;
    room.sendingRelays = info.relays;
    if (info.relays.isNotEmpty) {
      await RelayService.instance.addOrActiveRelay(info.relays);
    }
    room = await replaceListenPubkey(room);
    return room;
  }

  // kind 445
  Future decryptMessage(
      Room room, NostrEventModel event, Function(String) failedCallback) async {
    var exist = await MessageService.instance.getMessageByEventId(event.id);
    if (exist != null) {
      loggerNoLine.d('[mls]Received my event: ${event.id}');
      return;
    }
    try {
      MessageInType messageType = await rust_mls.parseMlsMsgType(
          groupId: room.toMainPubkey,
          nostrId: room.myIdPubkey,
          data: event.content);
      switch (messageType) {
        case MessageInType.commit:
          await _proccessTryProposalIn(
              room, event, event.content, failedCallback);
          break;
        case MessageInType.application:
          await _proccessApplication(
              room, event, event.content, failedCallback);
          break;
        default:
          throw Exception('Unsupported: ${messageType.name}');
      }
    } catch (e, s) {
      String? sender;
      try {
        sender = await rust_mls.getSender(
            nostrId: room.myIdPubkey,
            groupId: room.toMainPubkey,
            queuedMsg: event.content);
        // ignore: empty_catches
      } catch (e) {}
      String msg = '$sender ${Utils.getErrorMessage(e)}';
      logger.e('decrypt mls msg: $msg', error: e, stackTrace: s);
      failedCallback(msg);
      await appendMessageOrCreate(msg, room, 'mls decrypt failed', event);
    }
  }

  // Future deleteOldKeypackage(List<Identity> identities) async {
  //   if (identities.isEmpty) return;
  //   var ws = Get.find<WebsocketService>();
  //   await Future.forEach(identities, (identity) async {
  //     NostrReqModel req = NostrReqModel(
  //         reqId: generate64RandomHexChars(16),
  //         authors: [identity.secp256k1PKHex],
  //         kinds: [EventKinds.nip104KP],
  //         limit: 10,
  //         since: DateTime.now().subtract(Duration(days: 365)));
  //     List<RelayWebsocket> relays = ws.getOnlineNip104Relay();
  //     List<NostrEventModel> list = await ws.fetchInfoFromRelay(
  //         req.reqId, req.toString(),
  //         waitTimeToFill: true, sockets: relays);
  //     Get.find<WebsocketService>().sendMessage(Close(req.reqId).serialize());
  //     if (list.isEmpty) return;
  //     var ess = list.map((e) => ['e', e.id]);
  //     var event = await NostrAPI.instance.signEventByIdentity(
  //         identity: identity,
  //         content: "delete",
  //         createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  //         kind: EventKinds.delete,
  //         tags: [
  //           ...ess,
  //           ["k", EventKinds.nip104KP.toString()]
  //         ]);
  //     Get.find<WebsocketService>().sendMessageWithCallback(event, callback: (
  //         {required String relay,
  //         required String eventId,
  //         required bool status,
  //         String? errorMessage}) async {
  //       NostrAPI.instance.removeOKCallback(eventId);
  //       var map = {
  //         'relay': relay,
  //         'status': status,
  //         'errorMessage': errorMessage,
  //       };
  //       logger.d('fetchOldKeypackageAndDelete callback: $map');
  //     });
  //   });
  // }

  Future dissolve(Room room) async {
    var res = await rust_mls.updateGroupContextExtensions(
        nostrId: room.myIdPubkey,
        groupId: room.toMainPubkey,
        status: RoomStatus.dissolved.name);
    String realMessage = '[System] The admin closed the group chat';

    await sendEncryptedMessage(room, res, realMessage: realMessage);
    await RoomService.instance.deleteRoom(room);
  }

  Future<GroupExtension> getGroupExtension(Room room) async {
    GroupExtensionResult ger = await rust_mls.getGroupExtension(
        nostrId: room.myIdPubkey, groupId: room.toMainPubkey);

    return GroupExtension(
      name: utf8.decode(ger.name),
      description: utf8.decode(ger.description),
      admins: ger.adminPubkeys.map((e) => utf8.decode(e)).toList(),
      relays: ger.relays.map((e) => utf8.decode(e)).toList(),
      status: utf8.decode(ger.status),
    );
  }

  Future<Map<String, String>> getKeyPackagesFromRelay(
      List<String> pubkeys) async {
    var ws = Get.find<WebsocketService>();
    if (pubkeys.isEmpty) return {};

    NostrReqModel req = NostrReqModel(
        reqId: generate64RandomHexChars(16),
        authors: pubkeys,
        kinds: [EventKinds.mlsNipKeypackages],
        limit: pubkeys.length,
        since: DateTime.now().subtract(Duration(days: 365)));
    List<NostrEventModel> list = await ws
        .fetchInfoFromRelay(req.reqId, req.toString(), waitTimeToFill: true);
    // close req
    Get.find<WebsocketService>().sendMessage(Close(req.reqId).serialize());

    Map<String, String> result = {};
    for (var event in list) {
      result[event.pubkey] = event.content;
    }

    logger.d('PKs: $result');
    return result;
  }

  Future<String?> getKeyPackageFromRelay(String pubkey) async {
    var ws = Get.find<WebsocketService>();

    try {
      NostrReqModel req = NostrReqModel(
          reqId: generate64RandomHexChars(16),
          authors: [pubkey],
          kinds: [EventKinds.mlsNipKeypackages],
          limit: 1,
          since: DateTime.now().subtract(Duration(days: 365)));
      List<NostrEventModel> list = await ws
          .fetchInfoFromRelay(req.reqId, req.toString(), waitTimeToFill: true);
      // close req

      ws.sendMessage(Close(req.reqId).serialize());

      if (list.isEmpty) return null;
      return list[0].content;
    } catch (e, s) {
      logger.e('Error getting key package from relay: ${e.toString()}',
          error: e, stackTrace: s);
      return null;
    }
  }

  Future<Map<String, RoomMember>> getMembers(Room room) async {
    Map<String, RoomMember> roomMembers = {};
    Map<String, List<Uint8List>> extensions = await rust_mls.getMemberExtension(
        nostrId: room.myIdPubkey, groupId: room.toMainPubkey);
    for (var element in extensions.entries) {
      String name = element.key;
      UserStatusType status = UserStatusType.invited;
      if (element.value.isNotEmpty) {
        try {
          String res = utf8.decode(element.value[0]);
          Map extension = jsonDecode(res);
          name = extension['name'];
          if (extension['status'] != null) {
            status = UserStatusType.values
                .firstWhere((e) => e.name == extension['status']);
          }
        } catch (e) {
          logger.e('getMembers: ${e.toString()}');
        }
      }
      roomMembers[element.key] = RoomMember(
          idPubkey: element.key, name: name, roomId: room.id, status: status);
    }
    return roomMembers;
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
    String myIdPubkey = (sourceEvent.getTagByKey(EventKindTags.pubkey) ??
        sourceEvent.getTagByKey(EventKindTags.pubkey))!;
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
        senderPubkey: idRoom.toMainPubkey,
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
        logger.e('Init MLS Failed: ${identity.secp256k1PKHex} ${e.toString()}',
            error: e, stackTrace: s);
      }
    }
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
    throw Exception('Deprecated');
  }

  Future<Room> _proccessUpdateKeys(Room groupRoom, [int? version]) async {
    if (version != null) {
      groupRoom.version = version;
    }
    groupRoom = await replaceListenPubkey(groupRoom);
    await RoomService.getController(groupRoom.id)
        ?.setRoom(groupRoom)
        .resetMembers();
    return groupRoom;
  }

  Future removeMembers(Room room, List<RoomMember> list) async {
    await waitingForEose(
        recevingKey: room.onetimekey, relays: room.sendingRelays);
    Identity identity = room.getIdentity();
    List<String> idPubkeys = [];
    List<String> names = [];
    List<Uint8List> bLeafNodes = [];
    for (RoomMember rm in list) {
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

    room = await RoomService.instance.getRoomByIdOrFail(room.id);
    await sendEncryptedMessage(room, queuedMsg, realMessage: realMessage);
    await rust_mls.selfCommit(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    room = await replaceListenPubkey(room);
    RoomService.getController(room.id)?.setRoom(room).resetMembers();
  }

  Future<Room> replaceListenPubkey(Room room) async {
    String newPubkey = await rust_mls.getListenKeyFromExportSecret(
        nostrId: room.myIdPubkey, groupId: room.toMainPubkey);
    if (newPubkey == room.onetimekey) {
      await RoomService.instance.updateRoomAndRefresh(room);
      return room;
    }
    String? toDeletePubkey = room.onetimekey;
    // waiting for the old pubkey to be Eosed. means that all events proccessed
    await waitingForEose(
        recevingKey: room.onetimekey, relays: room.sendingRelays);

    room.onetimekey = newPubkey;
    await RoomService.instance.updateRoomAndRefresh(room);
    var ws = Get.find<WebsocketService>();
    if (toDeletePubkey != null) {
      ws.removePubkeyFromSubscription(toDeletePubkey);
      if (room.isMute == false) {
        NotifyService.removePubkeys([toDeletePubkey]);
      }
    }

    ws.listenPubkeyNip17([newPubkey],
        since: DateTime.fromMillisecondsSinceEpoch(room.version)
            .subtract(Duration(seconds: 3)));

    if (room.isMute == false) {
      NotifyService.addPubkeys([newPubkey]);
    }
    return room;
  }

  Future sendGreetingMessage(Room room) async {
    room.sentHelloToMLS = true;
    await selfUpdateKey(room,
        extension: {'name': room.getIdentity().displayName});
  }

  Future<Room> selfUpdateKey(Room room,
      {Map<String, dynamic>? extension}) async {
    await waitingForEose(
        recevingKey: room.onetimekey, relays: room.sendingRelays);
    var queuedMsg = await _selfUpdateKeyLocal(room, extension);
    Identity identity = room.getIdentity();
    String realMessage =
        'Hi everyone, I\'m ${extension?['name'] ?? identity.displayName}!';
    await sendEncryptedMessage(room, queuedMsg, realMessage: realMessage);
    await rust_mls.selfCommit(
        nostrId: identity.secp256k1PKHex, groupId: room.toMainPubkey);
    room = await replaceListenPubkey(room);
    await RoomService.getController(room.id)?.resetMembers();

    return room;
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
    var smr =
        await NostrAPI.instance.sendEventMessage(room.onetimekey!, message,
            prikey: randomAccount.prikey,
            from: randomAccount.pubkey,
            room: room,
            mediaType: mediaType,
            encryptType: MessageEncryptType.mls,
            kind: EventKinds.nip17,
            save: save,
            sourceContent: message,
            realMessage: realMessage,
            isEncryptedMessage: true,
            additionalTags: additionalTags ??
                [
                  [EventKindTags.pubkey, room.onetimekey!]
                ]);
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
    // String mlkPK = await createKeyMessages(identity.secp256k1PKHex);
    GroupInvitationRequestModel girm = GroupInvitationRequestModel(
        name: gim.name,
        roomPubkey: gim.pubkey,
        myPubkey: identity.secp256k1PKHex,
        myName: identity.displayName,
        time: DateTime.now().millisecondsSinceEpoch,
        mlsPK: '',
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
        .sendMessage(room, sm.toString(), realMessage: sm.msg);
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
    var smr = await NostrAPI.instance
        .sendEventMessage(room.onetimekey!, enctypted.encryptMsg,
            prikey: randomAccount.prikey,
            from: randomAccount.pubkey,
            room: room,
            encryptType: MessageEncryptType.mls,
            kind: EventKinds.nip17,
            additionalTags: [
              [EventKindTags.pubkey, room.onetimekey!]
            ],
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

  Future<Room> updateGroupName(Room room, String newName) async {
    await waitingForEose(
        recevingKey: room.onetimekey, relays: room.sendingRelays);
    var res = await rust_mls.updateGroupContextExtensions(
        nostrId: room.myIdPubkey,
        groupId: room.toMainPubkey,
        groupName: newName);
    await sendEncryptedMessage(room, res,
        realMessage: '[System]Update group name to: $newName');
    await rust_mls.selfCommit(
        nostrId: room.myIdPubkey, groupId: room.toMainPubkey);
    room = await replaceListenPubkey(room);
    return room;
  }

  Future uploadKeyPackages(
      {List<Identity>? identities,
      List<String>? toRelays,
      bool forceUpload = false}) async {
    List<String> onlineRelays = await Utils.waitRelayOnline();
    if (onlineRelays.isEmpty) {
      throw Exception('No relays available');
    }
    identities ??= Get.find<HomeController>().allIdentities.values.toList();
    await Future.wait(identities.map((identity) async {
      if (!forceUpload) {
        if (Get.find<HomeController>().allIdentities[identity.id]?.mlsInit ==
            true) {
          logger.d('${identity.secp256k1PKHex}\'s key packages initialized');
          return;
        }
      }
      logger.d(
          '${EventKinds.mlsNipKeypackages} start: ${identity.secp256k1PKHex}');

      var pkRes =
          await rust_mls.createKeyPackage(nostrId: identity.secp256k1PKHex);

      String event = await NostrAPI.instance.signEventByIdentity(
          identity: identity,
          content: pkRes.keyPackage,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          kind: EventKinds.mlsNipKeypackages,
          tags: [
            ["mls_protocol_version", pkRes.mlsProtocolVersion],
            ["ciphersuite", pkRes.ciphersuite],
            ["extensions", pkRes.extensions],
            ["client", KeychatGlobal.appName],
            ["relay", ...onlineRelays]
          ]);
      Get.find<WebsocketService>()
          .sendMessageWithCallback(event, relays: toRelays, callback: (
              {required String relay,
              required String eventId,
              required bool status,
              String? errorMessage}) {
        Get.find<HomeController>().allIdentities[identity.id]?.mlsInit = true;
        NostrAPI.instance.removeOKCallback(eventId);
        var map = {
          'relay': relay,
          'status': status,
          'errorMessage': errorMessage,
        };
        logger.d('Kind: ${EventKinds.mlsNipKeypackages}, relay: $map');
      });
    }));
  }

  Future<(Room, String?)> _handleGroupInfo(
      Room room, NostrEventModel event, String queuedMsg) async {
    GroupExtension info = await getGroupExtension(room);
    if (info.status == RoomStatus.dissolved.name) {
      room.status = RoomStatus.dissolved;
      String toSaveMsg = '[System] The admin closed this group chat';
      await RoomService.instance.updateRoomAndRefresh(room);
      return (room, toSaveMsg);
    }
    room.name = info.name;
    room.description = info.description;
    room.sendingRelays = info.relays;
    await RelayService.instance.addOrActiveRelay(info.relays);
    room = await replaceListenPubkey(room);
    return (room, null);
  }

  Future _proccessApplication(Room room, NostrEventModel event, String decoded,
      Function(String) failedCallback) async {
    DecryptedMessage decryptedMsg = await rust_mls.decryptMessage(
        nostrId: room.myIdPubkey, groupId: room.toMainPubkey, msg: decoded);

    RoomMember? sender = await room.getMemberByIdPubkey(decryptedMsg.sender);
    KeychatMessage? km;
    try {
      km = KeychatMessage.fromJson(jsonDecode(decryptedMsg.decryptMsg));
      // ignore: empty_catches
    } catch (e) {}
    await RoomService.instance.receiveDM(room, event,
        km: km,
        decodedContent: decryptedMsg.decryptMsg,
        senderPubkey: decryptedMsg.sender,
        encryptType: MessageEncryptType.mls,
        senderName: sender?.name ?? decryptedMsg.sender);
  }

  Future _proccessTryProposalIn(Room room, NostrEventModel event,
      String queuedMsg, Function(String) failedCallback) async {
    if (event.createdAt <= room.version) {
      throw Exception('Event is outdated.${event.id}');
    }
    var res = await rust_mls.getSender(
        nostrId: room.myIdPubkey,
        groupId: room.toMainPubkey,
        queuedMsg: queuedMsg);
    if (res == null) {
      throw Exception('Sender not found. ${event.id}');
    }
    String senderPubkey = res;
    RoomMember? sender = await room.getMemberByIdPubkey(senderPubkey);
    String senderName = sender?.name ?? senderPubkey;
    var before = await getMembers(room);
    CommitResult commitResult = await rust_mls.othersCommitNormal(
        nostrId: room.myIdPubkey,
        groupId: room.toMainPubkey,
        queuedMsg: queuedMsg);
    bool isMeRemoved = commitResult.commitType == CommitTypeResult.remove &&
        (commitResult.operatedMembers ?? []).contains(room.myIdPubkey);
    if (!isMeRemoved) {
      room = await _proccessUpdateKeys(room, event.createdAt);
    }

    String? realMessage;
    switch (commitResult.commitType) {
      case CommitTypeResult.add:
        List<String>? pubkeys = commitResult.operatedMembers;
        if (pubkeys == null) {
          throw Exception('pubkeys is null');
        }
        List<String> diffMembers = [];
        for (String pubkey in pubkeys) {
          RoomMember? member = await room.getMemberByIdPubkey(pubkey);
          diffMembers.add(member?.name ?? pubkey);
        }
        realMessage =
            '[System] $senderName added [${diffMembers.join(",")}] to the group';
        break;
      case CommitTypeResult.update:
        await RoomService.getController(room.id)?.resetMembers();
        var newMember = await room.getMemberByIdPubkey(senderPubkey);
        newMember ??= RoomMember(
            idPubkey: senderPubkey, name: senderName, roomId: room.id);
        realMessage = 'Hi everyone, I\'m ${newMember.name}!';

        // room member self leaave group
        if (newMember.status == UserStatusType.removed) {
          realMessage =
              '[System] $senderName requests to leave the group chat.';
          bool isAdmin = await room.checkAdminByIdPubkey(room.myIdPubkey);
          if (isAdmin) {
            removeMembers(room, [newMember]);
          }
        }
        break;
      case CommitTypeResult.remove:
        List<String>? pubkeys = commitResult.operatedMembers;
        if (pubkeys == null) {
          realMessage = '[SystemError] remove members failed, pubkeys is null';
          break;
        }
        // if I'm removed
        if (pubkeys.contains(room.myIdPubkey)) {
          realMessage = '[System] You have been removed by admin.';
          room.status = RoomStatus.removedFromGroup;
          await RoomService.instance.updateRoomAndRefresh(room);
          break;
        }

        // if others removed
        List<String> diffMembers = [];
        for (String pubkey in pubkeys) {
          String memberName = before[pubkey]?.name ?? pubkey;
          diffMembers.add(memberName);
        }
        realMessage =
            '[System] $senderName reomved [${diffMembers.join(",")}] ';
        await RoomService.getController(room.id)?.setRoom(room).resetMembers();

        break;
      case CommitTypeResult.groupContextExtensions:
        var res = await _handleGroupInfo(room, event, queuedMsg);
        room = res.$1;
        realMessage = res.$2 ?? '[System] $senderName updated group info';
        break;
    }
    await RoomService.instance.receiveDM(room, event,
        senderPubkey: senderPubkey,
        encryptType: MessageEncryptType.mls,
        realMessage: realMessage,
        senderName: senderName);
  }

  Future<String> _selfUpdateKeyLocal(Room room,
      [Map<String, dynamic>? extension]) async {
    Map map = extension ?? {'name': room.getIdentity().displayName};
    return await rust_mls.selfUpdate(
        nostrId: room.getIdentity().secp256k1PKHex,
        groupId: room.toMainPubkey,
        extensions: utf8.encode(jsonEncode(map)));
  }

  Future _sendInviteMessage(
      {required Room groupRoom,
      required Map<String, String> users,
      required String mlsWelcome}) async {
    if (users.isEmpty) return;
    await RoomService.instance.checkRoomStatus(groupRoom);

    await _sendPrivateMessageToMembers(
        realMessage: 'Send invitation to [${users.values.join(',')}]',
        users: users,
        content: mlsWelcome,
        groupRoom: groupRoom,
        nip17Kind: EventKinds.mlsNipWelcome,
        additionalTags: [
          [EventKindTags.pubkey, groupRoom.toMainPubkey],
        ]);

    RoomService.getController(groupRoom.id)?.resetMembers();
  }

  // Send a group message to all enabled users
  Future _sendPrivateMessageToMembers(
      {required String content,
      required String realMessage,
      required Room groupRoom,
      required Map users,
      int nip17Kind = EventKinds.nip17,
      List<List<String>>? additionalTags}) async {
    List<NostrEventModel> events = [];
    Identity identity = groupRoom.getIdentity();

    for (var user in users.entries) {
      if (identity.secp256k1PKHex == user.key) continue;
      try {
        var smr = await NostrAPI.instance.sendNip17Message(
            groupRoom, content, identity,
            toPubkey: user.key,
            nip17Kind: nip17Kind,
            additionalTags: additionalTags,
            save: false);
        if (smr.events.isEmpty) continue;
        var toSaveEvent = smr.events[0];
        toSaveEvent.toIdPubkey = user.key;
        events.add(toSaveEvent);
      } catch (e, s) {
        logger.e(e.toString(), error: e, stackTrace: s);
      }
    }
    if (events.isEmpty) {
      throw Exception('Message Sent Failed');
    }

    Message message = Message(
      identityId: groupRoom.identityId,
      msgid: events[0].id,
      eventIds: events.map((e) => e.id).toList(),
      roomId: groupRoom.id,
      from: identity.secp256k1PKHex,
      idPubkey: identity.secp256k1PKHex,
      to: groupRoom.toMainPubkey,
      encryptType: MessageEncryptType.nip17,
      sent: SendStatusType.success,
      isSystem: true,
      isMeSend: true,
      content: realMessage,
      createdAt: timestampToDateTime(events[0].createdAt),
      rawEvents: events.map((e) {
        Map m = e.toJson();
        m['toIdPubkey'] = e.toIdPubkey;
        return jsonEncode(m);
      }).toList(),
    )..isRead = true;
    await MessageService.instance.saveMessageModel(message, room: groupRoom);
  }

  Future sendSelfLeaveMessage(Room room) async {
    var queuedMsg = await _selfUpdateKeyLocal(room, {
      'status': UserStatusType.removed.name,
      'name': room.getIdentity().displayName
    });
    String realMessage = 'I am exiting the group chat';
    await sendEncryptedMessage(room, queuedMsg,
        realMessage: realMessage, save: false);
  }

  Future waitingForEose({String? recevingKey, List<String>? relays}) async {
    if (recevingKey == null) return;
    await Utils.waitRelayOnline(defaultRelays: relays);
    String? subId =
        Get.find<WebsocketService>().getSubscriptionIdsByPubkey(recevingKey);
    if (subId == null) return;
    bool subEventEosed = NostrAPI.instance.subscriptionIdEose.contains(subId);
    int queryTimes = 0;
    while (!subEventEosed) {
      DateTime? last = NostrAPI.instance.subscriptionLastEvent[subId];
      // get a new events? pending for 500ms
      if (last == null ||
          last.isBefore(DateTime.now().subtract(const Duration(seconds: 1)))) {
        queryTimes++;
      }
      if (queryTimes > 3) {
        logger.e('Not Eose: $subId, but timeout');
        break;
      }

      await Future.delayed(const Duration(milliseconds: 500));
      subEventEosed = NostrAPI.instance.subscriptionIdEose.contains(subId);
    }
    logger.d('done for Eose: $subId');
  }
}
