import 'dart:convert' show jsonDecode;

import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;
import 'package:app/service/chat.service.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/signalChat.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:aws/aws.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';

import '../constants.dart';
import '../controller/chat.controller.dart';
import '../controller/home.controller.dart';
import '../models/db_provider.dart';
import '../nostr-core/nostr.dart';
import 'contact.service.dart';
import 'file_util.dart';
import 'group.service.dart';
import 'identity.service.dart';
import 'message.service.dart';

class RoomService extends BaseChatService {
  static final RoomService _singleton = RoomService._internal();
  static final DBProvider dbProvider = DBProvider();
  static final GroupService groupService = GroupService();
  static final ContactService contactService = ContactService();
  HomeController homeController = Get.find<HomeController>();

  factory RoomService() {
    return _singleton;
  }

  RoomService._internal();

  Future checkRoomStatus(Room room) async {
    if (room.status == RoomStatus.dissolved) {
      throw Exception('Room had been dissolved');
    }

    if (room.status == RoomStatus.removedFromGroup) {
      throw Exception('You have been removed from the group.');
    }
  }

  Future<Room> createPrivateRoom(
      {required String toMainPubkey,
      required Identity identity,
      required RoomStatus status,
      String? name,
      Contact? contact,
      String? curve25519PkHex,
      String? onetimekey}) async {
    int identityId = identity.id;
    Room? exist = await getRoomByIdentity(toMainPubkey, identityId);
    if (exist != null) return exist;
    Room room = Room(
      toMainPubkey: toMainPubkey,
      identityId: identityId,
      status: status,
      npub: rustNostr.getBech32PubkeyByHex(hex: toMainPubkey),
    )
      ..onetimekey = onetimekey
      ..status = status
      ..curve25519PkHex = curve25519PkHex;

    if (toMainPubkey == identity.secp256k1PKHex) {
      room.encryptMode = EncryptMode.nip04;
      name = KeychatGlobal.selfName;
    }

    room = await updateRoom(room);
    contact ??=
        await ContactService().getContact(identityId, room.toMainPubkey);
    contact ??= Contact(
        identityId: room.identityId,
        pubkey: room.toMainPubkey,
        npubkey: rustNostr.getBech32PubkeyByHex(hex: room.toMainPubkey))
      ..name = name;
    await ContactService().saveContact(contact);
    contact = await ContactService().getContact(identityId, room.toMainPubkey);
    room.contact = contact;
    await homeController.loadIdentityRoomList(room.identityId);

    return room;
  }

  Future deleteRoom(Room room) async {
    Isar database = DBProvider.database;
    int? roomMykeyId = room.mykey.value?.id;
    var groupType = room.groupType;
    var roomType = room.type;
    int roomId = room.id;
    await database.writeTxn(() async {
      if (room.type == RoomType.group) {
        if (roomMykeyId != null) {
          await database.mykeys.filter().idEqualTo(roomMykeyId).deleteFirst();
        }
        await database.roomMembers.filter().roomIdEqualTo(roomId).deleteAll();
      } else {
        if (room.curve25519PkHex != null) {
          await Get.find<ChatxService>().deleteSignalSessionKPA(room);
        }
      }
      await database.messages.filter().roomIdEqualTo(roomId).deleteAll();
      await database.messageBills.filter().roomIdEqualTo(roomId).deleteAll();
      await database.rooms.filter().idEqualTo(roomId).deleteFirst();
      await FileUtils.deleteFolderByRoomId(room.identityId, room.id);
    });
    if (roomType == RoomType.group && groupType == GroupType.shareKey) {
      NotifyService.removePubkeys([room.toMainPubkey]);
    }
  }

  deleteRoomMessage(Room room) async {
    await FileUtils.deleteFolderByRoomId(room.identityId, room.id);

    await DBProvider.database.writeTxn(() async {
      return DBProvider.database.messages
          .filter()
          .roomIdEqualTo(room.id)
          .deleteAll();
    });
  }

  Future<List<Room>> getGroupsSharedKey() async {
    return await DBProvider.database.rooms
        .filter()
        .typeEqualTo(RoomType.group)
        .groupTypeEqualTo(GroupType.shareKey)
        .findAll();
  }

