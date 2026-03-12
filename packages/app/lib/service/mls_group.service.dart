import 'dart:async';
import 'dart:convert'
    show base64Decode, base64Encode, jsonDecode, jsonEncode, utf8;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:get/get.dart';
import 'package:keychat/constants.dart';
import 'package:keychat/exceptions/expired_members_exception.dart';
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

  /// Adds one or more members to an existing MLS group.
  ///
  /// Validates each member's key package freshness before adding.
  /// Sends an MLS commit message to the group, then sends individual
  /// Welcome messages to the newly added members.
  ///
  /// [groupRoom] is the target MLS group. [toUsers] is a list of user maps
  /// with keys 'pubkey', 'name', and 'mlsPK' (base64-encoded MLS key package).
  ///
  /// Throws [ExpiredMembersException] if any current group member's key package
  /// has expired. Throws [Exception] if [keyPackages] is empty or invalid.
  Future<void> addMemberToGroup(
    Room groupRoom,
    List<Map<String, dynamic>> toUsers, [
    String? sender,
  ]) async {
    await existExpiredMember(groupRoom);
    final identity = groupRoom.getIdentity();
    final userNameMap = <String, String>{};
    final keyPackages = <String>[];
    for (final user in toUsers) {
      userNameMap[user['pubkey'] as String] = user['name'] as String;
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
      nostrId: identity.nostrIdentityKey,
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
      nostrId: identity.nostrIdentityKey,
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

  /// Creates a new MLS group with the given [groupName] and initial [toUsers].
  ///
  /// Generates a random keypair as the group ID, initializes the MLS group in
  /// Rust via [rust_mls.createMlsGroup], adds the initial members, and sends
  /// Welcome messages to all invitees.
  ///
  /// Returns the created [Room] representing the group.
  /// Throws [Exception] if [toUsers] have no valid key packages.
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
      nostrId: identity.nostrIdentityKey,
      groupId: room.toMainPubkey,
      groupName: groupName,
      adminPubkeysHex: [identity.nostrIdentityKey],
      description: description ?? '',
      groupRelays: groupRelays,
      status: RoomStatus.enabled.name,
    );
    await _selfUpdateKeyLocal(room);
    await rust_mls.selfCommit(
      nostrId: identity.nostrIdentityKey,
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
      nostrId: identity.nostrIdentityKey,
      groupId: room.toMainPubkey,
      keyPackages: keyPackages,
    );
    await rust_mls.selfCommit(
      nostrId: identity.nostrIdentityKey,
      groupId: room.toMainPubkey,
    );
    room = await replaceListenPubkey(room);

    final welcomeMsg = base64Encode(welcome.welcome);

    final result = <String, String>{};
    for (final user in toUsers) {
      result[user['pubkey'] as String] = user['name'] as String;
    }

    await _sendInviteMessage(
      groupRoom: room,
      users: result,
      mlsWelcome: welcomeMsg,
    );

    return room;
  }

  /// Joins an MLS group using a Welcome message received from another member.
  ///
  /// Creates a local [Room] record, processes the MLS Welcome payload via
  /// Rust FFI [rust_mls.joinMlsGroup], fetches group metadata from the MLS
  /// group context extension, and sets up the listening key.
  ///
  /// Returns the newly created [Room] for the joined group.
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
      nostrId: identity.nostrIdentityKey,
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

  ///
  /// Parses the message type via Rust FFI [rust_mls.parseMlsMsgType], then
  /// routes to [_proccessTryProposalIn] for commit messages (member add/remove/
  /// update/group info) or [_proccessApplication] for application messages.
  ///
  /// Ignores duplicate events already stored in the database.
  /// Calls [failedCallback] with an error description on decryption failure.
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

  /// Dissolves the group by committing a group context extension with dissolved status.
  ///
  /// Sends a signed commit to notify all members of dissolution, then deletes
  /// the local room record. Only the group admin should call this method.
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

  /// Retrieves the MLS group context extensions: name, description, admins, relays, status.
  ///
  /// Calls Rust FFI [rust_mls.getGroupExtension] and decodes all byte fields to
  /// UTF-8 strings. Returns a [GroupExtension] with the current group metadata.
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

  /// Fetches MLS key packages (kind 10443) for the given [pubkeys] from connected relays.
  ///
  /// Queries up to 90 days of history and returns only the most recent key package
  /// per pubkey as a map of pubkey → base64-encoded key package content.
  /// Returns an empty map if [pubkeys] is empty.
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

  /// Fetches the MLS key package (kind 10443) for a single [pubkey] from relays.
  ///
  /// Optionally queries a specific relay via [toRelay]. Returns the key package
  /// content string, or null if not found or on error.
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

  /// Returns the current membership list of the MLS group as a map of pubkey → [RoomMember].
  ///
  /// Retrieves member leaf extensions (name, status, message) and per-member
  /// key package lifetime from Rust FFI. Sets [RoomMember.mlsPKExpired] if a
  /// member's key package has passed its expiry timestamp.
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
              orElse: () => UserStatusType.invited, // for default status
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

  /// Generates a signed JSON string for sharing a group invitation link.
  ///
  /// Signs the group pubkey, type, sender pubkey, and current timestamp with
  /// the identity's secp256k1 key. Recipients verify the signature before
  /// displaying the join prompt.
  ///
  /// Throws [Exception] if signing fails or the user denies the operation.
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

  /// Handles an incoming MLS Welcome event (Nostr kind 444 wrapped in NIP-17).
  ///
  /// Saves the invitation as a pending message with [RequestConfrimEnum.request],
  /// allowing the recipient to accept or decline joining the group.
  /// Ignores events sent by the local identity.
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
      encryptMode: EncryptMode.nip17,
    );
    final identity = idRoom.getIdentity();
    if (senderIdPubkey == identity.nostrIdentityKey) {
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
      content: subEvent.content,
      realMessage: 'Invite you to join group',
    );
  }

  /// Initializes the MLS database at the given [path] and bootstraps all identities.
  ///
  /// Must be called once at app startup before any MLS operations.
  /// Delegates identity initialization to [initIdentities].
  Future<void> initDB(String path) async {
    dbPath = path;
    await initIdentities();
  }

  /// Initializes the MLS Rust state machine for each identity in the database.
  ///
  /// If [identities] is null, loads all identities from [IdentityService].
  /// Each identity gets its own MLS database keyed by [KeychatGlobal.mlsDBFile].
  /// Initialization errors per identity are logged but do not abort the loop.
  Future<void> initIdentities([List<Identity>? identities]) async {
    if (dbPath == null) {
      throw Exception('MLS dbPath is null');
    }
    identities ??= await IdentityService.instance.getIdentityList();

    for (final identity in identities) {
      try {
        await rust_mls.initMlsDb(
          dbPath: '$dbPath${KeychatGlobal.mlsDBFile}',
          nostrId: identity.nostrIdentityKey,
        );
        loggerNoLine.i('MLS init for identity: ${identity.nostrIdentityKey}');
      } catch (e, s) {
        logger.e(
          'Init MLS Failed: ${identity.nostrIdentityKey} $e',
          error: e,
          stackTrace: s,
        );
      }
    }
  }

  // DEPRECATED: superseded by decryptMessage (commit dispatch handled by _proccessTryProposalIn) - candidate for removal
  @Deprecated('use decryptMessage instead')
  @override
  Future<void> processMessage({
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

  // Refreshes the room's epoch listening key and notifies the UI after a successful commit.
  // Optionally updates [room.version] to [version] if provided.
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

  /// Removes one or more members from the MLS group.
  ///
  /// Waits for pending messages to be fully processed (EOSE) before removing.
  /// Looks up each member's leaf node index via Rust FFI, sends a remove commit
  /// to all remaining members, then rotates the group's listening key.
  ///
  /// Only the group admin should call this method.
  Future<void> removeMembers(Room room, List<RoomMember> list) async {
    await waitingForEose(
      receivingKey: room.receiveAddress,
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
        nostrIdAdmin: identity.nostrIdentityKey,
        nostrIdCommon: rm.idPubkey,
        groupId: room.toMainPubkey,
      );
      bLeafNodes.add(bLeafNode);
    }
    final queuedMsg = await rust_mls.removeMembers(
      nostrId: identity.nostrIdentityKey,
      groupId: room.toMainPubkey,
      members: bLeafNodes,
    );

    final realMessage =
        '[System] Admin remove the ${names.length > 1 ? 'members' : 'member'}: ${names.join(',')}';

    room = await RoomService.instance.getRoomByIdOrFail(room.id);
    await sendEncryptedMessage(room, queuedMsg, realMessage: realMessage);
    await rust_mls.selfCommit(
      nostrId: identity.nostrIdentityKey,
      groupId: room.toMainPubkey,
    );
    room = await replaceListenPubkey(room);
    RoomService.getController(room.id)
      ?..setRoom(room)
      ..resetMembers();
  }

  /// Rotates the group's Nostr subscription key after an MLS epoch change.
  ///
  /// Derives the new listening key from the MLS export secret via Rust FFI
  /// [rust_mls.getListenKeyFromExportSecret]. Waits for EOSE on the old key,
  /// updates the WebSocket subscription, and removes the old key.
  ///
  /// Must be called after every successful commit (add/remove/update/dissolve).
  /// Returns the updated [Room] with the new [Room.receiveAddress].
  Future<Room> replaceListenPubkey(Room room) async {
    loggerNoLine.i(
      '[MLS] replaceListenPubkey START - roomId: ${room.id}, currentKey: ${room.receiveAddress}',
    );
    final newPubkey = await rust_mls
        .getListenKeyFromExportSecret(
          nostrId: room.myIdPubkey,
          groupId: room.toMainPubkey,
        )
        .timeout(const Duration(seconds: 2));

    if (newPubkey == room.receiveAddress) {
      loggerNoLine.i(
        '[MLS] replaceListenPubkey END - no change for room: ${room.id}',
      );
      await RoomService.instance.updateRoomAndRefresh(room);
      return room;
    }

    loggerNoLine.i(
      '[MLS] new pubkey for room: ${room.toMainPubkey}, '
      'old: ${room.receiveAddress}, new: $newPubkey',
    );
    final toDeletePubkey = room.receiveAddress;
    await waitingForEose(
      receivingKey: room.receiveAddress,
      relays: room.sendingRelays,
    );
    room.receiveAddress = newPubkey;
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

  /// Sends a greeting message when the local identity joins a group for the first time.
  ///
  /// Performs a self-update key operation that embeds the member's display name
  /// and a "Hello everyone" message into the MLS leaf extension. Marks
  /// [Room.sentHelloToMLS] to prevent duplicate greetings.
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

  /// Performs an MLS self-update, rotating the member's own leaf key.
  ///
  /// Waits for EOSE to ensure all pending messages are processed first.
  /// Sends the update commit to the group and rotates the listening key.
  /// Optionally embeds custom extension data (e.g., display name, status message).
  ///
  /// Returns the updated [Room] with the rotated listening key.
  Future<Room> selfUpdateKey(
    Room room, {
    required String msg,
    Map<String, dynamic>? extension,
  }) async {
    // waiting for the old pubkey to be Eosed. means that all events proccessed
    await waitingForEose(
      receivingKey: room.receiveAddress,
      relays: room.sendingRelays,
    );
    await RoomService.instance.checkWebsocketConnect();
    final queuedMsg = await _selfUpdateKeyLocal(room, extension);
    final identity = room.getIdentity();
    await sendEncryptedMessage(room, queuedMsg, realMessage: msg);
    await rust_mls.selfCommit(
      nostrId: identity.nostrIdentityKey,
      groupId: room.toMainPubkey,
    );
    final room0 = await replaceListenPubkey(room);
    await RoomService.getController(room.id)?.resetMembers();

    return room0;
  }

  /// Sends a raw MLS-encrypted message payload to the group's one-time key.
  ///
  /// Uses a freshly generated random Nostr keypair as the sender to preserve
  /// anonymity. The payload is sent as NIP-17.
  /// Used for system messages like commit notifications and group state changes.
  ///
  /// Throws [Exception] if the group's [Room.receiveAddress] is null.
  Future<SendMessageResponse> sendEncryptedMessage(
    Room room,
    String message, {
    bool save = true,
    MessageMediaType? mediaType,
    String? realMessage,
    List<List<String>>? additionalTags,
  }) async {
    if (room.receiveAddress == null) {
      throw Exception('Receiving pubkey is null');
    }

    final randomAccount = await rust_nostr.generateSimple();
    final smr = await NostrAPI.instance.sendEventMessage(
      room.receiveAddress!,
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
            [EventKindTags.pubkey, room.receiveAddress!],
          ],
    );
    return smr;
  }

  /// Encrypts and sends a user message to the MLS group.
  ///
  /// Encrypts [message] using the MLS Rust FFI [rust_mls.createMessage], then
  /// publishes it as a NIP-17 kind 1059 event to the group's one-time key.
  /// Supports optional [reply] threading and custom [mediaType].
  ///
  /// Throws [Exception] if [room.receiveAddress] is null.
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
    if (room.receiveAddress == null) {
      throw Exception('Receiving pubkey is null');
    }
    final identity = room.getIdentity();
    final enctypted = await rust_mls.createMessage(
      nostrId: identity.nostrIdentityKey,
      groupId: room.toMainPubkey,
      msg: message,
    );

    // refresh onetime key
    if (realMessage != null) {
      room = await RoomService.instance.getRoomByIdOrFail(room.id);
    }
    final randomAccount = await rust_nostr.generateSimple();
    final smr = await NostrAPI.instance.sendEventMessage(
      room.receiveAddress!,
      enctypted.encryptMsg,
      prikey: randomAccount.prikey,
      from: randomAccount.pubkey,
      room: room,
      encryptType: MessageEncryptType.mls,
      kind: EventKinds.nip17,
      additionalTags: [
        [EventKindTags.pubkey, room.receiveAddress!],
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

  /// Updates the MLS group name by committing a group context extension change.
  ///
  /// Waits for EOSE, sends the extension update commit to all members, then
  /// rotates the listening key. Only the group admin should call this method.
  ///
  /// Returns the updated [Room] with the new listening key.
  Future<Room> updateGroupName(Room room, String newName) async {
    await waitingForEose(
      receivingKey: room.receiveAddress,
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

  /// Publishes MLS key packages (kind 10443) to connected relays for each identity.
  ///
  /// Skips upload if a valid, non-expired key package (created <30 days ago)
  /// already exists on the relay, unless [forceUpload] is true.
  /// Optionally targets a specific relay via [toRelay].
  ///
  /// Key packages must be published before other users can add this identity
  /// to an MLS group. Throws [Exception] if no relays are available.
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
          pubkey: identity.nostrIdentityKey,
          toRelay: toRelay,
        );

        if (existingPK == null) {
          // No key package found on relay, need to upload
          needsUpload = true;
          loggerNoLine.i(
            'No key package found on relay for identity: ${identity.nostrIdentityKey}',
          );
        } else {
          // Query the event from relay to check creation time
          final ws = Get.find<WebsocketService>();
          final req = NostrReqModel(
            reqId: generate64RandomHexChars(16),
            authors: [identity.nostrIdentityKey],
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
          // TODO: check if the existing key package has already been consumed
          // by a group add operation before deciding to skip the upload.
          if (list.isNotEmpty) {
            final event = list[0];
            final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            final eventAge = now - event.createdAt;
            const thirtyDays = 30 * 24 * 60 * 60;

            if (eventAge >= thirtyDays) {
              needsUpload = true;
              loggerNoLine.i(
                'Key package expired (>30 days) for identity: ${identity.nostrIdentityKey}',
              );
            } else {
              loggerNoLine.i(
                'Key package still valid for identity: ${identity.nostrIdentityKey}',
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
        'Uploading key package for identity: ${identity.nostrIdentityKey}',
      );
      final event = await _createKeyPackageEvent(identity, onlineRelays);

      Get.find<WebsocketService>().sendMessageWithCallback(
        '["EVENT",$event]',
        callback:
            ({
              required relay,
              required eventId,
              required status,
              errorMessage,
            }) async {
              final isDuplicate =
                  errorMessage?.toLowerCase().startsWith('duplicate') ?? false;
              if (status || isDuplicate) {
                loggerNoLine.i(
                  'Key package uploaded successfully to $relay: ${identity.nostrIdentityKey}',
                );
              } else {
                logger.w(
                  'Key package upload failed to $relay: ${identity.nostrIdentityKey}, error: $errorMessage',
                );
              }
              NostrAPI.instance.removeOKCallback(eventId);
            },
      );
    }
  }

  // Applies an incoming group context extension commit to the local room state.
  // Updates room name, description, and relays. Handles group dissolution
  // by marking the room as [RoomStatus.dissolved].
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

  // Decrypts and delivers an MLS application message (regular chat message).
  // Calls Rust FFI [rust_mls.decryptMessage] to get the plaintext and sender pubkey.
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
    final km = NostrAPI.instance.tryGetKeyChatMessage(decryptedMsg.decryptMsg);
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

  // Applies an MLS commit from another member and generates the appropriate system message.
  // Handles commit types: add members, remove members, self-update, group context extension.
  // Rotates the room's listening key after a successful commit (unless local member was removed).
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

  // Generates a self-update proposal payload via Rust FFI [rust_mls.selfUpdate].
  // Embeds optional [extension] data (e.g., display name, status) into the leaf node.
  // Defaults to encoding just the identity's display name if [extension] is null.
  // Returns the queued message bytes to be sent as the commit payload.
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
      nostrId: identity.nostrIdentityKey,
      groupId: room.toMainPubkey,
      extensions: utf8.encode(jsonEncode(map)),
    );
  }

  // Sends MLS Welcome messages (kind 444 wrapped in NIP-17) to newly added members.
  // Each member receives an individual NIP-17 message containing the base64-encoded Welcome.
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
    int nip17Kind = EventKinds.chatRumor,
    List<List<String>>? additionalTags,
  }) async {
    final events = <NostrEventModel>[];
    final identity = groupRoom.getIdentity();
    String? errorMessage;
    for (final user in users.entries) {
      if (identity.nostrIdentityKey == user.key) continue;
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
      from: identity.nostrIdentityKey,
      idPubkey: identity.nostrIdentityKey,
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

  /// Notifies the group that this member is voluntarily leaving.
  ///
  /// Sends a self-update commit with status [UserStatusType.removed], signalling
  /// the admin to remove this member via [removeMembers]. The message is not
  /// saved to local history (save: false).
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

  /// Waits until the WebSocket subscription for [receivingKey] has received EOSE
  /// and no new events have arrived for at least 1 second.
  ///
  /// Falls back after 2 seconds if EOSE is never received (relay timeout).
  /// Used before group mutations to ensure all pending messages are processed,
  /// preventing epoch mismatches. No-ops if [receivingKey] is null.
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
      nostrId: identity.nostrIdentityKey,
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

  /// Repairs the one-time listening key for MLS group rooms after app restart.
  ///
  /// Compares each room's stored [Room.receiveAddress] against the value derived
  /// from the current MLS export secret. Updates the room and re-subscribes
  /// to the correct key if they differ.
  ///
  /// Called during app initialization to recover from interrupted epoch rotations.
  Future<void> fixMlsReceiveAddress(List<Room> rooms) async {
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
        if (room.receiveAddress == null || room.receiveAddress != newPubkey) {
          loggerNoLine.i(
            '[MLS] Room ${room.id} update receive address $newPubkey',
          );
          room.receiveAddress = newPubkey;
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

  /// Checks whether an MLS key package is still within its validity period.
  ///
  /// Parses the key package's [lifetime] via Rust FFI
  /// [rust_mls.parseLifetimeFromKeyPackage] and compares against the current
  /// Unix timestamp.
  ///
  /// Returns true if the key package has not expired, false otherwise.
  Future<bool> checkPkIsValid(Room room, String pk) async {
    final nostrId = room.getIdentity().nostrIdentityKey;
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

  /// Checks if any current group member has an expired MLS key package.
  ///
  /// Fetches all member lifetimes from Rust FFI and compares against current time.
  /// Throws [ExpiredMembersException] containing the list of expired [RoomMember]s
  /// if any are found. Used to block add/remove operations that would fail
  /// with expired credentials.
  Future<void> existExpiredMember(Room room) async {
    final lifeTimes = await rust_mls.getGroupMembersWithLifetime(
      nostrId: room.myIdPubkey,
      groupId: room.toMainPubkey,
    );
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiredPubkeys = lifeTimes.entries
        .where((entry) => entry.value != null && entry.value!.toInt() < now)
        .map((entry) => entry.key)
        .toList();

    if (expiredPubkeys.isEmpty) return;
    final expiredMembers = <RoomMember>[];
    for (final pubkey in expiredPubkeys) {
      final member = await room.getMemberByIdPubkey(pubkey);
      if (member != null) {
        expiredMembers.add(member);
      }
    }
    if (expiredMembers.isEmpty) return;
    // DEPRECATED: replaced by direct lifetime query above - candidate for removal
    // final expiredMembers = (await getMembers(room)).values.toList();
    throw ExpiredMembersException(expiredMembers);
  }
}
