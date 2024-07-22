import 'dart:collection' as collection;
import 'dart:convert' show jsonEncode, jsonDecode;

import 'package:app/controller/chat.controller.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/service/GroupTx.dart';
import 'package:app/service/chat.service.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/nip4Chat.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/signalChat.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';

import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;
import 'package:keychat_rust_ffi_plugin/api_signal.dart';
import 'package:queue/queue.dart';

import '../constants.dart';
import '../models/db_provider.dart';
import '../models/keychat/room_profile.dart';
import '../nostr-core/nostr.dart';
import '../utils.dart';
import 'contact.service.dart';
import 'identity.service.dart';
import 'message.service.dart';
import 'room.service.dart';

const String changeNickName = 'change nickname to: ';
const String joinGreeting = 'joined group';
const String hello = '😃 Hi, I am ';

class GroupService extends BaseChatService {
  static final GroupService _singleton = GroupService._internal();
  factory GroupService() {
    return _singleton;
  }

  GroupService._internal();

  static final DBProvider dbProvider = DBProvider();
  static final NostrAPI nostrAPI = NostrAPI();
  RoomService roomService = RoomService();
  ContactService contactService = ContactService();
  IdentityService identityService = IdentityService();

  changeMyNickname(Room room, String nickname) async {
    Isar database = DBProvider.database;

    RoomMember? rm = await database.roomMembers
        .filter()
        .roomIdEqualTo(room.id)
        .idPubkeyEqualTo(room.myIdPubkey)
        .findFirst();
    if (rm == null) return;
    await sendMessageToGroup(room, '${rm.name} $changeNickName$nickname',
        subtype: KeyChatEventKinds.groupChangeNickname,
        realMessage: '🤖 My new nickname: $nickname');
    rm.name = nickname;
    await database.writeTxn(() async {
      await database.roomMembers.put(rm);
    });
  }

  changeRoomName(int roomId, String name) async {
    Room room = await roomService.getRoomByIdOrFail(roomId);
    if (!await room.checkAdminByIdPubkey(room.myIdPubkey)) {
      throw Exception('only admin can change name');
    }
    room.name = name;
    await roomService.updateRoom(room);
    await sendMessageToGroup(room, name,
        subtype: KeyChatEventKinds.groupChangeRoomName,
        realMessage: '🤖 New room name: $name');
  }

