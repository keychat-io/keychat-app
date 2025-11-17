import 'dart:async';
import 'dart:convert'
    show base64Decode, base64Encode, jsonDecode, jsonEncode, utf8;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:get/get.dart';
import 'package:keychat/constants.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/nostr-core/close.dart';
import 'package:keychat/nostr-core/nostr.dart';
import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat/nostr-core/nostr_nip4_req.dart';
import 'package:keychat/nostr-core/relay_websocket.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/service/chat.service.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/relay.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/service/signal_chat_util.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_mls.dart' as rust_mls;
import 'package:keychat_rust_ffi_plugin/api_mls/types.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class MlsGroupService extends BaseChatService {
  // Avoid self instance
  MlsGroupService._();
  static MlsGroupService? _instance;
  static String? dbPath;
  static MlsGroupService get instance => _instance ??= MlsGroupService._();

  Future<void> addMemeberToGroup(
    Room groupRoom,
    List<Map<String, dynamic>> toUsers, [
    String? sender,
  ]) async {
    final invalidPubkeys = await existExpiredMember(groupRoom);
    if (invalidPubkeys.isNotEmpty) {
      throw Exception(
        "${invalidPubkeys.join(', ')} 's key package is expired, please remove them first",
      );
    }
    final identity = groupRoom.getIdentity();
    final userNameMap = <String, String>{};
    final keyPackages = <String>[];
    for (final user in toUsers) {
      userNameMap[user['pubkey']] = user['name'] as String;
      final pk = user['mlsPK'] as String?;
      if (pk != null) {
        final valid = await checkPkIsValid(groupRoom, pk);
        if (!valid) {
          throw Exception('Key package for ${user['name']} is expired');
        }
        keyPackages.add(pk);
      }
    }
    if (keyPackages.isEmpty) {
      throw Exception('keyPackages is empty');
    }
    await RoomService.instance.checkWebsocketConnect();
    final data = await rust_mls.addMembers(
      nostrId: identity.secp256k1PKHex,
      groupId: groupRoom.toMainPubkey,
      keyPackages: keyPackages,
    );
    final welcomeMsg = base64Encode(data.welcome);
    // send sync message to other member
    groupRoom = await RoomService.instance.getRoomByIdOrFail(groupRoom.id);
    await sendEncryptedMessage(
      groupRoom,
      data.queuedMsg,
      realMessage:
          '[System] Invite [${userNameMap.values.join(', ')}] to join group',
    );
    await rust_mls.selfCommit(
      nostrId: identity.secp256k1PKHex,
      groupId: groupRoom.toMainPubkey,
    );
    groupRoom = await _proccessUpdateKeys(groupRoom);

    // send invitation message
    await _sendInviteMessage(
      groupRoom: groupRoom,
      users: userNameMap,
      mlsWelcome: welcomeMsg,
    );
  }

  Future<Room> createGroup(
    String groupName,
    Identity identity, {
    required List<Map<String, dynamic>> toUsers,
    required List<String> groupRelays,
    String? description,
  }) async {
    final randomKey = await rust_nostr.generateSimple();
    final toMainPubkey = randomKey.pubkey;
    final version = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var room =
        Room(
            toMainPubkey: toMainPubkey,
            npub: rust_nostr.getBech32PubkeyByHex(hex: toMainPubkey),
            identityId: identity.id,
            type: RoomType.group,
          )
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
      status: RoomStatus.enabled.name,
    );
    await _selfUpdateKeyLocal(room);
    await rust_mls.selfCommit(
      nostrId: identity.secp256k1PKHex,
      groupId: room.toMainPubkey,
    );

    final keyPackages = <String>[];
    for (final user in toUsers) {
      final pk = user['mlsPK'] as String;
      keyPackages.add(pk);
    }
    if (keyPackages.isEmpty) {
      throw Exception('keyPackages is empty');
    }
    final welcome = await rust_mls.addMembers(
      nostrId: identity.secp256k1PKHex,
      groupId: room.toMainPubkey,
      keyPackages: keyPackages,
    );
    await rust_mls.selfCommit(
      nostrId: identity.secp256k1PKHex,
      groupId: room.toMainPubkey,
    );
    room = await replaceListenPubkey(room);

    final welcomeMsg = base64Encode(welcome.welcome);

    final result = <String, String>{};
    for (final user in toUsers) {
      result[user['pubkey']] = user['name'] as String;
    }

    await _sendInviteMessage(
      groupRoom: room,
      users: result,
      mlsWelcome: welcomeMsg,
    );

    return room;
  }

  Future<Room> createGroupFromInvitation(
    NostrEventModel event,
    Identity identity,
    Message message, {
    required String groupId,
  }) async {
    var room =
        Room(
            toMainPubkey: groupId,
            npub: rust_nostr.getBech32PubkeyByHex(hex: groupId),
            identityId: identity.id,
            type: RoomType.group,
          )
          ..name = groupId.substring(0, 8)
          ..groupType = GroupType.mls
          ..version = event.createdAt;
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.messages.put(message);
      room.id = await DBProvider.database.rooms.put(room);
    });
    final welcome = base64Decode(event.content).toList();
    await rust_mls.joinMlsGroup(
      nostrId: identity.secp256k1PKHex,
      groupId: room.toMainPubkey,
      welcome: welcome,
    );
    final info = await getGroupExtension(room);
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
  Future<void> decryptMessage(
    Room room,
    NostrEventModel event,
    void Function(String) failedCallback,
  ) async {
    loggerNoLine.i(
      '[MLS] decryptMessage START - eventId: ${event.id}, roomId: ${room.id}',
    );

    final exist = await MessageService.instance.getMessageByEventId(event.id);
    if (exist != null) {
      loggerNoLine.i('[MLS] decryptMessage END - duplicate event: ${event.id}');
      return;
    }

    try {
      final messageType = await rust_mls.parseMlsMsgType(
        groupId: room.toMainPubkey,
        nostrId: room.myIdPubkey,
        data: event.content,
      );
      loggerNoLine.i(
        '[MLS] Message type parsed: ${messageType.name} for event: ${event.id}',
      );

      switch (messageType) {
        case MessageInType.commit:
          loggerNoLine.i('[MLS] Processing commit message: ${event.id}');
          await _proccessTryProposalIn(
            room,
            event,
            event.content,
            failedCallback,
          ).timeout(const Duration(seconds: 20));
          loggerNoLine.i(
            '[MLS] Commit message processed successfully: ${event.id}',
          );
        case MessageInType.application:
          loggerNoLine.i('[MLS] Processing application message: ${event.id}');
          await _proccessApplication(
            room,
            event,
            event.content,
            failedCallback,
          );
          loggerNoLine.i(
            '[MLS] Application message processed successfully: ${event.id}',
          );
        case MessageInType.proposal:
        case MessageInType.welcome:
        case MessageInType.groupInfo:
        case MessageInType.keyPackage:
        case MessageInType.publicMessage:
        case MessageInType.custom:
          logger.e(
            '[MLS] Unsupported message type: ${messageType.name} for event: ${event.id}',
          );
          throw Exception('Unsupported: ${messageType.name}');
      }
      loggerNoLine.i('[MLS] decryptMessage END - success: ${event.id}');
    } on TimeoutException catch (e, s) {
      final msg =
          'ProccessTryProposalIn timeout after 10s for event: ${event.id}';
      logger.e('[MLS] decrypt mls msg timeout: $msg', error: e, stackTrace: s);
      failedCallback(msg);
      await RoomUtil.appendMessageOrCreate(
        msg,
        room,
        'mls decrypt timeout',
        event,
      );
    } catch (e, s) {
      logger.e(
        '[MLS] decryptMessage ERROR for event: ${event.id}',
        error: e,
        stackTrace: s,
      );
      String? sender;
      try {
        loggerNoLine.i('[MLS] Getting sender for failed event: ${event.id}');
        sender = await rust_mls.getSender(
          nostrId: room.myIdPubkey,
          groupId: room.toMainPubkey,
          queuedMsg: event.content,
        );
        loggerNoLine.i(
          '[MLS] Sender retrieved: $sender for event: ${event.id}',
        );
      } catch (e) {
        logger.e('[MLS] Failed to get sender for event: ${event.id}', error: e);
      }
      final msg = '$sender ${Utils.getErrorMessage(e)}';
      logger.e('decrypt mls msg: $msg', error: e, stackTrace: s);
      failedCallback(msg);
    }
  }

  Future<void> dissolve(Room room) async {
    await RoomService.instance.checkWebsocketConnect();
    final res = await rust_mls.updateGroupContextExtensions(
      nostrId: room.myIdPubkey,
      groupId: room.toMainPubkey,
      status: RoomStatus.dissolved.name,
    );
    const realMessage = '[System] The admin closed the group chat';

    await sendEncryptedMessage(room, res, realMessage: realMessage);
    await RoomService.instance.deleteRoom(room);
  }

  Future<GroupExtension> getGroupExtension(Room room) async {
    final ger = await rust_mls.getGroupExtension(
      nostrId: room.myIdPubkey,
      groupId: room.toMainPubkey,
    );

    return GroupExtension(
      name: utf8.decode(ger.name),
      description: utf8.decode(ger.description),
      admins: ger.adminPubkeys.map((e) => utf8.decode(e)).toList(),
      relays: ger.relays.map((e) => utf8.decode(e)).toList(),
      status: utf8.decode(ger.status),
    );
  }

  Future<Map<String, String>> getKeyPackagesFromRelay(
    List<String> pubkeys,
  ) async {
    final ws = Get.find<WebsocketService>();
    if (pubkeys.isEmpty) return {};

    final req = NostrReqModel(
      reqId: generate64RandomHexChars(16),
      authors: pubkeys,
      kinds: [EventKinds.mlsNipKeypackages],
      limit: pubkeys.length,
      since: DateTime.now().subtract(const Duration(days: 90)),
    );
    final list = await ws.fetchInfoFromRelay(
      req.reqId,
      req.toString(),
      waitTimeToFill: true,
    );
    // close req
    Get.find<WebsocketService>().sendReqToRelays(Close(req.reqId).serialize());

    final filteredMap = <String, NostrEventModel>{};
    for (final event in list) {
      final existing = filteredMap[event.pubkey];
      if (existing == null || event.createdAt > existing.createdAt) {
        filteredMap[event.pubkey] = event;
      }
    }

    final result = <String, String>{};
    for (final event in filteredMap.values) {
      result[event.pubkey] = event.content;
    }
    loggerNoLine.i('PKs: $result');
    return result;
  }

  Future<String?> getKeyPackageFromRelay({
    required String pubkey,
    String? toRelay,
  }) async {
    final ws = Get.find<WebsocketService>();

    try {
      final req = NostrReqModel(
        reqId: generate64RandomHexChars(16),
        authors: [pubkey],
        kinds: [EventKinds.mlsNipKeypackages],
        limit: 1,
        since: DateTime.now().subtract(const Duration(days: 90)),
      );
      RelayWebsocket? websocket;
      if (toRelay != null) {
        websocket = ws.channels[toRelay];
      }
      final list = await ws.fetchInfoFromRelay(
        req.reqId,
        req.toString(),
        waitTimeToFill: true,
        sockets: websocket != null ? [websocket] : null,
      );
      // close req

      ws.sendReqToRelays(Close(req.reqId).serialize());

      if (list.isEmpty) return null;
      return list[0].content;
    } catch (e, s) {
      logger.e(
        'Error getting key package from relay: $e',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  Future<Map<String, RoomMember>> getMembers(Room room) async {
    final roomMembers = <String, RoomMember>{};
    final extensions = await rust_mls.getMemberExtension(
      nostrId: room.myIdPubkey,
      groupId: room.toMainPubkey,
    );
    final lifeTimes = await rust_mls.getGroupMembersWithLifetime(
      nostrId: room.myIdPubkey,
      groupId: room.toMainPubkey,
    );
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final element in extensions.entries) {
      String? name;
      var status = UserStatusType.invited;
      String? msg;
      if (element.value.isNotEmpty) {
        try {
          final res = utf8.decode(element.value[0]);
          final extension = jsonDecode(res) as Map<String, dynamic>;
          name = extension['name'] as String?;
          msg = extension['msg'] as String?;
          if (extension['status'] != null) {
            status = UserStatusType.values.firstWhere(
              (e) => e.name == extension['status'],
            );
          }
        } catch (e) {
          logger.e('getMembers: $e');
        }
      }
      var mlsPKExpired = false;
      if (lifeTimes[element.key] != null) {
        final lifetime = lifeTimes[element.key];
        if (lifetime != null && lifetime > BigInt.zero) {
          final expireTime = lifetime.toInt() * 1000;
          if (expireTime < now) {
            mlsPKExpired = true;
          }
        }
      }
      roomMembers[element.key] =
          RoomMember(
              idPubkey: element.key,
              name: name,
              roomId: room.id,
              status: status,
            )
            ..mlsPKExpired = mlsPKExpired
            ..msg = msg;
    }
    return roomMembers;
  }

  Future<String> getShareInfo(Room room) async {
    final map = {
      'name': room.name,
      'pubkey': room.toMainPubkey,
      'type': room.groupType.name,
      'myPubkey': room.myIdPubkey,
      'time': DateTime.now().millisecondsSinceEpoch,
    };

    final contentToSign = jsonEncode([
      map['pubkey'],
      map['type'],
      map['myPubkey'],
      map['time'],
    ]);
    final signature = await SignalChatUtil.signByIdentity(
      identity: room.getIdentity(),
      content: contentToSign,
    );
    if (signature == null) {
      throw Exception('Sign failed or User denied');
    }
    map['signature'] = signature;

    return jsonEncode(map);
  }

  // kind 444
  Future<void> handleWelcomeEvent({
    required NostrEventModel subEvent,
    required NostrEventModel sourceEvent,
    required Relay relay,
  }) async {
    loggerNoLine.i('subEvent $subEvent');
    final senderIdPubkey = subEvent.pubkey;
    final myIdPubkey =
        (sourceEvent.getTagByKey(EventKindTags.pubkey) ??
        sourceEvent.getTagByKey(EventKindTags.pubkey))!;
    final idRoom = await RoomService.instance.getOrCreateRoom(
      subEvent.pubkey,
      myIdPubkey,
      RoomStatus.enabled,
    );
    final identity = idRoom.getIdentity();
    if (senderIdPubkey == identity.secp256k1PKHex) {
      loggerNoLine.i('Event sent by me: ${subEvent.id}');
      return;
    }
    final pubkey = subEvent.getTagByKey(EventKindTags.pubkey);
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
      realMessage: 'Invite you to join group',
    );
  }

  Future<void> initDB(String path) async {
    dbPath = path;
    await initIdentities();
  }

  Future<void> initIdentities([List<Identity>? identities]) async {
    if (dbPath == null) {
      throw Exception('MLS dbPath is null');
    }
    identities ??= await IdentityService.instance.getIdentityList();

    for (final identity in identities) {
      try {
        await rust_mls.initMlsDb(
          dbPath: '$dbPath${KeychatGlobal.mlsDBFile}',
          nostrId: identity.secp256k1PKHex,
        );
        loggerNoLine.i('MLS init for identity: ${identity.secp256k1PKHex}');
      } catch (e, s) {
        logger.e(
          'Init MLS Failed: ${identity.secp256k1PKHex} $e',
          error: e,
          stackTrace: s,
        );
      }
    }
  }

  @Deprecated('use proccessMLSPrososalMessage instead')
  @override
  Future<void> proccessMessage({
    required Room room,
    required NostrEventModel event,
    required KeychatMessage km,
    NostrEventModel? sourceEvent,
    void Function(String error)? failedCallback,
    String? msgKeyHash,
    String? fromIdPubkey,
  }) async {
    throw Exception('Deprecated');
  }

  Future<Room> _proccessUpdateKeys(Room groupRoom, [int? version]) async {
    if (version != null) {
      groupRoom.version = version;
    }
    groupRoom = await replaceListenPubkey(groupRoom);
    RoomService.getController(groupRoom.id)
      ?..setRoom(groupRoom)
      ..resetMembers();
    return groupRoom;
  }

  Future<void> removeMembers(Room room, List<RoomMember> list) async {
    await waitingForEose(
      receivingKey: room.onetimekey,
      relays: room.sendingRelays,
    );
    await RoomService.instance.checkWebsocketConnect();
    final identity = room.getIdentity();
    final idPubkeys = <String>[];
    final names = <String>[];
    final bLeafNodes = <Uint8List>[];
    for (final rm in list) {
      idPubkeys.add(rm.idPubkey);
      names.add(rm.displayName);
      final bLeafNode = await rust_mls.getLeadNodeIndex(
        nostrIdAdmin: identity.secp256k1PKHex,
        nostrIdCommon: rm.idPubkey,
        groupId: room.toMainPubkey,
      );
      bLeafNodes.add(bLeafNode);
    }
    final queuedMsg = await rust_mls.removeMembers(
      nostrId: identity.secp256k1PKHex,
      groupId: room.toMainPubkey,
      members: bLeafNodes,
    );

    final realMessage =
        '[System] Admin remove the ${names.length > 1 ? 'members' : 'member'}: ${names.join(',')}';

    room = await RoomService.instance.getRoomByIdOrFail(room.id);
    await sendEncryptedMessage(room, queuedMsg, realMessage: realMessage);
    await rust_mls.selfCommit(
      nostrId: identity.secp256k1PKHex,
      groupId: room.toMainPubkey,
    );
    room = await replaceListenPubkey(room);
    RoomService.getController(room.id)
      ?..setRoom(room)
      ..resetMembers();
  }

  Future<Room> replaceListenPubkey(Room room) async {
    loggerNoLine.i(
      '[MLS] replaceListenPubkey START - roomId: ${room.id}, currentKey: ${room.onetimekey}',
    );
    final newPubkey = await rust_mls
        .getListenKeyFromExportSecret(
          nostrId: room.myIdPubkey,
          groupId: room.toMainPubkey,
        )
        .timeout(const Duration(seconds: 2));

    if (newPubkey == room.onetimekey) {
      loggerNoLine.i(
        '[MLS] replaceListenPubkey END - no change for room: ${room.id}',
      );
      await RoomService.instance.updateRoomAndRefresh(room);
      return room;
    }

    loggerNoLine.i(
      '[MLS] new pubkey for room: ${room.toMainPubkey}, '
      'old: ${room.onetimekey}, new: $newPubkey',
    );
    final toDeletePubkey = room.onetimekey;
    await waitingForEose(
      receivingKey: room.onetimekey,
      relays: room.sendingRelays,
    );
    room.onetimekey = newPubkey;
    loggerNoLine.i(
      '[MLS] Updating room with new key $newPubkey for room: ${room.id}',
    );
    await RoomService.instance.updateRoomAndRefresh(room);
    loggerNoLine.i('[MLS] Room updated with new key for room: ${room.id}');

    final ws = Get.find<WebsocketService>();
    if (toDeletePubkey != null) {
      ws.removePubkeyFromSubscription(toDeletePubkey);
      if (!room.isMute) {
        NotifyService.instance.removePubkeys([toDeletePubkey]);
      }
    }
    ws.listenPubkeyNip17(
      [newPubkey],
      since: DateTime.fromMillisecondsSinceEpoch(
        room.version * 1000,
      ).subtract(const Duration(seconds: 3)),
      relays: room.sendingRelays,
    );

    if (!room.isMute) {
      unawaited(NotifyService.instance.addPubkeys([newPubkey]));
    }
    loggerNoLine.i(
      '[MLS] replaceListenPubkey END - success for room: ${room.id}',
    );
    return room;
  }

  Future<void> sendGreetingMessage(Room room) async {
    room.sentHelloToMLS = true;
    final identity = room.getIdentity();
    final msg = '[System] Hello everyone! I am ${identity.displayName}';
    await selfUpdateKey(
      room,
      extension: {
        'name': identity.displayName,
        'msg': msg,
      },
      msg: msg,
    );
  }

  Future<Room> selfUpdateKey(
    Room room, {
    required String msg,
    Map<String, dynamic>? extension,
  }) async {
    // waiting for the old pubkey to be Eosed. means that all events proccessed
    await waitingForEose(
      receivingKey: room.onetimekey,
      relays: room.sendingRelays,
    );
    await RoomService.instance.checkWebsocketConnect();
    final queuedMsg = await _selfUpdateKeyLocal(room, extension);
    final identity = room.getIdentity();
    await sendEncryptedMessage(room, queuedMsg, realMessage: msg);
    await rust_mls.selfCommit(
      nostrId: identity.secp256k1PKHex,
      groupId: room.toMainPubkey,
    );
    final room0 = await replaceListenPubkey(room);
    await RoomService.getController(room.id)?.resetMembers();

    return room0;
  }

  Future<SendMessageResponse> sendEncryptedMessage(
    Room room,
    String message, {
    bool save = true,
    MessageMediaType? mediaType,
    String? realMessage,
    List<List<String>>? additionalTags,
  }) async {
    if (room.onetimekey == null) {
      throw Exception('Receiving pubkey is null');
    }

    final randomAccount = await rust_nostr.generateSimple();
    final smr = await NostrAPI.instance.sendEventMessage(
      room.onetimekey!,
      message,
      prikey: randomAccount.prikey,
      from: randomAccount.pubkey,
      room: room,
      mediaType: mediaType,
      encryptType: MessageEncryptType.mls,
      kind: EventKinds.nip17,
      save: save,
      sourceContent: message,
      isSystem: true,
      realMessage: realMessage,
      isEncryptedMessage: true,
      additionalTags:
          additionalTags ??
          [
            [EventKindTags.pubkey, room.onetimekey!],
          ],
    );
    return smr;
  }

  Future<void> sendJoinGroupRequest(
    GroupInvitationModel gim,
    Identity identity,
  ) async {
    if (gim.pubkey == identity.secp256k1PKHex) {
      throw Exception('You are already in this group');
    }
    final girm = GroupInvitationRequestModel(
      name: gim.name,
      roomPubkey: gim.pubkey,
      myPubkey: identity.secp256k1PKHex,
      myName: identity.displayName,
      time: DateTime.now().millisecondsSinceEpoch,
      mlsPK: '',
      sig: '',
    );
    var room = await RoomService.instance.getRoomByIdentity(
      gim.sender,
      identity.id,
    );
    if (room == null) {
      room = await RoomService.instance.createRoomAndsendInvite(
        gim.sender,
        identity: identity,
        autoJump: false,
      );
      await Future.delayed(const Duration(seconds: 1));
    }
    if (room == null) {
      throw Exception('Room not found or create failed');
    }
    final sm =
        KeychatMessage(
            c: MessageType.mls,
            type: KeyChatEventKinds.groupInvitationRequesting,
          )
          ..name = girm.toString()
          ..msg = 'Request to join group: ${gim.name}';
    await RoomService.instance.sendMessage(
      room,
      sm.toString(),
      realMessage: sm.msg,
    );
  }

  @override
  Future<SendMessageResponse> sendMessage(
    Room room,
    String message, {
    MessageMediaType? mediaType,
    bool save = true,
    MsgReply? reply,
    String? realMessage,
  }) async {
    if (reply != null) {
      message = KeychatMessage.getTextMessage(MessageType.mls, message, reply);
    }
    if (room.onetimekey == null) {
      throw Exception('Receiving pubkey is null');
    }
    final identity = room.getIdentity();
    final enctypted = await rust_mls.createMessage(
      nostrId: identity.secp256k1PKHex,
      groupId: room.toMainPubkey,
      msg: message,
    );

    // refresh onetime key
    if (realMessage != null) {
      room = await RoomService.instance.getRoomByIdOrFail(room.id);
    }
    final randomAccount = await rust_nostr.generateSimple();
    final smr = await NostrAPI.instance.sendEventMessage(
      room.onetimekey!,
      enctypted.encryptMsg,
      prikey: randomAccount.prikey,
      from: randomAccount.pubkey,
      room: room,
      encryptType: MessageEncryptType.mls,
      kind: EventKinds.nip17,
      additionalTags: [
        [EventKindTags.pubkey, room.onetimekey!],
      ],
      save: save,
      mediaType: mediaType,
      sourceContent: message,
      realMessage: realMessage,
      reply: reply,
      isEncryptedMessage: true,
    );
    return smr;
  }

  Future<void> shareToFriends(
    Room room,
    List<Room> toUsers,
    String realMessage,
  ) async {
    final gim = GroupInvitationModel(
      name: room.name ?? room.toMainPubkey,
      pubkey: room.toMainPubkey,
      sender: room.myIdPubkey,
      time: DateTime.now().millisecondsSinceEpoch,
      sig: '',
    );
    final sm =
        KeychatMessage(
            c: MessageType.mls,
            type: KeyChatEventKinds.groupInvitationInfo,
          )
          ..name = gim.toString()
          ..msg = realMessage;
    await RoomService.instance.sendMessageToMultiRooms(
      message: sm.toString(),
      realMessage: sm.msg!,
      rooms: toUsers,
      identity: room.getIdentity(),
      mediaType: MessageMediaType.groupInvitationInfo,
    );
  }

  Future<Room> updateGroupName(Room room, String newName) async {
    await waitingForEose(
      receivingKey: room.onetimekey,
      relays: room.sendingRelays,
    );
    await RoomService.instance.checkWebsocketConnect();
    final res = await rust_mls.updateGroupContextExtensions(
      nostrId: room.myIdPubkey,
      groupId: room.toMainPubkey,
      groupName: newName,
    );
    await sendEncryptedMessage(
      room,
      res,
      realMessage: '[System] Update group name to: $newName',
    );
    await rust_mls.selfCommit(
      nostrId: room.myIdPubkey,
      groupId: room.toMainPubkey,
    );
    return replaceListenPubkey(room);
  }

  Future<void> uploadKeyPackages({
    required List<Identity> identities,
    bool forceUpload = false,
    String? toRelay,
  }) async {
    await Utils.waitRelayOnline();
    final onlineRelays = Get.find<WebsocketService>().getOnlineSocketString();
    if (onlineRelays.isEmpty) {
      throw Exception('No relays available');
    }

    for (final identity in identities) {
      var needsUpload = forceUpload;

      if (!forceUpload) {
        // Check from relay if key package exists and is not expired
        final existingPK = await getKeyPackageFromRelay(
          pubkey: identity.secp256k1PKHex,
          toRelay: toRelay,
        );

        if (existingPK == null) {
          // No key package found on relay, need to upload
          needsUpload = true;
          loggerNoLine.i(
            'No key package found on relay for identity: ${identity.secp256k1PKHex}',
          );
        } else {
          // Query the event from relay to check creation time
          final ws = Get.find<WebsocketService>();
          final req = NostrReqModel(
            reqId: generate64RandomHexChars(16),
            authors: [identity.secp256k1PKHex],
            kinds: [EventKinds.mlsNipKeypackages],
            limit: 1,
            since: DateTime.now().subtract(const Duration(days: 90)),
          );
          final list = await ws.fetchInfoFromRelay(
            req.reqId,
            req.toString(),
            waitTimeToFill: true,
          );
          ws.sendReqToRelays(Close(req.reqId).serialize());
          // TODOcheck the kp is used?
          if (list.isNotEmpty) {
            final event = list[0];
            final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            final eventAge = now - event.createdAt;
            const thirtyDays = 30 * 24 * 60 * 60;

            if (eventAge >= thirtyDays) {
              needsUpload = true;
              loggerNoLine.i(
                'Key package expired (>30 days) for identity: ${identity.secp256k1PKHex}',
              );
            } else {
              loggerNoLine.i(
                'Key package still valid for identity: ${identity.secp256k1PKHex}',
              );
              continue;
            }
          } else {
            needsUpload = true;
          }
        }
      }

      if (!needsUpload) {
        continue;
      }

      loggerNoLine.i(
        'Uploading key package for identity: ${identity.secp256k1PKHex}',
      );
      final event = await _createKeyPackageEvent(identity, onlineRelays);

      Get.find<WebsocketService>().sendMessageWithCallback(
        '["EVENT",$event]',
        callback:
            ({
              required String relay,
              required String eventId,
              required bool status,
              String? errorMessage,
            }) async {
              final isDuplicate =
                  errorMessage?.toLowerCase().startsWith('duplicate') ?? false;
              if (status || isDuplicate) {
                loggerNoLine.i(
                  'Key package uploaded successfully to $relay: ${identity.secp256k1PKHex}',
                );
              } else {
                logger.w(
                  'Key package upload failed to $relay: ${identity.secp256k1PKHex}, error: $errorMessage',
                );
              }
              NostrAPI.instance.removeOKCallback(eventId);
            },
      );
    }
  }

  Future<(Room, String?)> _handleGroupInfo(
    Room room,
    NostrEventModel event,
    String queuedMsg,
  ) async {
    final info = await getGroupExtension(room);
    if (info.status == RoomStatus.dissolved.name) {
      room.status = RoomStatus.dissolved;
      const toSaveMsg = '[System] The admin closed this group chat';
      await RoomService.instance.updateRoomAndRefresh(room);
      return (room, toSaveMsg);
    }
    room
      ..name = info.name
      ..description = info.description
      ..sendingRelays = info.relays;
    await RelayService.instance.addOrActiveRelay(info.relays);
    return (await replaceListenPubkey(room), null);
  }

  Future<void> _proccessApplication(
    Room room,
    NostrEventModel event,
    String decoded,
    void Function(String) failedCallback,
  ) async {
    loggerNoLine.i('[MLS] Decrypting message for event: ${event.id}');
    final decryptedMsg = await rust_mls.decryptMessage(
      nostrId: room.myIdPubkey,
      groupId: room.toMainPubkey,
      msg: decoded,
    );
    loggerNoLine.i(
      '[MLS] Message decrypted, sender: ${decryptedMsg.sender}, event: ${event.id}',
    );

    final sender = await room.getMemberByIdPubkey(decryptedMsg.sender);
    loggerNoLine.i(
      '[MLS] Sender member found: ${sender?.name ?? 'null'} for event: ${event.id}',
    );

    KeychatMessage? km;
    try {
      km = KeychatMessage.fromJson(jsonDecode(decryptedMsg.decryptMsg));
      // ignore: empty_catches
    } catch (e) {}

    await RoomService.instance.receiveDM(
      room,
      event,
      km: km,
      decodedContent: decryptedMsg.decryptMsg,
      senderPubkey: decryptedMsg.sender,
      encryptType: MessageEncryptType.mls,
      senderName: sender?.name ?? decryptedMsg.sender,
    );
  }

  Future<void> _proccessTryProposalIn(
    Room room,
    NostrEventModel event,
    String queuedMsg,
    void Function(String) failedCallback,
  ) async {
    final res = await rust_mls.getSender(
      nostrId: room.myIdPubkey,
      groupId: room.toMainPubkey,
      queuedMsg: queuedMsg,
    );
    if (res == null) {
      logger.e('[MLS] Sender not found for event: ${event.id}');
      throw Exception('Sender not found. ${event.id}');
    }
    final senderPubkey = res;
    loggerNoLine.i('[MLS] Sender found: $senderPubkey for event: ${event.id}');

    final sender = await room.getMemberByIdPubkey(senderPubkey);
    final senderName = sender?.name ?? senderPubkey;
    loggerNoLine.i('[MLS] Sender member: $senderName for event: ${event.id}');
    final before = await getMembers(room);
    final commitResult = await rust_mls.othersCommitNormal(
      nostrId: room.myIdPubkey,
      groupId: room.toMainPubkey,
      queuedMsg: queuedMsg,
    );

    final isMeRemoved =
        commitResult.commitType == CommitTypeResult.remove &&
        (commitResult.operatedMembers ?? []).contains(room.myIdPubkey);
    loggerNoLine.i('[MLS] isMeRemoved: $isMeRemoved for event: ${event.id}');

    if (!isMeRemoved) {
      room = await _proccessUpdateKeys(room, event.createdAt);
      loggerNoLine.i('[MLS] Update keys processed for event: ${event.id}');
    }

    String? realMessage;
    switch (commitResult.commitType) {
      case CommitTypeResult.add:
        loggerNoLine.i('[MLS] Processing ADD commit for event: ${event.id}');
        final pubkeys = commitResult.operatedMembers;
        if (pubkeys == null) {
          logger.e('[MLS] pubkeys is null for ADD commit, event: ${event.id}');
          throw Exception('pubkeys is null');
        }
        loggerNoLine.i(
          '[MLS] Added ${pubkeys.length} members for event: ${event.id}',
        );
        final diffMembers = <String>[];
        for (final pubkey in pubkeys) {
          final member = await room.getMemberByIdPubkey(pubkey);
          diffMembers.add(member?.name ?? pubkey);
        }
        realMessage =
            '[System] $senderName added [${diffMembers.join(",")}] to the group';
      case CommitTypeResult.update:
        loggerNoLine.i('[MLS] Processing UPDATE commit for event: ${event.id}');
        await RoomService.getController(room.id)?.resetMembers();
        var newMember = await room.getMemberByIdPubkey(senderPubkey);
        newMember ??= RoomMember(
          idPubkey: senderPubkey,
          name: senderName,
          roomId: room.id,
        );
        realMessage =
            newMember.msg ?? "[System] Hi everyone, I'm ${newMember.name}!";

        // room member self leave group
        if (newMember.status == UserStatusType.removed) {
          loggerNoLine.i(
            '[MLS] Member requests to leave: $senderName for event: ${event.id}',
          );
          realMessage =
              '[System] $senderName requests to leave the group chat.';
          final isAdmin = await room.checkAdminByIdPubkey(room.myIdPubkey);
          if (isAdmin) {
            loggerNoLine.i(
              '[MLS] Admin removing member: $senderName for event: ${event.id}',
            );
            await removeMembers(room, [newMember]);
            loggerNoLine.i(
              '[MLS] Member removed: $senderName for event: ${event.id}',
            );
          }
        }
      case CommitTypeResult.remove:
        loggerNoLine.i('[MLS] Processing REMOVE commit for event: ${event.id}');
        final pubkeys = commitResult.operatedMembers;
        if (pubkeys == null) {
          logger.e(
            '[MLS] pubkeys is null for REMOVE commit, event: ${event.id}',
          );
          realMessage = '[SystemError] remove members failed, pubkeys is null';
          break;
        }
        loggerNoLine.i(
          '[MLS] Removed ${pubkeys.length} members for event: ${event.id}',
        );
        // if I'm removed
        if (pubkeys.contains(room.myIdPubkey)) {
          logger.w('[MLS] I was removed from group for event: ${event.id}');
          realMessage = '[System] You have been removed by admin.';
          room.status = RoomStatus.removedFromGroup;
          await RoomService.instance.updateRoomAndRefresh(room);
          break;
        }

        // if others removed
        final diffMembers = <String>[];
        for (final pubkey in pubkeys) {
          final memberName = before[pubkey]?.name ?? pubkey;
          diffMembers.add(memberName);
        }
        realMessage =
            '[System] $senderName removed [${diffMembers.join(",")}] ';
        RoomService.getController(room.id)
          ?..setRoom(room)
          ..resetMembers();

      case CommitTypeResult.groupContextExtensions:
        loggerNoLine.i(
          '[MLS] Processing GROUP_CONTEXT_EXTENSIONS commit for event: ${event.id}',
        );
        final res = await _handleGroupInfo(room, event, queuedMsg);
        room = res.$1;
        realMessage = res.$2 ?? '[System] $senderName updated group info';
    }

    await RoomService.instance.receiveDM(
      room,
      event,
      senderPubkey: senderPubkey,
      encryptType: MessageEncryptType.mls,
      realMessage: realMessage,
      senderName: senderName,
    );
  }

  Future<String> _selfUpdateKeyLocal(
    Room room, [
    Map<String, dynamic>? extension,
  ]) async {
    var map = extension ?? {};
    final identity = room.getIdentity();
    if (extension == null) {
      map = {
        'name': identity.displayName,
      };
    }
    return rust_mls.selfUpdate(
      nostrId: identity.secp256k1PKHex,
      groupId: room.toMainPubkey,
      extensions: utf8.encode(jsonEncode(map)),
    );
  }

  Future<void> _sendInviteMessage({
    required Room groupRoom,
    required Map<String, String> users,
    required String mlsWelcome,
  }) async {
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
      ],
    );

    RoomService.getController(groupRoom.id)?.resetMembers();
  }

  // Send a group message to all enabled users
  Future<void> _sendPrivateMessageToMembers({
    required String content,
    required String realMessage,
    required Room groupRoom,
    required Map users,
    int nip17Kind = EventKinds.nip17,
    List<List<String>>? additionalTags,
  }) async {
    final events = <NostrEventModel>[];
    final identity = groupRoom.getIdentity();
    String? errorMessage;
    for (final user in users.entries) {
      if (identity.secp256k1PKHex == user.key) continue;
      try {
        final smr = await NostrAPI.instance.sendNip17Message(
          groupRoom,
          content,
          identity,
          toPubkey: user.key as String,
          nip17Kind: nip17Kind,
          additionalTags: additionalTags,
          save: false,
        );
        if (smr.events.isEmpty) continue;
        final toSaveEvent = smr.events[0];
        toSaveEvent.toIdPubkey = user.key as String;
        events.add(toSaveEvent);
      } catch (e, s) {
        final msg = Utils.getErrorMessage(e);
        logger.e(msg, error: e, stackTrace: s);
        errorMessage = msg;
      }
    }
    if (events.isEmpty) {
      throw Exception(errorMessage ?? 'Message Sent Failed');
    }

    final message = Message(
      identityId: groupRoom.identityId,
      msgid: events[0].id,
      eventIds: events.map((e) => e.id).toList(),
      roomId: groupRoom.id,
      from: identity.secp256k1PKHex,
      idPubkey: identity.secp256k1PKHex,
      to: groupRoom.toMainPubkey,
      encryptType: MessageEncryptType.nip17,
      sent: SendStatusType.sending,
      isSystem: true,
      isMeSend: true,
      content: realMessage,
      createdAt: timestampToDateTime(events[0].createdAt),
      rawEvents: events.map((e) {
        final m = e.toJson();
        m['toIdPubkey'] = e.toIdPubkey;
        return jsonEncode(m);
      }).toList(),
    )..isRead = true;
    await MessageService.instance.saveMessageModel(message, room: groupRoom);
  }

  Future<void> sendSelfLeaveMessage(Room room) async {
    await RoomService.instance.checkWebsocketConnect();
    final queuedMsg = await _selfUpdateKeyLocal(room, {
      'status': UserStatusType.removed.name,
      'name': room.getIdentity().displayName,
    });
    const realMessage = '[System] I am exiting the group chat';
    await sendEncryptedMessage(
      room,
      queuedMsg,
      realMessage: realMessage,
      save: false,
    );
  }

  Future<void> waitingForEose({
    String? receivingKey,
    List<String>? relays,
  }) async {
    if (receivingKey == null) return;
    await Utils.waitRelayOnline(defaultRelays: relays);
    final subId = Get.find<WebsocketService>().getSubscriptionIdsByPubkey(
      receivingKey,
    );
    if (subId == null) return;

    var lastEventTime = NostrAPI.instance.subscriptionLastEvent[subId];
    var lastChangeTime = DateTime.now();

    while (true) {
      // Check if EOSE received
      final currentEosed = NostrAPI.instance.subscriptionIdEose.contains(subId);

      // Check if event time has changed
      final currentEventTime = NostrAPI.instance.subscriptionLastEvent[subId];
      final hasNewEvent = currentEventTime != lastEventTime;

      // Update tracking variables if we got new events
      if (hasNewEvent) {
        lastEventTime = currentEventTime;
        lastChangeTime = DateTime.now();
        logger.d('New event detected for receivingKey: $receivingKey');
      }

      // Exit condition 1: EOSE received and no new messages for 1 second
      if (currentEosed &&
          DateTime.now().difference(lastChangeTime).inSeconds >= 1) {
        logger.d(
          'EOSE received and no new events for 1s for receivingKey: $receivingKey',
        );
        break;
      }

      // Exit condition 2: No EOSE but no new messages for 2 seconds (timeout)
      if (!currentEosed &&
          DateTime.now().difference(lastChangeTime).inSeconds >= 2) {
        logger.w(
          'No EOSE received but no new events for 2s for receivingKey: $receivingKey',
        );
        break;
      }

      await Future.delayed(const Duration(milliseconds: 400));
    }

    logger.d(
      'Done waiting for events on receivingKey: $receivingKey, EOSE: ${NostrAPI.instance.subscriptionIdEose.contains(subId)}',
    );
  }

  // Generate and sign new key package event for kind 10443
  Future<String> _createKeyPackageEvent(
    Identity identity,
    List<String> onlineRelays,
  ) async {
    final pkRes = await rust_mls.createKeyPackage(
      nostrId: identity.secp256k1PKHex,
    );

    final event = await NostrAPI.instance.signEventByIdentity(
      identity: identity,
      content: pkRes.keyPackage,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      kind: EventKinds.mlsNipKeypackages,
      tags: [
        ['mls_protocol_version', pkRes.mlsProtocolVersion],
        ['ciphersuite', pkRes.ciphersuite],
        ['extensions', pkRes.extensions],
        ['client', KeychatGlobal.appName],
        ['relay', ...onlineRelays],
      ],
    );
    return event;
  }

  Future<void> fixMlsOnetimeKey(List<Room> rooms) async {
    await Utils.waitRelayOnline();
    for (final room in rooms) {
      try {
        while (true) {
          final cc = RoomService.getController(room.id);
          if (cc == null) break;
          await Future.delayed(const Duration(seconds: 1));
          if (DateTime.now().difference(cc.lastMessageAddedAt).inSeconds > 2) {
            loggerNoLine.i('[MLS] Waiting for room ${room.id} to be ready');
            break;
          }
        }

        // no any new messages
        final newPubkey = await rust_mls
            .getListenKeyFromExportSecret(
              nostrId: room.myIdPubkey,
              groupId: room.toMainPubkey,
            )
            .timeout(const Duration(seconds: 2));
        logger.i('[MLS] Fetched new pubkey for room ${room.id}: $newPubkey');
        if (room.onetimekey == null || room.onetimekey != newPubkey) {
          loggerNoLine.i('[MLS] Room ${room.id} update onetime key $newPubkey');
          room.onetimekey = newPubkey;
          await RoomService.instance.updateRoomAndRefresh(room);
          Get.find<WebsocketService>().listenPubkeyNip17(
            [newPubkey],
            since: DateTime.fromMillisecondsSinceEpoch(
              room.version * 1000,
            ).subtract(const Duration(seconds: 3)),
            relays: room.sendingRelays,
          );

          if (!room.isMute) {
            NotifyService.instance.addPubkeys([newPubkey]);
          }
        }
      } catch (e) {
        logger.e('[MLS] Failed to get new pubkey for room ${room.id}: $e');
      }
    }
  }

  Future<bool> checkPkIsValid(Room room, String pk) async {
    final nostrId = room.getIdentity().secp256k1PKHex;
    final lifetime = await rust_mls.parseLifetimeFromKeyPackage(
      nostrId: nostrId,
      keyPackageHex: pk,
    );
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (lifetime > BigInt.zero) {
      return lifetime.toInt() > now;
    }
    return false;
  }

  Future<List<String>> existExpiredMember(Room room) async {
    final lifeTimes = await rust_mls.getGroupMembersWithLifetime(
      nostrId: room.myIdPubkey,
      groupId: room.toMainPubkey,
    );
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return lifeTimes.entries
        .where((entry) => entry.value != null && entry.value!.toInt() < now)
        .map((entry) => entry.key)
        .toList();
  }
}
