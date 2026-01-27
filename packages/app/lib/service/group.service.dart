import 'dart:collection' as collection;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/service/group_tx.dart';
import 'package:keychat/service/chat.service.dart';
import 'package:keychat/service/chatx.service.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/nip4_chat.service.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/signal_chat.service.dart';
import 'package:keychat/service/signalId.service.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';

import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:queue/queue.dart';

import 'package:keychat/constants.dart';
import 'package:keychat/nostr-core/nostr.dart';
import 'package:keychat/utils.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/service/room.service.dart';

const String changeNickName = 'change nickname to: ';
const String joinGreeting = 'joined group';
const String hello = '😃 Hi, I am ';

class GroupService extends BaseChatService {
  // Avoid self instance
  GroupService._();
  static GroupService? _instance;
  static GroupService get instance => _instance ??= GroupService._();

  static final DBProvider dbProvider = DBProvider.instance;
  static final NostrAPI nostrAPI = NostrAPI.instance;
  RoomService roomService = RoomService.instance;
  ContactService contactService = ContactService.instance;
  IdentityService identityService = IdentityService.instance;

  Future<void> changeMyNickname(Room room, String newName) async {
    final database = DBProvider.database;

    final rm = await database.roomMembers
        .filter()
        .roomIdEqualTo(room.id)
        .idPubkeyEqualTo(room.myIdPubkey)
        .findFirst();
    if (rm == null) return;
    await sendMessageToGroup(
      room,
      'My new nickname: $newName',
      ext: newName,
      subtype: KeyChatEventKinds.groupChangeNickname,
    );
    rm.name = newName;
    await database.writeTxn(() async {
      await database.roomMembers.put(rm);
    });
  }

  Future<void> changeRoomName(int roomId, String newName) async {
    final room = await roomService.getRoomByIdOrFail(roomId);
    if (!await room.checkAdminByIdPubkey(room.myIdPubkey)) {
      throw Exception('only admin can change name');
    }
    room.name = newName;
    if (room.isSendAllGroup) {
      await sendMessageToGroup(
        room,
        '[System] New room name: $newName',
        subtype: KeyChatEventKinds.groupChangeRoomName,
        ext: newName,
      );
      await roomService.updateRoomAndRefresh(room);
    } else if (room.isMLSGroup) {
      await MlsGroupService.instance.updateGroupName(room, newName);
    }
  }

  bool checkUserInList(List<dynamic> list, String pubkey) {
    for (final user in list) {
      if (user['idPubkey'] == pubkey) {
        return true;
      }
    }
    return false;
  }

  // create group
  // 1. Create a new local roomChat and create a new identity key: myRoomKey
  // 2. Create a new sharedPrivateKey shared by the group: bip340
  // 3. Set the name of the group and the encrypted participant list to the relay
  // 4. Listen for messages from group’s sharedPubkey
  Future<Room> createGroup(
    String groupName,
    Identity identity,
    GroupType groupType, {
    List<String>? groupRelays,
  }) async {
    final randomKey = await rust_nostr.generateSimple();
    final toMainPubkey = randomKey.pubkey;

    final now = DateTime.now();
    final room = await _createGroupToDB(
      toMainPubkey,
      groupName,
      members: [],
      identity: identity,
      groupType: groupType,
      groupRelays: groupRelays,
      version: now.millisecondsSinceEpoch,
    );
    // add meMember
    await room.addMember(
      name: identity.name,
      isAdmin: true,
      idPubkey: identity.secp256k1PKHex,
      curve25519PkHex: identity.curve25519PkHex,
      status: UserStatusType.invited,
      createdAt: now,
      updatedAt: now,
    );
    return room;
  }

  Future<void> dissolveGroup(Room room) async {
    if (!await room.checkAdminByIdPubkey(room.myIdPubkey)) {
      throw Exception('Only admin can exit group');
    }
    const message = '[System] The admin closed the group chat';
    if (room.isMLSGroup) {
      await MlsGroupService.instance.dissolve(room);
      return;
    }
    const subtype = KeyChatEventKinds.groupDissolve;

    final List list = await room.getActiveMembers();
    if (list.isNotEmpty) {
      await sendMessageToGroup(room, message, subtype: subtype);
    }

    await roomService.deleteRoom(room);
  }