  // get room by send_pubkey and bob_pubkey
  Future<Room> getOrCreateRoom(String from, String to, RoomStatus status,
      {String? contactName}) async {
    Room? room = await getRoom(from, to);
    if (room != null) {
      await ContactService().updateOrCreateByRoom(room, contactName);
      return room;
    }

    Identity? identity = await IdentityService().getIdentityByPubkey(to);
    if (identity == null) {
      throw Exception('no this identity');
    }
    return await createPrivateRoom(
        toMainPubkey: from,
        identity: identity,
        status: status,
        name: contactName);
  }

  Future<Room> getOrCreateRoomByIdentity(
      String toMainPubkey, Identity identity, RoomStatus status) async {
    Room? room = await getRoomByIdentity(toMainPubkey, identity.id);
    if (room != null) return room;

    room = await createPrivateRoom(
        toMainPubkey: toMainPubkey, identity: identity, status: status);
    return room;
  }

  Future<Room?> getRoom(String from, String to) async {
    Isar database = DBProvider.database;

    Room? signalRatchetRoom = await _getRoomByReceiveKey(to);
    if (signalRatchetRoom != null) return signalRatchetRoom;

    // common chat. from is room mainkey, to is my identity'pubkey
    List<Room> nip4Rooms =
        await database.rooms.filter().toMainPubkeyEqualTo(from).findAll();

    for (var room in nip4Rooms) {
      Identity identity = homeController.identities[room.identityId]!;
      if (identity.secp256k1PKHex == to) {
        return room;
      }
    }

    // group share key
    if (from == to) {
      Room? groupRoom = await database.rooms
          .filter()
          .typeEqualTo(RoomType.group)
          .groupTypeEqualTo(GroupType.shareKey)
          .mykey((q) => q.pubkeyEqualTo(to))
          .findFirst();

      if (groupRoom != null) return groupRoom;
    }
    return null;
  }

  Future<Room?> getRoomById(int id) async {
    Isar database = DBProvider.database;

    return await database.rooms.filter().idEqualTo(id).findFirst();
  }

  Future<Room?> getRoomByIdentity(String from, int identityId) async {
    Isar database = DBProvider.database;

    return await database.rooms
        .filter()
        .toMainPubkeyEqualTo(from)
        .identityIdEqualTo(identityId)
        .findFirst();
  }

  Future<Room?> getRoomAndContainSession(String from, int identityId) async {
    Room? room = await DBProvider.database.rooms
        .filter()
        .toMainPubkeyEqualTo(from)
        .identityIdEqualTo(identityId)
        .findFirst();
    if (room == null) return null;
    if (room.curve25519PkHex != null) {
      var res = await Get.find<ChatxService>().getRoomKPA(room);
      return res == null ? null : room;
    }
    return null;
  }

  Future<Room> getRoomByIdOrFail(int id) async {
    Room? exist = await getRoomById(id);
    if (exist == null) throw Exception('room is null');
    return exist;
  }

  Room? getRoomByIdSync(int id) {
    Isar database = DBProvider.database;

    return database.rooms.filter().idEqualTo(id).findFirstSync();
  }