  bool checkUserInList(List<dynamic> list, String pubkey) {
    for (var user in list) {
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
      String groupName, Identity identity, GroupType groupType,
      [String? groupRelay]) async {
    Mykey? sharedKey;
    late String toMainPubkey;
    if (groupType == GroupType.shareKey) {
      sharedKey = await GroupTx().createMykey(identity);
      toMainPubkey = sharedKey.pubkey;
    } else {
      var key = await rustNostr.generateSimple();
      toMainPubkey = key.pubkey;
    }
    DateTime now = DateTime.now();
    Room room = await _createGroupToDB(toMainPubkey, groupName,
        members: [],
        sharedKey: sharedKey,
        identity: identity,
        groupType: groupType,
        groupRelay: groupRelay,
        version: now.millisecondsSinceEpoch);
    // add meMember
    await room.addMember(
        name: identity.name,
        isAdmin: true,
        idPubkey: identity.secp256k1PKHex,
        curve25519PkHex: identity.curve25519PkHex,
        status: UserStatusType.invited,
        createdAt: now,
        updatedAt: now);
    return room;
  }

  dissolveGroup(Room room) async {
    if (!await room.checkAdminByIdPubkey(room.myIdPubkey)) {
      throw Exception('Only admin can exit group');
    }

    await sendMessageToGroup(room, KeyChatEventKinds.groupDissolve.toString(),
        subtype: KeyChatEventKinds.groupDissolve);

    await roomService.deleteRoom(room);
  }

  exitGroup(Room room) async {
    if (await room.checkAdminByIdPubkey(room.myIdPubkey)) {
      throw Exception('admin can not exit group');
    }
    RoomMember? rm = await room.getMemberByIdPubkey(room.myIdPubkey);
    if (rm == null) return;
    await sendMessageToGroup(room, '${rm.name} exit group',
        subtype: KeyChatEventKinds.groupExist);
    await roomService.deleteRoom(room);
  }

  fillContactName(Room room, String groupName, RoomMember? rm) async {
    if (rm == null) return;

    Contact? contact =
        await contactService.getContact(room.identityId, room.toMainPubkey);

    if (contact == null) return;
    if (contact.name == null && contact.petname == null) {
      contact.petname = '${rm.name} - $groupName';
      await contactService.saveContact(contact);
    }
  }

  isAdminCheck(Room room, String pubkey, RoomMember? roomMember) async {
    bool isAdmin = false;
    if (room.groupType == GroupType.shareKey) {
      isAdmin = await room.checkAdminByIdPubkey(pubkey);
    } else if (roomMember != null) {
      isAdmin = roomMember.isAdmin;
    }
    if (!isAdmin) {
      throw Exception('not admin');
    }
  }

  processChangeSignKey(
      Room idRoom, NostrEventModel event, RoomProfile roomProfile) async {
    String? newPrikey = roomProfile.prikey;
    if (newPrikey == null) throw Exception('newPrikey is null');
    String oldToRoomPubKey = roomProfile.oldToRoomPubKey!;
    List<dynamic> users = roomProfile.users;
    String newPubkey = await rustNostr.getHexPubkeyByPrikey(prikey: newPrikey);

    Room? room =
        await roomService.getRoomByIdentity(oldToRoomPubKey, idRoom.identityId);
    if (room == null) return;
    RoomMember? roomMemberAdmin = await room.getAdmin();
    if (roomMemberAdmin == null) throw Exception('not found admin');
    if (roomMemberAdmin.idPubkey != event.pubkey) {
      throw Exception('not admin');
    }

    late Mykey newkey;
    await DBProvider.database.writeTxn(() async {
      newkey = await GroupTx().importMykeyTx(
          room.getIdentity(), await rustNostr.importKey(senderKeys: newPrikey));
    });

    await updateRoomMykey(room, newkey);

    await room.updateAllMember(users);

    await MessageService().saveMessageToDB(
        events: [event],
        room: room,
        sent: SendStatusType.success,
        encryptType: room.isSendAllGroup
            ? MessageEncryptType.signal
            : MessageEncryptType.nip4,
        content: event.content,
        realMessage:
            '🤖 Admin changed the SharedPrivate Key. ${roomProfile.ext}',
        from: room.myIdPubkey,
        idPubkey: idRoom.toMainPubkey,
        to: room.toMainPubkey,
        isMeSend: false,
        isSystem: true,
        isRead: false);
    await Get.find<WebsocketService>().listenPubkey([newPubkey], limit: 1000);
    updateChatControllerMembers(room.id);
  }

  processGroupMessage(
      Room room, NostrEventModel event, GroupMessage groupMessage,
      {RoomMember? member,
      Room? idRoom,
      String? msgKeyHash,
      required Relay relay,
      NostrEventModel? sourceEvent}) async {
    String signPubkey =
        room.isSendAllGroup ? idRoom!.toMainPubkey : event.pubkey;
    int? subType = groupMessage.subtype;
    String? ext = groupMessage.ext;

    Message toSaveMsg = Message(
        idPubkey: signPubkey,
        identityId: room.identityId,
        msgid: sourceEvent?.id ?? event.id,
        eventIds: [sourceEvent?.id ?? event.id],
        roomId: room.id,
        from: signPubkey,
        to: room.toMainPubkey,
        encryptType: room.isSendAllGroup
            ? MessageEncryptType.signal
            : MessageEncryptType.nip4WrapNip4,
        isMeSend: signPubkey == room.myIdPubkey,
        sent: SendStatusType.success,
        content: groupMessage.message,
        msgKeyHash: msgKeyHash,
        createdAt: timestampToDateTime(event.createdAt))
      ..isRead = signPubkey == room.myIdPubkey;

    if (subType != null) {
      toSaveMsg.isSystem = true;
    }
    DateTime updatedAt = timestampToDateTime(event.createdAt * 1000);
    switch (subType) {
      case KeyChatEventKinds.groupHi:
        String newName = groupMessage.message.split(joinGreeting)[0];
        await _processGroupHi(room, signPubkey, updatedAt, newName);
        break;
      case KeyChatEventKinds.groupChangeNickname:
        String newName = groupMessage.message.split(changeNickName)[1];
        await room.updateMemberName(signPubkey, newName);
        updateChatControllerMembers(room.id);
        break;
      case KeyChatEventKinds.groupExist:
        // self exit group
        if (signPubkey == room.myIdPubkey) {
          return;
        }
        await room.removeMember(signPubkey);
        updateChatControllerMembers(room.id);
        break;

      case KeyChatEventKinds.groupDissolve:
        await isAdminCheck(room, signPubkey, member);
        room.status = RoomStatus.dissolved;
        toSaveMsg.content = '🤖 The admin dissolved this room. Please delete.';
        await roomService.updateRoom(room);
        break;
      case KeyChatEventKinds.groupChangeRoomName:
        await isAdminCheck(room, signPubkey, member);
        room.name = toSaveMsg.content;
        await roomService.updateRoom(room);
        toSaveMsg.content = '🤖 New room name: ${toSaveMsg.content}';
        break;
      case KeyChatEventKinds.groupRemoveSingleMember:
        await isAdminCheck(room, signPubkey, member);
        if (ext != null) {
          await room.removeMember(ext);
          await updateChatControllerMembers(room.id);

          // Check if I am still in the group, otherwise I will be marked as kicked out of the group
          RoomMember? rm = await room.getMemberByIdPubkey(room.myIdPubkey);
          if (rm == null || rm.status == UserStatusType.removed) {
            toSaveMsg.content = '🤖 You have been removed from the group.';
            room.status = RoomStatus.removedFromGroup;
            room = await RoomService().updateRoom(room);
            updateChatControllerMembers(room.id);
            RoomService.getController(room.id)?.setRoom(room);
          }
        }
        break;
      case KeyChatEventKinds.dm:
        if (ext != null) {
          toSaveMsg.reply = MsgReply.fromJson(jsonDecode(ext));
        }
        break;
      default:
    }

    await MessageService().saveMessageModel(toSaveMsg);
  }

  processInvite(Room idRoom, NostrEventModel event, RoomProfile roomProfile,
      String realMessage) async {
    String? toRoomPriKey = roomProfile.prikey; // shared private key
    String groupName = roomProfile.name;
    String groupRelay = roomProfile.groupRelay ?? KeychatGlobal.defaultRelay;
    List<dynamic> users = roomProfile.users;
    List groupInviteMsg = jsonDecode(realMessage);
    String senderIdPubkey = groupInviteMsg[1];
    Identity identity = idRoom.getIdentity();

    if (senderIdPubkey == identity.secp256k1PKHex) {
      return;
    }
    // check is in group?
    if (idRoom.type == RoomType.common) {
      bool isMemeber = checkUserInList(users, idRoom.toMainPubkey);
      if (!isMemeber) {
        logger.d('You are not in the group');
        throw Exception('You are not in the group, so can\'t invite me.');
      }
    }
    // roomProfile.oldToRoomPubKey 是 room 唯一标识，所有人同步
    Room? groupRoom = await roomService.getRoomByIdentity(
        roomProfile.oldToRoomPubKey!, idRoom.identityId);
    if (groupRoom == null) {
      if (roomProfile.groupType == GroupType.shareKey) {
        await MessageService().saveMessageToDB(
            from: event.pubkey,
            to: event.tags[0][1],
            idPubkey: idRoom.toMainPubkey,
            events: [event],
            room: idRoom,
            isMeSend: false,
            isSystem: true,
            encryptType: MessageEncryptType.nip4WrapNip4,
            sent: SendStatusType.success,
            mediaType: MessageMediaType.groupInvite,
            requestConfrim: RequestConfrimEnum.request,
            content: roomProfile.toString(),
            realMessage: 'Invite you to join group: $groupName');
        return;
      } else {
        await DBProvider.database.writeTxn(() async {
          try {
            groupRoom = await GroupTx().joinGroup(roomProfile, identity);

            await MessageService().saveMessageToDB(
                from: event.pubkey,
                to: event.tags[0][1],
                idPubkey: idRoom.toMainPubkey,
                events: [event],
                room: groupRoom!,
                isMeSend: false,
                isSystem: true,
                encryptType: MessageEncryptType.nip4WrapNip4,
                sent: SendStatusType.success,
                content: roomProfile.toString(),
                realMessage: 'Invite you to join group: $groupName',
                persist: false);
          } catch (e, s) {
            logger.e(e.toString(), error: e, stackTrace: s);
          }
        });
        if (groupRoom != null) {
          await Get.find<HomeController>()
              .loadIdentityRoomList(groupRoom!.identityId);
        }
        return;
      }
    }
    // start to update room
    // check room version
    if ((roomProfile.updatedAt ?? 0) > groupRoom.version) {
      groupRoom.version = roomProfile.updatedAt!;
    } else {
      return;
    }
    // When the room has been created, verify whether the sender is in the group.
    RoomMember? member = await groupRoom.getEnableMember(senderIdPubkey);
    if (member == null) {
      logger.d('Not a vaild member in group');
      throw Exception('Not a vaild member in group');
    }

    groupRoom.status = RoomStatus.enabled;
    groupRoom.name = groupName;
    groupRoom.groupRelay = groupRelay;

    // Whether the shared secret key key changes
    bool isKeyChange = false;
    if (groupRoom.isShareKeyGroup && toRoomPriKey != null) {
      Mykey roomKey = groupRoom.mykey.value!;

      if (groupRoom.mykey.value!.prikey != toRoomPriKey) {
        isKeyChange = true;
        await DBProvider.database.writeTxn(() async {
          roomKey = await GroupTx().importMykeyTx(
              identity, await rustNostr.importKey(senderKeys: toRoomPriKey));
        });
        groupRoom.mykey.value = roomKey;
        await Get.find<WebsocketService>()
            .listenPubkey([roomKey.pubkey], limit: 300);
        NotifyService.addPubkeys([roomKey.pubkey]);
      }

      // if is p2p message, then send: I am in
      if (event.tags[0][1] != roomKey.pubkey) {
        await GroupService().sendMessageToGroup(
            groupRoom, '${identity.displayName} $joinGreeting',
            subtype: KeyChatEventKinds.groupHi, sentCallback: (res) {});
      }
    }
    await RoomService().updateRoom(groupRoom, updateMykey: isKeyChange);
    RoomService().updateChatRoomPage(groupRoom);

    await groupRoom.updateAllMember(users);
    await updateChatControllerMembers(groupRoom.id);

    if (idRoom.type == RoomType.common && groupRoom.isShareKeyGroup) return;

    Message message = Message(
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
            : MessageEncryptType.nip4,
        isSystem: true,
        isMeSend: false,
        content: groupInviteMsg[0],
        createdAt: timestampToDateTime(event.createdAt));
    await MessageService().saveMessageModel(message);
  }

  @override
  processMessage(
      {required Room room,
      required KeychatMessage km,
      required NostrEventModel event,
      NostrEventModel? sourceEvent,
      String? msgKeyHash,
      required Relay relay}) async {
    switch (km.type) {
      case KeyChatEventKinds.groupInvite:
        RoomService().checkMessageValid(room, sourceEvent ?? event);
        RoomProfile roomProfile = RoomProfile.fromJson(jsonDecode(km.msg!));
        String realMessage = km.name ?? "[]";
        return await processInvite(room, event, roomProfile, realMessage);
      case KeyChatEventKinds.groupSharedKeyMessage:
        NostrEventModel subEvent =
            NostrEventModel.fromJson(jsonDecode(km.msg!));
        String? content = await NostrAPI().getDecodeNip4Content(subEvent);
        content ??= '[GroupMessage decoded failed]';
        GroupMessage gm = GroupMessage.fromJson(jsonDecode(content));
        return await processGroupMessage(room, subEvent, gm,
            relay: relay, sourceEvent: event, msgKeyHash: msgKeyHash);
      case KeyChatEventKinds.groupChangeSignKey:
        RoomProfile roomProfile = RoomProfile.fromJson(jsonDecode(km.msg!));
        return await processChangeSignKey(room, event, roomProfile);
      case KeyChatEventKinds.groupRemoveSingleMember:
        return await _processGroupRemoveSingleMember(
          room,
          km,
          event,
        );
      case KeyChatEventKinds.groupSendToAllMessage:
        GroupMessage gm = GroupMessage.fromJson(jsonDecode(km.msg!));

        Room? groupRoom =
            await RoomService().getRoomByIdentity(gm.pubkey, room.identityId);
        if (groupRoom == null) {
          return;
        }
        RoomMember? member = await groupRoom.getMember(room.toMainPubkey);
        if (member == null) {
          if (gm.subtype != KeyChatEventKinds.groupHi) {
            logger.i('Not a member in group ${groupRoom.id}');
            return;
          }
        }
        return await processGroupMessage(groupRoom, event, gm,
            member: member, idRoom: room, relay: relay, msgKeyHash: msgKeyHash);
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
  inviteToJoinGroup(Room groupRoom, {List<String> toUsers = const []}) async {
    if (toUsers.isEmpty) return;
    Identity identity = groupRoom.getIdentity();
    await roomService.checkRoomStatus(groupRoom);
    List<RoomMember> allMembers = await groupRoom.getMembers();
    List<RoomMember> toMembers = [];
    UserStatusType status = groupRoom.isSendAllGroup
        ? UserStatusType.invited
        : UserStatusType.inviting;
    DateTime now = DateTime.now();

    // Add to the local contact list in batches, update if it exists, create if it does not exist
    for (var idPubkey in toUsers) {
      RoomMember? rm = allMembers
          .firstWhereOrNull((element) => element.idPubkey == idPubkey);
      if (rm == null) {
        Contact c = await contactService.getOrCreateContact(
            groupRoom.identityId, idPubkey);
        rm = await groupRoom.addMember(
            name: c.displayName,
            curve25519PkHex: c.curve25519PkHex,
            idPubkey: idPubkey,
            status: status,
            createdAt: now,
            updatedAt: now);
      } else {
        if (rm.status != UserStatusType.invited) {
          rm.status = status;
          rm.updatedAt = now;
          await groupRoom.updateMember(rm);
        }
      }
      toMembers.add(rm);
    }

    allMembers = await groupRoom.getMembers();

    Mykey? roomMykey = groupRoom.mykey.value;
    String roomPubkey =
        roomMykey == null ? groupRoom.toMainPubkey : roomMykey.pubkey;
    RoomProfile roomProfile = RoomProfile(
        roomPubkey, groupRoom.name!, allMembers, groupRoom.groupType)
      ..oldToRoomPubKey = groupRoom.toMainPubkey
      ..prikey = roomMykey?.prikey
      ..groupRelay = groupRoom.groupRelay
      ..updatedAt = DateTime.now().millisecondsSinceEpoch;

    List<String> addUsersName = toMembers.map((e) => e.name).toList();
    String realMessage = '🤖 Invite ${addUsersName.join(',')} to join group';

    KeychatMessage km = KeychatMessage(
        c: MessageType.group,
        type: KeyChatEventKinds.groupInvite,
        msg: jsonEncode(roomProfile.toJson()))
      ..name = jsonEncode([realMessage, groupRoom.myIdPubkey]);
    if (groupRoom.isShareKeyGroup) {
      await _inviteSharekeyGroup(
          realMessage, toMembers, identity, groupRoom, km);
    } else if (groupRoom.isSendAllGroup) {
      await _invitePairwiseGroup(realMessage, identity, groupRoom, km);
    }

    RoomService.getController(groupRoom.id)?.resetMembers();
  }

  Future removeMember(Room room, RoomMember rm) async {
    if (room.isShareKeyGroup) {
      await _removeMemberSharekey(room, rm);
    } else if (room.isSendAllGroup) {
      await _removeMemberPairwise(room, rm);
    }
  }

  // Share secret key to send group messages, use double-layer nesting to send information
  // Sub event: sender private key  --> room's pubkey
  // Main event: room's private key--> room's pubkey
  @override
  Future<SendMessageResponse> sendMessage(Room room, String message,
      {int? subtype,
      String? ext,
      MsgReply? reply,
      String? realMessage,
      MessageMediaType? mediaType,
      Function(bool)? sentCallback,
      bool save = true}) async {
    Mykey roomKey = room.mykey.value!;

    GroupMessage gm = _getGroupMessage(room, message,
        pubkey: '', reply: reply, subtype: subtype, ext: ext);
    String subEncryptedEvent = await rustNostr.getEncryptEvent(
        senderKeys: room.getIdentity().secp256k1SKHex,
        receiverPubkey: roomKey.pubkey,
        content: gm.toString());

    KeychatMessage km = KeychatMessage(
        c: MessageType.group,
        type: KeyChatEventKinds.groupSharedKeyMessage,
        msg: subEncryptedEvent);

    String encryptedEvent = await rustNostr.getEncryptEvent(
        senderKeys: roomKey.prikey,
        receiverPubkey: roomKey.pubkey,
        content: km.toString());

    NostrEventModel event =
        NostrEventModel.fromJson(jsonDecode(encryptedEvent), verify: false);

    List<String> relays = await Get.find<WebsocketService>().writeNostrEvent(
        event: event,
        encryptedEvent: encryptedEvent,
        roomId: room.id,
        hisRelay: room.groupRelay ?? KeychatGlobal.defaultRelay,
        sentCallback: sentCallback);

    Message? model;
    if (subtype == null && ext == null) {
      await dbProvider.saveMyEventLog(event: event, relays: relays);
      Identity identity = room.getIdentity();

      model = await MessageService().saveMessageToDB(
          events: [event],
          room: room,
          reply: reply,
          content: message,
          from: identity.secp256k1PKHex,
          idPubkey: identity.secp256k1PKHex,
          to: room.toMainPubkey,
          realMessage: realMessage,
          isMeSend: true,
          encryptType: MessageEncryptType.nip4WrapNip4,
          mediaType: mediaType,
          isRead: true);
    }
    return SendMessageResponse(relays: relays, events: [event], message: model);
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

    GroupMessage gm = _getGroupMessage(room, message,
        pubkey: room.toMainPubkey, reply: reply, subtype: subtype, ext: ext);

    KeychatMessage km = KeychatMessage(
        c: MessageType.group,
        type: KeyChatEventKinds.groupSendToAllMessage,
        msg: jsonEncode(gm.toJson()));
    String toSendMessage = jsonEncode(km.toJson());
    List<NostrEventModel> events = [];

    List<Room>? memberRooms = [];
    ChatController? cc = RoomService.getController(room.id);
    if (cc != null) {
      memberRooms = cc.memberRooms.values.toList();
    } else {
      memberRooms = (await room.getEnableMemberRooms()).values.toList();
    }

    if (memberRooms.isEmpty) {
      throw Exception('no member in group');
    }
    final queue = Queue(parallel: 10);
    ChatxService cs = Get.find<ChatxService>();

    List<String> toAddPubkeys = [];
    List<Room> kapIsNullCount = [];
    BaseChatService chatService = SignalChatService();
    for (Room idRoom in memberRooms) {
      if (idRoom.toMainPubkey == idRoom.myIdPubkey) continue;
      queue.add(() async {
        idRoom.parentRoom = room;
        try {
          KeychatProtocolAddress? kpa = await cs.getRoomKPA(idRoom);
          if (kpa == null) {
            kapIsNullCount.add(idRoom);
            return; // skip nip04 room
          }

          SendMessageResponse smr =
              await chatService.sendMessage(idRoom, toSendMessage, save: false);

          msgKeyHash = smr.msgKeyHash;
          toAddPubkeys.addAll(smr.toAddPubkeys ?? []);
          events.add(smr.events[0]);
          await dbProvider.saveMyEventLog(
              event: smr.events[0],
              relays: smr.relays,
              toIdPubkey: idRoom.toMainPubkey);
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
      Get.find<WebsocketService>().listenPubkey(toAddPubkeys,
          since: DateTime.now().subtract(const Duration(seconds: 60)));
      NotifyService.addPubkeys(toAddPubkeys);
    }

    Message? model;
    if (events.isNotEmpty) {
      Identity identity = room.getIdentity();

      model = await MessageService().saveMessageToDB(
          events: events,
          room: room,
          content: message,
          realMessage: realMessage,
          from: identity.secp256k1PKHex,
          idPubkey: identity.secp256k1PKHex,
          to: room.toMainPubkey,
          isMeSend: true,
          encryptType: MessageEncryptType.signal,
          reply: reply,
          mediaType: mediaType,
          msgKeyHash: msgKeyHash,
          sent: SendStatusType.sending,
          isRead: true);
    }
    return SendMessageResponse(relays: [], events: events, message: model);
  }

  updateChatControllerMembers(int roomId) {
    RoomService.getController(roomId)?.resetMembers();
  }

  Future updateRoomMykey(Room room, Mykey newMykey) async {
    if (!room.isShareKeyGroup) {
      return;
    }
    Isar database = DBProvider.database;
    int? mykeyId = room.mykey.value?.id;
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

  Future<Room> _createGroupToDB(String toMainPubkey, String groupName,
      {List<dynamic> members = const [],
      required GroupType groupType,
      required Identity identity,
      required int version,
      Mykey? sharedKey,
      String? groupRelay}) async {
    if (groupType == GroupType.shareKey && sharedKey == null) {
      throw Exception('sharedKey is required');
    }
    Room room = Room(
        toMainPubkey: toMainPubkey,
        npub: rustNostr.getBech32PubkeyByHex(hex: toMainPubkey),
        identityId: identity.id,
        status: RoomStatus.enabled,
        type: RoomType.group)
      ..name = groupName
      ..groupType = groupType
      ..version = version
      ..groupRelay = groupRelay;
    if (sharedKey != null) {
      room.mykey.value = sharedKey;
    }

    room = await roomService.updateRoom(room, updateMykey: sharedKey != null);
    await room.updateAllMember(members);
    RoomMember? me = await room.getMember(identity.secp256k1PKHex);

    if (me != null && me.status != UserStatusType.invited) {
      me.status = UserStatusType.invited;
      await room.updateMember(me);
    }
    // listen
    if (room.isShareKeyGroup) {
      await Get.find<WebsocketService>()
          .listenPubkey([toMainPubkey], limit: 300);
      NotifyService.addPubkeys([toMainPubkey]);
    }
    return room;
  }

  _getGroupMessage(Room room, String message,
      {int? subtype,
      required String pubkey,
      String? ext,
      String? sig,
      MsgReply? reply}) {
    GroupMessage gm = GroupMessage(message: message, pubkey: pubkey, sig: sig)
      ..subtype = subtype
      ..ext = ext;

    if (reply != null) {
      gm.subtype = KeyChatEventKinds.dm;
      gm.ext = reply.toString(); // EventId
    }
    return gm;
  }

  // Send a group message to all enabled users
  Future _invitePairwiseGroup(String realMessage, Identity identity,
      Room groupRoom, KeychatMessage km) async {
    // final queue = Queue(parallel: 5);
    List<RoomMember> enables = await groupRoom.getEnableMembers();
    List<RoomMember> invitings = await groupRoom.getInvitingMembers();
    var todo = collection.Queue.from([...enables, ...invitings]);
    km.name = jsonEncode([realMessage, identity.secp256k1PKHex]);
    List<NostrEventModel> events = [];
    int membersLength = todo.length;

    for (int i = 0; i < membersLength; i++) {
      // queue.add(() async {
      //   if (todo.isEmpty) return;
      RoomMember rm = todo.removeFirst();
      if (identity.secp256k1PKHex == rm.idPubkey) continue;
      try {
        Room memberRoom = await RoomService().getOrCreateRoomByIdentity(
            rm.idPubkey, identity, RoomStatus.groupUser);
        var res = await Nip4ChatService().sendMessage(memberRoom, km.toString(),
            realMessage: realMessage, save: false);

        if (res.events.isNotEmpty) {
          events.add(res.events[0]);
          await dbProvider.saveMyEventLog(
              event: res.events[0],
              relays: res.relays,
              toIdPubkey: rm.idPubkey);
        }
      } catch (e, s) {
        logger.e(e.toString(), error: e, stackTrace: s);
      }
    }
    // );
    // }
    // await queue.onComplete;
    Message message = Message(
        identityId: groupRoom.identityId,
        msgid: events[0].id,
        eventIds: events.map((e) => e.id).toList(),
        roomId: groupRoom.id,
        from: identity.secp256k1PKHex,
        idPubkey: identity.secp256k1PKHex,
        to: groupRoom.toMainPubkey,
        encryptType: groupRoom.isSendAllGroup
            ? MessageEncryptType.signal
            : MessageEncryptType.nip4,
        sent: SendStatusType.success,
        isSystem: true,
        isMeSend: true,
        content: realMessage,
        createdAt: timestampToDateTime(events[0].createdAt))
      ..isRead = true;
    await MessageService().saveMessageModel(message);
  }

  Future _inviteSharekeyGroup(String realMessage, List<RoomMember> toUsers,
      Identity identity, Room groupRoom, KeychatMessage km) async {
    final queue = Queue(parallel: 5);
    var todo = collection.Queue.from(toUsers);
    int membersLength = todo.length;
    for (int i = 0; i < membersLength; i++) {
      queue.add(() async {
        if (todo.isEmpty) return;
        RoomMember rm = todo.removeFirst();
        String hexPubkey = rustNostr.getHexPubkeyByBech32(bech32: rm.idPubkey);
        if (identity.secp256k1PKHex == hexPubkey) return;
        try {
          await nostrAPI.sendNip4Message(
            save: groupRoom.isSendAllGroup,
            hexPubkey,
            km.toString(),
            room: groupRoom,
            encryptType: MessageEncryptType.nip4,
            prikey: identity.secp256k1SKHex,
            from: identity.secp256k1PKHex,
            realMessage: realMessage,
          );
        } catch (e, s) {
          logger.e(e.toString(), error: e, stackTrace: s);
        }
      });
    }
    await queue.onComplete;
    Mykey roomMykey = groupRoom.mykey.value!;
    await nostrAPI.sendNip4Message(roomMykey.pubkey, km.toString(),
        room: groupRoom,
        prikey: roomMykey.prikey,
        from: roomMykey.pubkey,
        encryptType: MessageEncryptType.nip4,
        realMessage: realMessage);
  }

  Future _processGroupHi(
      Room groupRoom, String idPubkey, DateTime updatedAt, String name) async {
    RoomMember? rm = await groupRoom.getMember(idPubkey);
    if (rm == null) {
      logger.d('Not a member in group ${groupRoom.id}, $idPubkey');
      return;
    }

    rm.status = UserStatusType.invited;
    rm.updatedAt = updatedAt;
    rm.name = name;
    await groupRoom.updateMember(rm);

    updateChatControllerMembers(groupRoom.id);
  }

  // Received the news that I was baned from the group
  Future _processGroupRemoveSingleMember(
      Room idRoom, KeychatMessage km, NostrEventModel event) async {
    String? toMainPubkey = km.msg;
    if (toMainPubkey == null) return;
    Room? groupRoom =
        await RoomService().getRoomByIdentity(toMainPubkey, idRoom.identityId);
    if (groupRoom == null) return;
    RoomMember? member =
        await groupRoom.getMemberByIdPubkey(idRoom.toMainPubkey);
    if (member == null) return;
    if (!member.isAdmin) throw Exception('not admin');

    await MessageService().saveMessageToDB(
        from: event.pubkey,
        to: event.tags[0][1],
        idPubkey: idRoom.toMainPubkey,
        events: [event],
        room: groupRoom,
        isMeSend: false,
        isSystem: true,
        encryptType: MessageEncryptType.nip4,
        sent: SendStatusType.success,
        mediaType: MessageMediaType.text,
        content: event.content,
        realMessage: '🤖 You have been removed');

    groupRoom.status = RoomStatus.removedFromGroup;
    await RoomService().updateRoom(groupRoom);
    RoomService.getController(groupRoom.id)?.setRoom(groupRoom);
    updateChatControllerMembers(groupRoom.id);
  }

  Future _removeMemberPairwise(Room room, RoomMember rm) async {
    String msg = '''Remove member: ${rm.name}
${rm.idPubkey}
''';

    await sendMessageToGroup(room, msg,
        subtype: KeyChatEventKinds.groupRemoveSingleMember, ext: rm.idPubkey);
    await room.setMemberDisable(rm);
    await updateChatControllerMembers(room.id);
  }

  // Shared private key group, delete the user, need to replace the shared private key
  _removeMemberSharekey(Room room, RoomMember rm) async {
    String oldToRoomPubKey = room.toMainPubkey;
    bool isAdmin = await room.checkAdminByIdPubkey(room.myIdPubkey);
    if (!isAdmin) {
      throw Exception('Only admin can change sign key');
    }
    Identity identity = room.getIdentity();

    Mykey myID = await GroupTx().createMykey(identity);

    // room.toMainPubkey = myID.pubkey;
    await updateRoomMykey(room, myID);
    await Get.find<WebsocketService>().listenPubkey([myID.pubkey], limit: 1000);
    await room.setMemberDisable(rm);

    List<RoomMember> newToUsers = await room.getMembers();
    String realMessage = 'Remove member: ${rm.name}';
    RoomProfile roomProfile =
        RoomProfile(myID.pubkey, room.name!, newToUsers, room.groupType)
          ..prikey = myID.prikey
          ..ext = realMessage
          ..oldToRoomPubKey = oldToRoomPubKey;

    // send msg to user_should_be_remove
    KeychatMessage kmToRemove = KeychatMessage(
        c: MessageType.group,
        type: KeyChatEventKinds.groupRemoveSingleMember,
        msg: oldToRoomPubKey);

    await nostrAPI.sendNip4Message(
      rm.idPubkey,
      kmToRemove.toString(),
      room: room,
      encryptType: MessageEncryptType.nip4,
      prikey: identity.secp256k1SKHex,
      from: identity.secp256k1PKHex,
      realMessage: '$realMessage Send to: ${rm.name}',
    );

    // send msg to all enable with allUsers and newPrikey
    KeychatMessage km = KeychatMessage(
        c: MessageType.group,
        type: KeyChatEventKinds.groupChangeSignKey,
        msg: roomProfile.toString(),
        name: realMessage);
    List<RoomMember> enables = await room.getEnableMembers();

    for (RoomMember element in enables) {
      if (identity.secp256k1PKHex == element.idPubkey ||
          element.status != UserStatusType.invited) {
        continue;
      }
      await nostrAPI.sendNip4Message(
        element.idPubkey,
        km.toString(),
        room: room,
        encryptType: MessageEncryptType.nip4,
        prikey: identity.secp256k1SKHex,
        from: identity.secp256k1PKHex,
        realMessage: '$realMessage Send to: ${element.name}',
      );
    }

    RoomService.getController(room.id)?.resetMembers();
  }

  Future sendMessageToGroup(
    Room room,
    String message, {
    bool save = true,
    int? subtype,
    String? ext,
    String? realMessage,
    Function(bool)? sentCallback,
  }) async {
    if (room.type != RoomType.group) throw Exception('room type error');
    if (room.groupType == GroupType.shareKey) {
      return await sendMessage(room, message,
          subtype: subtype,
          ext: ext,
          save: save,
          realMessage: realMessage,
          sentCallback: sentCallback);
    }

    if (room.groupType == GroupType.sendAll) {
      return await sendToAllMessage(room, message,
          subtype: subtype, ext: ext, realMessage: realMessage);
    }
  }
}