  Future<void> selfExitGroup(Room room) async {
    if (await room.checkAdminByIdPubkey(room.myIdPubkey)) {
      throw Exception('admin can not exit group');
    }
    if (room.isMLSGroup) {
      try {
        await MlsGroupService.instance.sendSelfLeaveMessage(room);
      } catch (e) {
        logger.e('sendSelfLeaveMessage error: $e');
      }
      await roomService.deleteRoom(room);
      return;
    }

    final rm = await room.getMemberByIdPubkey(room.myIdPubkey);
    if (rm != null) {
      final message =
          '[System] ${rm.name} exit group, waiting for admin commit.';
      const subtype = KeyChatEventKinds.groupSelfLeave;
      await sendMessageToGroup(room, message, subtype: subtype);
    }
    await roomService.deleteRoom(room);
  }

  Future<void> isAdminCheck(
    Room room,
    String pubkey,
    RoomMember? roomMember,
  ) async {
    var isAdmin = false;
    if (room.groupType == GroupType.shareKey) {
      isAdmin = await room.checkAdminByIdPubkey(pubkey);
    } else if (roomMember != null) {
      isAdmin = roomMember.isAdmin;
    }
    if (!isAdmin) {
      throw Exception('not admin');
    }
  }

  Future<void> processGroupMessage(
    Room room,
    NostrEventModel event,
    GroupMessage groupMessage, {
    RoomMember? member,
    Room? idRoom,
    String? msgKeyHash,
    NostrEventModel? sourceEvent,
  }) async {
    final signPubkey = room.isSendAllGroup
        ? idRoom!.toMainPubkey
        : event.pubkey;
    final subType = groupMessage.subtype;
    final ext = groupMessage.ext;

    final toSaveMsg = Message(
      idPubkey: signPubkey,
      identityId: room.identityId,
      msgid: sourceEvent?.id ?? event.id,
      eventIds: [sourceEvent?.id ?? event.id],
      roomId: room.id,
      from: signPubkey,
      to: room.toMainPubkey,
      encryptType: room.isSendAllGroup
          ? MessageEncryptType.signal
          : MessageEncryptType.mls,
      isMeSend: signPubkey == room.myIdPubkey,
      sent: SendStatusType.success,
      content: groupMessage.message,
      msgKeyHash: msgKeyHash,
      createdAt: timestampToDateTime(event.createdAt),
      rawEvents: [(sourceEvent ?? event).toString()],
    )..isRead = signPubkey == room.myIdPubkey;

    if (subType != null) {
      toSaveMsg.isSystem = true;
    }
    final updatedAt = timestampToDateTime(event.createdAt * 1000);
    switch (subType) {
      case KeyChatEventKinds.groupHi:
        final newName = groupMessage.message.split(joinGreeting)[0];
        await _processHelloMessage(room, signPubkey, updatedAt, newName);
      case KeyChatEventKinds.groupChangeNickname:
        if (groupMessage.ext != null) {
          await room.updateMemberName(
            signPubkey,
            groupMessage.ext!,
          );
          updateChatControllerMembers(room.id);
        }
      case KeyChatEventKinds.groupSelfLeave:
        // self exit group
        if (signPubkey == room.myIdPubkey) {
          return;
        }
        await room.removeMember(signPubkey);
        updateChatControllerMembers(room.id);

      case KeyChatEventKinds.groupDissolve:
        await isAdminCheck(room, signPubkey, member);
        room.status = RoomStatus.dissolved;
        toSaveMsg.content = '[System] The admin closed the group chat';
        await roomService.updateRoomAndRefresh(room);
      case KeyChatEventKinds.groupChangeRoomName:
        await isAdminCheck(room, signPubkey, member);
        room.name = ext;
        await roomService.updateRoomAndRefresh(room);
        toSaveMsg.content = toSaveMsg.content;
      case KeyChatEventKinds.groupRemoveSingleMember:
        await isAdminCheck(room, signPubkey, member);
        if (ext != null) {
          await room.removeMember(ext);
          updateChatControllerMembers(room.id);

          // Check if I am still in the group, otherwise I will be marked as kicked out of the group
          final rm = await room.getMemberByIdPubkey(room.myIdPubkey);
          if (rm == null || rm.status == UserStatusType.removed) {
            toSaveMsg.content = '[System] You have been removed by admin.';
            room.status = RoomStatus.removedFromGroup;
            room = await RoomService.instance.updateRoom(room);
            updateChatControllerMembers(room.id);
            RoomService.getController(room.id)?.setRoom(room);
          }
        }
      case KeyChatEventKinds.dm:
        if (ext != null) {
          toSaveMsg.reply = MsgReply.fromJson(
            jsonDecode(ext) as Map<String, dynamic>,
          );
        }
      default:
    }

    await MessageService.instance.saveMessageModel(toSaveMsg, room: room);
  }