  Future<Map<String, List<Room>>> getRoomList({required int indetityId}) async {
    Isar database = DBProvider.database;

    List<Room> list = await database.rooms
        .filter()
        .identityIdEqualTo(indetityId)
        .not()
        .statusEqualTo(RoomStatus.groupUser) // not include init
        .sortByCreatedAtDesc()
        .findAll();
    List<Room> friendsRoom = [];
    List<Room> approving = [];
    List<Room> requesting = [];
    for (Room room in list) {
      room.unReadCount = await MessageService().unreadCountByRoom(room.id);
      var lastMessageModel =
          await MessageService().getLastMessageByRoom(room.id);

      // sub contend
      if (lastMessageModel != null) {
        if (lastMessageModel.content.length > 50) {
          lastMessageModel.content = lastMessageModel.content.substring(0, 50);
        }
        room.lastMessageModel = lastMessageModel;
      }
      if (room.type != RoomType.common) {
        friendsRoom.add(room);
        continue;
      }
      room.contact = await contactService.getOrCreateContact(
          room.identityId, room.toMainPubkey,
          curve25519PkHex: room.curve25519PkHex);
      if (room.status == RoomStatus.requesting) {
        requesting.add(room); // not friend
        continue;
      }

      if (room.status == RoomStatus.approving) {
        approving.add(room);
        continue;
      }

      friendsRoom.add(room);
    }

    friendsRoom.sort((a, b) {
      if (a.pin || b.pin) {
        if (a.pin && b.pin) {
          return b.pinAt!.compareTo(a.pinAt!);
        }
        return a.pin ? -1 : 1;
      }
      if (a.lastMessageModel == null) return 1;
      if (b.lastMessageModel == null) return -1;
      return b.lastMessageModel!.createdAt
          .compareTo(a.lastMessageModel!.createdAt);
    });

    // anonymous.sort((a, b) {
    //   if (a.lastMessageModel == null) return 1;
    //   if (b.lastMessageModel == null) return -1;
    //   return b.lastMessageModel!.createdAt
    //       .compareTo(a.lastMessageModel!.createdAt);
    // });
    return {
      'friends': friendsRoom,
      'approving': approving,
      'requesting': requesting
    };
  }

  Future<Room> getRoomOrFail(String from, String to) async {
    Room? room = await getRoom(from, to);
    if (room == null) throw Exception('room is null');
    return room;
  }

  Future processKeychatMessage(
    NostrEventModel event, // as subEvent
    Map<String, dynamic> content,
    Relay relay, [
    NostrEventModel? sourceEvent, // parent event
  ]) async {
    KeychatMessage km = KeychatMessage.fromJson(content);
    String toAddress = event.tags[0][1];
    Identity? identity;
    Mykey? mykey;
    List<Identity> identities = homeController.identities.values
        .where((element) => element.secp256k1PKHex == toAddress)
        .toList();
    if (identities.isNotEmpty) {
      identity = identities[0];
    } else {
      // onetime-key is receive address
      mykey = await IdentityService().getMykeyByPubkey(toAddress);
      if (mykey != null) {
        identity = homeController.identities[mykey.identityId];
      }
    }
    if (identity == null) throw Exception('My receive address is null');

    Room room = await getOrCreateRoomByIdentity(
        event.pubkey, identity, RoomStatus.init);
    await km.service.processMessage(
        room: room,
        event: event,
        km: km,
        relay: relay,
        sourceEvent: sourceEvent);

    return;
  }

  @override
  Future processMessage(
      {required Room room,
      required NostrEventModel event,
      NostrEventModel? sourceEvent,
      String? msgKeyHash,
      required KeychatMessage km,
      required Relay relay}) async {
    switch (km.type) {
      // case KeyChatEventKinds.webrtcAudioCall:
      // case KeyChatEventKinds.webrtcVideoCall:
      //   await _processWebRTCCall(room, event, km, sourceEvent);
      //   break;
      // case KeyChatEventKinds.webrtcCancel:
      //   await _processWebRTCCancel(room, event, km, sourceEvent);
      //   break;
      // case KeyChatEventKinds.webrtcEnd:
      //   await _processWebRTCEnd(room, event, km, sourceEvent);
      //   break;
      // case KeyChatEventKinds.webrtcSignaling:
      // WebRTCController? wc = getGetxController<WebRTCController>();
      // receiveDM(room, event, km, sourceEvent,
      //     realMessage: km.msg, isSystem: true, isRead: true);
      // wc?.signaling?.onMessage(jsonDecode(km.msg!));
      default:
        logger.e('not processed!!!');
    }
  }

  Future receiveDM(Room room, NostrEventModel event, KeychatMessage km,
      NostrEventModel? sourceEvent,
      {bool? isSystem,
      String? realMessage,
      bool? isRead,
      String? msgKeyHash}) async {
    String content = realMessage ?? km.msg!;
    MsgReply? reply;
    if (km.type == KeyChatEventKinds.dm && km.name != null) {
      try {
        reply = MsgReply.fromJson(jsonDecode(km.name!));
        content = km.msg!;
        // ignore: empty_catches
      } catch (e) {}
    }
    late String idPubkey;
    if (room.type == RoomType.common) {
      idPubkey = room.toMainPubkey;
    } else {
      idPubkey = event.pubkey;
    }

    var encryptType =
        MessageService().getMessageEncryptType(event, sourceEvent);
    await MessageService().saveMessageToDB(
        events: [sourceEvent ?? event],
        room: room,
        from: sourceEvent?.pubkey ?? event.pubkey,
        to: sourceEvent?.tags[0][1] ?? event.tags[0][1],
        idPubkey: idPubkey,
        isSystem: isSystem,
        realMessage: realMessage,
        content: content,
        encryptType: encryptType,
        reply: reply,
        sent: SendStatusType.success,
        isMeSend: false,
        isRead: isRead,
        msgKeyHash: msgKeyHash);
  }