  Future<void> processInvite(
    Room idRoom,
    NostrEventModel event,
    RoomProfile roomProfile,
    String realMessage, {
    Function(String error)? failedCallback,
  }) async {
    final groupName = roomProfile.name;
    final users = roomProfile.users;
    final groupInviteMsg = jsonDecode(realMessage) as List;
    final senderIdPubkey = groupInviteMsg[1] as String;
    final identity = idRoom.getIdentity();

    if (senderIdPubkey == identity.secp256k1PKHex) {
      return;
    }
    // check is in group?
    if (idRoom.type == RoomType.common) {
      final isMemeber = checkUserInList(users, idRoom.toMainPubkey);
      if (!isMemeber) {
        logger.i('You are not in the group');
        throw Exception("You are not in the group, so can't invite me.");
      }
    }
    // roomProfile.oldToRoomPubKey is room unique key
    var groupRoom = await roomService.getRoomByIdentity(
      roomProfile.oldToRoomPubKey!,
      idRoom.identityId,
    );

    if (groupRoom == null) {
      if (roomProfile.groupType == GroupType.sendAll) {
        await DBProvider.database.writeTxn(() async {
          try {
            groupRoom = await GroupTx.instance.joinGroup(roomProfile, identity);

            await MessageService.instance.saveMessageToDB(
              from: event.pubkey,
              to: event.tags[0][1],
              senderPubkey: idRoom.toMainPubkey,
              events: [event],
              room: groupRoom!,
              isMeSend: false,
              isSystem: true,
              encryptType: MessageEncryptType.nip17,
              sent: SendStatusType.success,
              content: roomProfile.toString(),
              realMessage: groupInviteMsg[0] as String,
              persist: false,
            );
          } catch (e, s) {
            if (failedCallback != null) {
              failedCallback(e.toString());
            }
            logger.e(e.toString(), error: e, stackTrace: s);
          }
        });
        if (groupRoom != null) {
          Get.find<HomeController>().loadIdentityRoomList(
            groupRoom!.identityId,
          );
        }
        return;
      }
    }
    if (groupRoom == null) throw Exception('Group not found');

    if (roomProfile.groupType == GroupType.kdf ||
        roomProfile.groupType == GroupType.mls) {
      await MessageService.instance.saveMessageToDB(
        from: event.pubkey,
        to: event.tags[0][1],
        senderPubkey: idRoom.toMainPubkey,
        events: [event],
        room: idRoom,
        isMeSend: false,
        isSystem: true,
        encryptType: RoomUtil.getEncryptMode(event),
        sent: SendStatusType.success,
        mediaType: MessageMediaType.groupInvite,
        requestConfrim: RequestConfrimEnum.request,
        content: roomProfile.toString(),
        realMessage: groupInviteMsg[0] as String,
      );
      return;
    }

    // start to update room
    // check room version
    if (roomProfile.updatedAt < groupRoom.version) {
      if (failedCallback != null) {
        failedCallback('The invitation has expired');
      }
      throw Exception('The invitation has expired');
    }
    groupRoom.version = roomProfile.updatedAt;
    // When the room has been created, verify whether the sender is in the group.
    final member = await groupRoom.getEnableMember(senderIdPubkey);
    if (member == null) {
      logger.i('Not a vaild member in group');
      throw Exception('Not a vaild member in group');
    }

    groupRoom
      ..status = RoomStatus.enabled
      ..name = groupName;

    await RoomService.instance.updateRoomAndRefresh(groupRoom);

    await groupRoom.updateAllMember(users);
    updateChatControllerMembers(groupRoom.id);

    final message = Message(
      identityId: groupRoom.identityId,
      msgid: event.id,
      eventIds: [event.id],
      roomId: groupRoom.id,
      from: event.pubkey,
      idPubkey: senderIdPubkey,
      to: event.tags[0][1],
      sent: SendStatusType.success,
      encryptType: groupRoom.isSendAllGroup
          ? MessageEncryptType.signal
          : MessageEncryptType.nip17,
      isSystem: true,
      content: groupInviteMsg[0] as String,
      createdAt: timestampToDateTime(event.createdAt),
      rawEvents: [event.toString()],
    );
    await MessageService.instance.saveMessageModel(message, room: groupRoom);
  }

  @override
  Future<void> proccessMessage({
    required Room room,
    required KeychatMessage km,
    required NostrEventModel event,
    NostrEventModel? sourceEvent,
    Function(String error)? failedCallback,
    String? fromIdPubkey,
    String? msgKeyHash,
  }) async {
    switch (km.type) {
      case KeyChatEventKinds.groupInvite:
        final roomProfile = RoomProfile.fromJson(
          jsonDecode(km.msg!) as Map<String, dynamic>,
        );
        final realMessage = km.name ?? '[]';

        return processInvite(
          room,
          event,
          roomProfile,
          realMessage,
          failedCallback: failedCallback,
        );
      case KeyChatEventKinds.groupRemoveSingleMember:
        return _processGroupRemoveSingleMember(room, km, event);
      case KeyChatEventKinds.groupSendToAllMessage:
        final gm = GroupMessage.fromJson(
          jsonDecode(km.msg!) as Map<String, dynamic>,
        );

        final groupRoom = await RoomService.instance.getRoomByIdentity(
          gm.pubkey,
          room.identityId,
        );
        if (groupRoom == null) {
          return;
        }
        final member = await groupRoom.getMemberByIdPubkey(room.toMainPubkey);
        if (member == null) {
          if (gm.subtype != KeyChatEventKinds.groupHi) {
            logger.i('Not a member in group ${groupRoom.id}');
            return;
          }
        }
        return processGroupMessage(
          groupRoom,
          event,
          gm,
          member: member,
          idRoom: room,
          msgKeyHash: msgKeyHash,
        );
      case KeyChatEventKinds.inviteToGroupRequest:
        return _processinviteToGroupRequest(room, event, km);
      default:
    }
  }

  // Sender:
  // 1. Draw people into the group,
  // 2. Synchronize room information and member list to invited people
  // 3. Send another message about the new person joining the group. After others receive it, add the user to the list
  //
  // Receiving end:
  // 1. If the room id already exists locally, check whether the sending user is in the group
  // 2. If not, throw an exception
  // 3. Check if the secret key matches. There is a situation where the roomID is the same, but the shared secret key has been changed.
  Future<RoomProfile> inviteToJoinGroup(
    Room groupRoom,
    Map<String, String> toUsers, {
    SignalId? signalId,
    Mykey? mykey,
    String? mlsWelcome,
  }) async {
    if (toUsers.isEmpty) throw Exception('no users to invite');
    final identity = groupRoom.getIdentity();
    await roomService.checkRoomStatus(groupRoom);
    final allMembers = (await groupRoom.getSmallGroupMembers()).values.toList();
    final toMembers = <RoomMember>[];
    final status = groupRoom.isSendAllGroup
        ? UserStatusType.invited
        : UserStatusType.inviting;
    final now = DateTime.now();

    // Add to the local contact list in batches, update if it exists, create if it does not exist
    for (final idPubkey in toUsers.keys) {
      var rm = allMembers.firstWhereOrNull(
        (element) => element.idPubkey == idPubkey,
      );
      if (rm == null) {
        final c = await contactService.getOrCreateContact(
          identityId: groupRoom.identityId,
          pubkey: idPubkey,
          name: (toUsers[idPubkey]?.length ?? 0) > 0 ? toUsers[idPubkey] : null,
        );
        rm = await groupRoom.addMember(
          name: c.displayName,
          idPubkey: idPubkey,
          status: status,
          createdAt: now,
          updatedAt: now,
        );
      } else {
        if (rm.status != UserStatusType.invited) {
          rm.status = status;
          rm.updatedAt = now;
          await groupRoom.updateMember(rm);
        }
      }
      toMembers.add(rm);
    }

    final roomProfile = await getRoomProfile(
      groupRoom,
      signalId: signalId,
      mykey: mykey,
      mlsWelcome: mlsWelcome,
    );
    final addUsersName = toMembers.map((e) => e.name).toList();
    final names = addUsersName.join(',');
    final realMessage = 'Invite [$names] to join group ${groupRoom.name}';

    final km = KeychatMessage(
      c: MessageType.group,
      type: KeyChatEventKinds.groupInvite,
      msg: jsonEncode(roomProfile.toJson()),
    )..name = jsonEncode([realMessage, groupRoom.myIdPubkey]);

    switch (groupRoom.groupType) {
      case GroupType.mls:
        final pubkeys = toMembers.map((e) => e.idPubkey).toList();
        await sendPrivateMessageToMembers(
          realMessage,
          pubkeys,
          identity,
          groupRoom: groupRoom,
          content: km.toString(),
        );
      case GroupType.sendAll:
        await _invitePairwiseGroup(realMessage, identity, groupRoom, km);
      case GroupType.shareKey:
      case GroupType.kdf:
        break;
      case GroupType.common:
        throw UnimplementedError();
    }

    RoomService.getController(groupRoom.id)?.resetMembers();
    return roomProfile;
  }