  Future sendFileMessage(
      {required Room room,
      required String relativePath,
      required FileEncryptInfo fileInfo,
      required MessageMediaType type}) async {
    var mfi = MsgFileInfo()
      ..localPath = relativePath
      ..url = fileInfo.url
      ..suffix = fileInfo.suffix
      ..key = fileInfo.key
      ..iv = fileInfo.iv
      ..size = fileInfo.size
      ..updateAt = DateTime.now()
      ..ecashToken = fileInfo.ecashToken
      ..status = FileStatus.decryptSuccess;
    return await RoomService().sendTextMessage(
        room, mfi.getUriString(type.name, fileInfo),
        realMessage: mfi.toString(), mediaType: type);
  }

  Future forwardFileMessage(
      {required Room room,
      required String content,
      required MsgFileInfo mfi,
      required MessageMediaType mediaType}) async {
    return await RoomService().sendTextMessage(room, content,
        realMessage: mfi.toString(), mediaType: mediaType);
  }

  @override
  Future<SendMessageResponse> sendMessage(
    Room room,
    String message, {
    bool save = true, // default to save message to db. if false, just boardcast
    MsgReply? reply,
    String? realMessage,
    MessageMediaType? mediaType,
    Function? sentCallback,
  }) {
    throw UnimplementedError();
  }

  Future<SendMessageResponse> sendTextMessage(Room room, String content,
      {MessageMediaType? mediaType,
      EncryptMode? encryptMode,
      MsgReply? reply,
      String? realMessage,
      String? toAddress,
      bool? isSystem}) async {
    String? realMessageContent = realMessage;
    if (realMessage == null && reply != null) {
      realMessageContent = content;
    }
    await _checkWebsocketConnect();

    if (room.type == RoomType.group) {
      room = await getRoomByIdOrFail(room.id);
      return await _sendTextMessageToGroup(room, content,
          reply: reply, realMessage: realMessageContent, mediaType: mediaType);
    }

    SendMessageResponse map;
    encryptMode ??= room.encryptMode;
    if (encryptMode == EncryptMode.nip04) {
      Identity identity = room.getIdentity();

      String sm =
          KeychatMessage.getTextMessage(MessageType.nip04, content, reply);
      map = await NostrAPI().sendNip4Message(toAddress ?? room.toMainPubkey, sm,
          prikey: identity.secp256k1SKHex,
          from: identity.secp256k1PKHex,
          room: room,
          reply: reply,
          realMessage: realMessageContent,
          mediaType: mediaType,
          encryptType: MessageEncryptType.nip4,
          isSystem: isSystem);
    } else {
      String sm = realMessage == null
          ? KeychatMessage.getTextMessage(MessageType.signal, content, reply)
          : content;
      map = await SignalChatService().sendMessage(room, sm,
          realMessage: realMessageContent,
          reply: reply,
          isSystem: isSystem,
          mediaType: mediaType);
    }
    return map;
  }

  updateChatRoomPage(Room room) async {
    ChatController? cc = RoomService.getController(room.id);
    if (cc == null) return;

    room.contact ??=
        await contactService.getContact(room.identityId, room.toMainPubkey);
    cc.setRoom(room);
  }