  Future<void> removeMember(Room room, RoomMember rm) async {
    switch (room.groupType) {
      case GroupType.sendAll:
        return _removeMemberPairwise(room, rm);
      case GroupType.mls:
        return MlsGroupService.instance.removeMembers(room, [rm]);
      case GroupType.shareKey:
      case GroupType.kdf:
        throw Exception('not support');
      case GroupType.common:
        throw UnimplementedError();
    }
  }

  // Share secret key to send group messages, use double-layer nesting to send information
  // Sub event: sender private key  --> room's pubkey
  // Main event: room's private key--> room's pubkey
  @override
  Future<SendMessageResponse> sendMessage(
    Room room,
    String message, {
    int? subtype,
    String? ext,
    MsgReply? reply,
    String? realMessage,
    MessageMediaType? mediaType,
    bool save = true,
  }) async {
    throw Exception('unsupported method');
  }

  Future<SendMessageResponse> sendToAllMessage(
    Room room,
    String message, {
    int? subtype,
    String? ext,
    MsgReply? reply,
    String? realMessage,
    MessageMediaType? mediaType,
  }) async {
    String? msgKeyHash;

    final gm = RoomUtil.getGroupMessage(
      room,
      message,
      pubkey: room.toMainPubkey,
      reply: reply,
      subtype: subtype,
      ext: ext,
    );

    final km = KeychatMessage(
      c: MessageType.group,
      type: KeyChatEventKinds.groupSendToAllMessage,
      msg: jsonEncode(gm.toJson()),
    );
    final toSendMessage = jsonEncode(km.toJson());
    final events = <NostrEventModel>[];

    List<Room>? memberRooms = [];
    final cc = RoomService.getController(room.id);
    if (cc != null) {
      memberRooms = cc.memberRooms.values.toList();
    } else {
      memberRooms = (await room.getEnableMemberRooms()).values.toList();
    }

    if (memberRooms.isEmpty) {
      throw Exception('no member in group');
    }
    final queue = Queue(parallel: 10);
    final cs = Get.find<ChatxService>();

    final toAddPubkeys = <String>[];
    final kapIsNullCount = <Room>[];
    final BaseChatService chatService = SignalChatService.instance;
    for (final idRoom in memberRooms) {
      if (idRoom.toMainPubkey == idRoom.myIdPubkey) continue;
      queue.add(() async {
        idRoom.parentRoom = room;
        try {
          final kpa = await cs.getRoomKPA(idRoom);
          if (kpa == null) {
            kapIsNullCount.add(idRoom);
            return; // skip nip04 room
          }

          final smr = await chatService.sendMessage(
            idRoom,
            toSendMessage,
            save: false,
          );

          msgKeyHash = smr.msgKeyHash;
          toAddPubkeys.addAll(smr.toAddPubkeys ?? []);
          final toSaveEvent = smr.events[0];
          toSaveEvent.toIdPubkey = idRoom.toMainPubkey;
          events.add(toSaveEvent);
        } catch (e, s) {
          logger.e(e.toString(), error: e, stackTrace: s);
        }
      });
    }
    if (cc != null) {
      cc.kpaIsNullRooms.value = kapIsNullCount;
    }
    await queue.onComplete;
    if (toAddPubkeys.isNotEmpty) {
      Get.find<WebsocketService>().listenPubkey(
        toAddPubkeys,
        kinds: [EventKinds.nip04],
        since: DateTime.now().subtract(const Duration(seconds: 60)),
      );
      NotifyService.instance.addPubkeys(toAddPubkeys);
    }

    Message? model;
    if (events.isNotEmpty) {
      final identity = room.getIdentity();

      model = await MessageService.instance.saveMessageToDB(
        events: events,
        room: room,
        content: message,
        realMessage: realMessage,
        from: identity.secp256k1PKHex,
        senderPubkey: identity.secp256k1PKHex,
        to: room.toMainPubkey,
        isMeSend: true,
        encryptType: MessageEncryptType.signal,
        reply: reply,
        mediaType: mediaType,
        msgKeyHash: msgKeyHash,
        isRead: true,
      );
    }
    return SendMessageResponse(events: events, message: model);
  }

  void updateChatControllerMembers(int roomId) {
    RoomService.getController(roomId)?.resetMembers();
  }

  Future<void> updateRoomMykey(Room room, Mykey newMykey) async {
    if (!room.isShareKeyGroup) {
      return;
    }
    final database = DBProvider.database;
    final mykeyId = room.mykey.value?.id;
    if (mykeyId != null && mykeyId == newMykey.id) {
      return;
    }
    await database.writeTxn(() async {
      room.mykey.value = newMykey;
      await database.rooms.put(room);
      await room.mykey.save();

      if (mykeyId != null) {
        await database.mykeys.filter().idEqualTo(mykeyId).deleteFirst();
      }
    });
  }

  Future<Room> _createGroupToDB(
    String toMainPubkey,
    String groupName, {
    required GroupType groupType,
    required Identity identity,
    required int version,
    List<dynamic> members = const [],
    List<String>? groupRelays,
    SignalId? signalId,
  }) async {
    var room =
        Room(
            toMainPubkey: toMainPubkey,
            npub: rust_nostr.getBech32PubkeyByHex(hex: toMainPubkey),
            identityId: identity.id,
            type: RoomType.group,
          )
          ..name = groupName
          ..groupType = groupType
          ..version = version;
    if (groupRelays != null) {
      room.sendingRelays = groupRelays;
    }

    if (groupType == GroupType.sendAll) {
      signalId ??= await SignalIdService.instance.createSignalId(identity.id);
      room.signalIdPubkey = signalId.pubkey;
    }

    room = await roomService.updateRoom(room);

    if (groupType == GroupType.sendAll) {
      await room.updateAllMember(members);
      final me = await room.getMemberByIdPubkey(identity.secp256k1PKHex);

      if (me != null && me.status != UserStatusType.invited) {
        me.status = UserStatusType.invited;
        await room.updateMember(me);
      }
    }
    return room;
  }