  Future<Room> updateRoom(Room room, {bool updateMykey = false}) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.rooms.put(room);
      if (updateMykey) {
        await room.mykey.save();
      }
    });
    return room;
  }

  _checkWebsocketConnect() async {
    bool netStatus = homeController.isConnectedNetwork.value;
    if (!netStatus) {
      throw Exception('Lost Network');
    }
    List online = Get.find<WebsocketService>().getOnlineRelayString();
    if (online.isEmpty) {
      throw Exception('Not connected with relay server, please retry');
    }
  }

  Future<Room?> _getRoomByReceiveKey(String address) async {
    ContactReceiveKey? crk = await DBProvider.database.contactReceiveKeys
        .filter()
        .receiveKeysElementContains(address)
        .findFirst();
    if (crk == null) return null;
    Room? room = await DBProvider.database.rooms
        .filter()
        .identityIdEqualTo(crk.identityId)
        .toMainPubkeyEqualTo(crk.pubkey)
        .findFirst();
    return room;
  }

  Future<SendMessageResponse> _sendTextMessageToGroup(
    Room room,
    String message, {
    String? realMessage,
    MessageMediaType? mediaType,
    MsgReply? reply,
  }) async {
    await checkRoomStatus(room);
    if (room.groupType == GroupType.shareKey) {
      return await groupService.sendMessage(room, message,
          reply: reply, realMessage: realMessage, mediaType: mediaType);
    }
    if (room.groupType == GroupType.sendAll) {
      return await groupService.sendToAllMessage(room, message,
          reply: reply, realMessage: realMessage, mediaType: mediaType);
    }
    throw Exception('not support group type');
  }

  static ChatController? getController(int roomId) {
    ChatController? cc;
    try {
      cc = Get.find<ChatController>(tag: roomId.toString());
      // ignore: empty_catches
    } catch (e) {}
    return cc;
  }

  static ChatController getOrCreateController(Room room) {
    ChatController? cc;
    try {
      cc = Get.find<ChatController>(tag: room.id.toString());
    } catch (e) {
      cc = Get.put(ChatController(room), tag: room.id.toString());
    }
    return cc!;
  }

  Future<Room?> createRoomAndsendInvite(String input,
      {bool autoJump = true, Identity? identity, String? greeting}) async {
    identity ??= homeController.getSelectedIdentity();
    // input is a hex string, decode in json
    if (input.length == 64 || input.length == 63) {
      String hexPubkey = input;
      if (input.startsWith('npub') && input.length == 63) {
        hexPubkey = rustNostr.getHexPubkeyByBech32(bech32: input);
      }

      try {
        late Room room;
        // add myself
        if (identity.secp256k1PKHex == hexPubkey) {
          room = await RoomService().getOrCreateRoomByIdentity(
              hexPubkey, identity, RoomStatus.enabled);
        } else {
          for (var iden in homeController.identities.values) {
            if (iden.secp256k1PKHex == hexPubkey) {
              throw Exception('Can not add other identity\' pubkey');
            }
          }
          room = await RoomService().getOrCreateRoomByIdentity(
              hexPubkey, identity, RoomStatus.requesting);
          await SignalChatService()
              .sendHelloMessage(room, identity, greeting: greeting);
          if (room.status != RoomStatus.requesting) {
            room.status = RoomStatus.requesting;
            await RoomService().updateRoom(room);
          }
          EasyLoading.showSuccess('Request sent successfully');
        }

        if (autoJump) {
          await Get.offAndToNamed('/room/${room.id}', arguments: room);
          await homeController.loadIdentityRoomList(identity.id);
        }
        return room;
      } catch (e, s) {
        logger.e('add contact failed', error: e, stackTrace: s);
        EasyLoading.showError(e.toString());
      }
    }
    return null;
  }

  void checkMessageValid(Room room, NostrEventModel nostrEventModel) {
    int createdAt = room.getIdentity().createdAt.millisecondsSinceEpoch ~/ 1000;
    if (nostrEventModel.createdAt < createdAt) {
      throw Exception('ignore_old_message');
    }
  }

  Future markAllRead({required int identityId, required int roomId}) async {
    await MessageService().setViewedMessage(roomId);
    homeController.loadIdentityRoomList(identityId);
  }
}

class SendMessageResponse {
  List<String> relays = [];
  List<NostrEventModel> events = [];
  Message? message;
  List<String>? toAddPubkeys;
  String? msgKeyHash;
  SendMessageResponse(
      {required this.relays,
      required this.events,
      this.message,
      this.msgKeyHash});
}