  // Send a group message to all enabled users
  Future<void> _invitePairwiseGroup(
    String realMessage,
    Identity identity,
    Room groupRoom,
    KeychatMessage km,
  ) async {
    // final queue = Queue(parallel: 5);
    final enables = (await groupRoom.getEnableMembers()).values.toList();
    final invitings = await groupRoom.getInvitingMembers();
    final tasks = collection.Queue.from([...enables, ...invitings]);
    km.name = jsonEncode([realMessage, identity.secp256k1PKHex]);
    final events = <NostrEventModel>[];
    final membersLength = tasks.length;

    for (var i = 0; i < membersLength; i++) {
      // queue.add(() async {
      final rm = tasks.removeFirst() as RoomMember;
      if (identity.secp256k1PKHex == rm.idPubkey) continue;
      try {
        final memberRoom = await RoomService.instance.getOrCreateRoomByIdentity(
          rm.idPubkey,
          identity,
          RoomStatus.groupUser,
        );
        final smr = await Nip4ChatService.instance.sendMessage(
          memberRoom,
          km.toString(),
          realMessage: realMessage,
          save: false,
        );
        if (smr.events.isEmpty) return;
        final toSaveEvent = smr.events[0];
        toSaveEvent.toIdPubkey = rm.idPubkey;
        events.add(toSaveEvent);
      } catch (e, s) {
        logger.e(e.toString(), error: e, stackTrace: s);
      }
    }
    // );
    // }
    // await queue.onComplete;
    final message = Message(
      identityId: groupRoom.identityId,
      msgid: events[0].id,
      eventIds: events.map((e) => e.id).toList(),
      roomId: groupRoom.id,
      from: identity.secp256k1PKHex,
      idPubkey: identity.secp256k1PKHex,
      to: groupRoom.toMainPubkey,
      encryptType: groupRoom.isSendAllGroup
          ? MessageEncryptType.signal
          : MessageEncryptType.nip17,
      sent: SendStatusType.success,
      isSystem: true,
      isMeSend: true,
      content: realMessage,
      createdAt: timestampToDateTime(events[0].createdAt),
      rawEvents: events.map((e) {
        final Map m = e.toJson();
        m['toIdPubkey'] = e.toIdPubkey;
        return jsonEncode(m);
      }).toList(),
    )..isRead = true;
    await MessageService.instance.saveMessageModel(message, room: groupRoom);
  }

  // send message to users, but skip meMember
  Future<void> sendPrivateMessageToMembers(
    String realMessage,
    List<String> toUsers,
    Identity identity, {
    required Room groupRoom,
    required String content,
    bool nip17 = false,
    int nip17Kind = EventKinds.nip17,
    List<List<String>>? additionalTags,
    bool save = true,
  }) async {
    final queue = Queue(parallel: 5);
    final tasks = collection.Queue.from(toUsers);
    final membersLength = tasks.length;
    final identity = groupRoom.getIdentity();
    for (var i = 0; i < membersLength; i++) {
      queue.add(() async {
        if (tasks.isEmpty) return;
        final idPubkey = tasks.removeFirst() as String;
        final hexPubkey = rust_nostr.getHexPubkeyByBech32(bech32: idPubkey);
        if (identity.secp256k1PKHex == hexPubkey) return;
        var room = await roomService.getRoomByIdentity(hexPubkey, identity.id);
        if (room == null) {
          room = await RoomService.instance.createRoomAndsendInvite(
            hexPubkey,
            identity: identity,
            autoJump: false,
          );
          await Future.delayed(const Duration(milliseconds: 300));
        }
        // send message with nip17
        if (nip17 || room == null) {
          await NostrAPI.instance.sendNip17Message(
            groupRoom,
            content,
            identity,
            toPubkey: idPubkey,
            realMessage: realMessage,
            nip17Kind: nip17Kind,
            additionalTags: additionalTags,
            save: save,
          );
          return;
        }
        await RoomService.instance.sendMessage(
          room,
          content,
          realMessage: realMessage,
        );
      });
    }
    await queue.onComplete;
  }

  Future<void> _processHelloMessage(
    Room groupRoom,
    String idPubkey,
    DateTime updatedAt,
    String name,
  ) async {
    final rm = await groupRoom.getMemberByIdPubkey(idPubkey);
    if (rm == null) {
      logger.i('Not a member in group ${groupRoom.id}, $idPubkey');
      return;
    }

    rm.status = UserStatusType.invited;
    rm.updatedAt = updatedAt;
    rm.name = name;
    await groupRoom.updateMember(rm);

    updateChatControllerMembers(groupRoom.id);
  }

  // Received the news that I was baned from the group
  Future<void> _processGroupRemoveSingleMember(
    Room idRoom,
    KeychatMessage km,
    NostrEventModel event,
  ) async {
    final toMainPubkey = km.msg;
    if (toMainPubkey == null) return;
    final groupRoom = await RoomService.instance.getRoomByIdentity(
      toMainPubkey,
      idRoom.identityId,
    );
    if (groupRoom == null) return;
    final member = await groupRoom.getMemberByIdPubkey(idRoom.toMainPubkey);
    if (member == null) return;
    if (!member.isAdmin) throw Exception('not admin');

    await MessageService.instance.saveMessageToDB(
      from: event.pubkey,
      to: event.tags[0][1],
      senderPubkey: idRoom.toMainPubkey,
      events: [event],
      room: groupRoom,
      isMeSend: false,
      isSystem: true,
      encryptType: MessageEncryptType.nip17,
      sent: SendStatusType.success,
      mediaType: MessageMediaType.text,
      content: event.content,
      realMessage: '[System] You have been removed',
    );

    groupRoom.status = RoomStatus.removedFromGroup;
    await RoomService.instance.updateRoom(groupRoom);
    RoomService.getController(groupRoom.id)?.setRoom(groupRoom);
    updateChatControllerMembers(groupRoom.id);
  }

  Future<void> _removeMemberPairwise(Room room, RoomMember rm) async {
    final msg =
        '''
Remove member: ${rm.name}
${rm.idPubkey}
''';

    await sendMessageToGroup(
      room,
      msg,
      subtype: KeyChatEventKinds.groupRemoveSingleMember,
      ext: rm.idPubkey,
    );
    await room.setMemberDisable(rm);
    updateChatControllerMembers(room.id);
  }

  Future<SendMessageResponse?> sendMessageToGroup(
    Room room,
    String message, {
    bool save = true,
    int? subtype,
    String? ext,
    String? realMessage,
  }) async {
    if (room.isMLSGroup) {
      final sm = KeychatMessage(c: MessageType.mls, type: subtype ?? 0)
        ..name = ext
        ..msg = message;
      return MlsGroupService.instance.sendMessage(
        room,
        sm.toString(),
        realMessage: realMessage ?? message,
        save: save,
      );
    }

    if (room.isSendAllGroup) {
      return sendToAllMessage(
        room,
        message,
        subtype: subtype,
        ext: ext,
        realMessage: realMessage,
      );
    }
    return null;
  }

  Future<void> sendInviteToAdmin(
    Room room,
    Map<String, String> selectAccounts,
  ) async {
    final roomMember = await room.getAdmin();
    if (roomMember == null) {
      throw Exception('No admin in group');
    }
    final identity = room.getIdentity();
    final names = selectAccounts.values.join(',');
    final sm =
        KeychatMessage(
            c: MessageType.group,
            type: KeyChatEventKinds.inviteToGroupRequest,
          )
          ..name = jsonEncode([room.toMainPubkey, selectAccounts])
          ..msg =
              'Invite [${names.isEmpty ? selectAccounts.keys.join(',') : names}] to join group ${room.name}, Please confirm';

    final adminRoom = await RoomService.instance.getOrCreateRoom(
      roomMember,
      identity.secp256k1PKHex,
      RoomStatus.init,
    );
    Get.find<HomeController>().loadIdentityRoomList(adminRoom.identityId);
    await RoomService.instance.sendMessage(
      adminRoom,
      sm.toString(),
      realMessage: sm.msg,
    );
  }

  Future<void> _processinviteToGroupRequest(
    Room room,
    NostrEventModel event,
    KeychatMessage km,
  ) async {
    RoomService.instance.receiveDM(
      room,
      event,
      decodedContent: km.name,
      realMessage: km.msg,
      requestConfrim: RequestConfrimEnum.request,
      mediaType: MessageMediaType.groupInviteConfirm,
    );
  }

  Future<RoomProfile> getRoomProfile(
    Room groupRoom, {
    SignalId? signalId,
    Mykey? mykey,
    String? mlsWelcome,
  }) async {
    final allMembers = (await groupRoom.getSmallGroupMembers()).values.toList();

    final roomMykey = groupRoom.mykey.value;
    final roomPubkey =
        mykey?.pubkey ?? roomMykey?.pubkey ?? groupRoom.toMainPubkey;
    final roomProfile =
        RoomProfile(
            roomPubkey,
            groupRoom.name!,
            allMembers,
            groupRoom.groupType,
            DateTime.now().millisecondsSinceEpoch,
          )
          ..oldToRoomPubKey = groupRoom.toMainPubkey
          ..prikey = mykey?.prikey ?? roomMykey?.prikey;

    if (mlsWelcome != null) {
      roomProfile.ext = mlsWelcome;
    }
    return roomProfile;
  }
}
