import 'dart:collection' as collection;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:app/bot/bot_server_message_model.dart';
import 'package:app/bot/bot_client_message_model.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/chat/RoomUtil.dart';
import 'package:app/service/file.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/signalId.service.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:keychat_rust_ffi_plugin/api_mls.dart' as rust_mls;
import 'package:app/service/chat.service.dart';
import 'package:app/service/chatx.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/signal_chat.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:queue/queue.dart';

import '../constants.dart';
import '../controller/chat.controller.dart';
import '../controller/home.controller.dart';
import '../nostr-core/nostr.dart';
import 'contact.service.dart';
import 'group.service.dart';
import 'identity.service.dart';
import 'message.service.dart';

class RoomService extends BaseChatService {
  static RoomService? _instance;
  static RoomService get instance => _instance ??= RoomService._();
  // Avoid self instance
  RoomService._();
  static final DBProvider dbProvider = DBProvider.instance;
  static final GroupService groupService = GroupService.instance;
  static final ContactService contactService = ContactService.instance;

  Future checkRoomStatus(Room room) async {
    if (room.status == RoomStatus.dissolved) {
      throw Exception('Room had been dissolved');
    }

    if (room.status == RoomStatus.removedFromGroup) {
      throw Exception('You have been removed by admin.');
    }
  }

  Future<Room> createPrivateRoom(
      {required String toMainPubkey,
      required Identity identity,
      required RoomStatus status,
      required EncryptMode encryptMode,
      String? name,
      Contact? contact,
      String? curve25519PkHex,
      String? onetimekey,
      SignalId? signalId,
      RoomType? type}) async {
    int identityId = identity.id;
    Room? exist = await getRoomByIdentity(toMainPubkey, identityId);
    if (exist != null) return exist;
    signalId ??= await SignalIdService.instance.createSignalId(identityId);

    Room room = Room(
      toMainPubkey: toMainPubkey,
      identityId: identityId,
      status: status,
      npub: rust_nostr.getBech32PubkeyByHex(hex: toMainPubkey),
    )
      ..onetimekey = onetimekey
      ..status = status
      ..type = type ?? RoomType.common
      ..encryptMode = encryptMode
      ..curve25519PkHex = curve25519PkHex
      ..signalIdPubkey = signalId!.pubkey;
    // set bot room's name
    if (room.type == RoomType.bot) {
      room.name = name;
    }
    if (toMainPubkey == identity.secp256k1PKHex) {
      room.encryptMode = EncryptMode.nip04;
      name = KeychatGlobal.selfName;
    }

    room = await updateRoom(room);

    // 1v1 room's contact's name
    if (room.type == RoomType.common) {
      contact ??= await ContactService.instance
          .getContact(identityId, room.toMainPubkey);
      contact ??= Contact(
          identityId: room.identityId,
          pubkey: room.toMainPubkey,
          npubkey: rust_nostr.getBech32PubkeyByHex(hex: room.toMainPubkey))
        ..name = name;
      await ContactService.instance.saveContact(contact);
      contact = await ContactService.instance
          .getContact(identityId, room.toMainPubkey);
      room.contact = contact;
    }
    Utils.getGetxController<HomeController>()
        ?.loadIdentityRoomList(room.identityId);
    return room;
  }

  Future deleteRoomHandler(String pubkey, int identityId) async {
    Room? room;
    await ContactService.instance.deleteContactByPubkey(pubkey, identityId);
    room = await RoomService.instance.getRoomByIdentity(pubkey, identityId);
    if (room != null) {
      await RoomService.instance.deleteRoom(room);
    }
  }

  Future deleteRoom(Room room, {bool websocketInited = true}) async {
    Isar database = DBProvider.database;
    int? roomMykeyId = room.mykey.value?.id;
    String? listenPubkey = room.mykey.value?.pubkey;
    var groupType = room.groupType;
    var roomType = room.type;
    int roomId = room.id;
    String toMainPubkey = room.toMainPubkey;
    String? mlsListenPubkey = room.onetimekey;
    // delete room's signalId
    String? signalIdPubkey = room.signalIdPubkey;
    List<Room> sameSignalIdrooms = [];
    if (signalIdPubkey != null) {
      sameSignalIdrooms =
          await RoomService.instance.getRoomBySignalIdPubkey(signalIdPubkey);
    }
    await database.writeTxn(() async {
      if (room.type == RoomType.group) {
        if (roomMykeyId != null) {
          await database.mykeys.filter().idEqualTo(roomMykeyId).deleteFirst();
        }
        await database.roomMembers.filter().roomIdEqualTo(roomId).deleteAll();

        // remove shared signalId
        if (room.isKDFGroup && room.sharedSignalID != null) {
          await DBProvider.database.signalIds
              .filter()
              .identityIdEqualTo(room.identityId)
              .pubkeyEqualTo(room.sharedSignalID!)
              .deleteAll();
        }
      } else {
        if (signalIdPubkey != null && sameSignalIdrooms.length <= 1) {
          await DBProvider.database.signalIds
              .filter()
              .pubkeyEqualTo(signalIdPubkey)
              .identityIdEqualTo(room.identityId)
              .deleteAll();
        }
        // delete session with  verison of signal id
        try {
          await Get.find<ChatxService>().deleteSignalSessionKPA(room);
        } catch (e) {
          logger.e('delete signal session error', error: e);
        }
      }
      await database.contactReceiveKeys
          .filter()
          .pubkeyEqualTo(room.toMainPubkey)
          .deleteAll();
      await database.messages.filter().roomIdEqualTo(roomId).deleteAll();
      await database.nostrEventStatus
          .filter()
          .roomIdEqualTo(roomId)
          .deleteAll();
      await database.rooms.filter().idEqualTo(roomId).deleteFirst();
      await FileService.instance.deleteFolderByRoomId(room.identityId, room.id);
    });
    if (listenPubkey != null) {
      if (roomType == RoomType.group &&
          (groupType == GroupType.shareKey || groupType == GroupType.kdf)) {
        NotifyService.removePubkeys([listenPubkey]);
        if (websocketInited) {
          Get.find<WebsocketService>()
              .removePubkeyFromSubscription(listenPubkey);
        }
      }
    }
    if (roomType == RoomType.group && groupType == GroupType.mls) {
      if (mlsListenPubkey != null) {
        if (websocketInited) {
          Get.find<WebsocketService>()
              .removePubkeyFromSubscription(mlsListenPubkey);
        }
        NotifyService.removePubkeys([mlsListenPubkey]);
      }
      Identity? identity =
          await IdentityService.instance.getIdentityById(room.identityId);
      String? myIdPubkey = identity?.secp256k1PKHex;
      if (myIdPubkey != null) {
        try {
          await rust_mls.deleteGroup(
              nostrId: myIdPubkey, groupId: toMainPubkey);
        } catch (e) {
          logger.i('delete mls group error', error: e);
        }
      }
    }
  }

  deleteRoomMessage(Room room) async {
    await FileService.instance.deleteFolderByRoomId(room.identityId, room.id);

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
        .group((q) => q
            .groupTypeEqualTo(GroupType.shareKey)
            .or()
            .groupTypeEqualTo(GroupType.kdf))
        .findAll();
  }

  Future<List<Room>> getMlsRooms() async {
    return await DBProvider.database.rooms
        .filter()
        .groupTypeEqualTo(GroupType.mls)
        .onetimekeyIsNotEmpty()
        .findAll();
  }

  Future<List<Room>> getMlsRoomsSkipMute() async {
    return await DBProvider.database.rooms
        .filter()
        .groupTypeEqualTo(GroupType.mls)
        .isMuteEqualTo(false)
        .onetimekeyIsNotEmpty()
        .findAll();
  }

  // get room by send_pubkey and bob_pubkey
  Future<Room> getOrCreateRoom(String from, String to, RoomStatus initStatus,
      {String? contactName, Identity? identity, RoomType? type}) async {
    Room? room = await getRoom(from, to, identity);
    if (room != null && room.type == RoomType.common && contactName != null) {
      await ContactService.instance.updateOrCreateByRoom(room, contactName);
      return room;
    }

    identity ??= await IdentityService.instance.getIdentityByNostrPubkey(to);
    if (identity == null) {
      throw Exception('no this identity');
    }
    return await createPrivateRoom(
        toMainPubkey: from,
        identity: identity,
        status: initStatus,
        encryptMode: EncryptMode.nip04,
        type: type,
        name: contactName);
  }

  Future<Room> getOrCreateRoomByIdentity(
      String toMainPubkey, Identity identity, RoomStatus status) async {
    Room? room = await getRoomByIdentity(toMainPubkey, identity.id);
    if (room != null) return room;

    return await createPrivateRoom(
        encryptMode: EncryptMode.nip04,
        toMainPubkey: toMainPubkey,
        identity: identity,
        status: status);
  }

  Future<Room?> getRoom(String from, String to, [Identity? identity]) async {
    Isar database = DBProvider.database;

    Room? signalRatchetRoom = await getRoomByReceiveKey(to);
    if (signalRatchetRoom != null) return signalRatchetRoom;

    // common chat. from is room mainkey, to is my identity'pubkey
    List<Room> nip4Rooms =
        await database.rooms.filter().toMainPubkeyEqualTo(from).findAll();

    for (var room in nip4Rooms) {
      identity ??=
          await IdentityService.instance.getIdentityById(room.identityId);
      if (identity != null && identity.secp256k1PKHex == to) {
        return room;
      }
    }

    // group share key
    if (from == to) {
      return await _getGroupRoom(to);
    }
    return null;
  }

  Future<Room?> _getGroupRoom(String to) async {
    return await DBProvider.database.rooms
        .filter()
        .typeEqualTo(RoomType.group)
        .mykey((q) => q.pubkeyEqualTo(to))
        .findFirst();
  }

  Future<Room?> getGroupByReceivePubkey(String to) async {
    return await DBProvider.database.rooms
        .filter()
        .typeEqualTo(RoomType.group)
        .mykey((q) => q.pubkeyEqualTo(to))
        .findFirst();
  }

  Future<Room?> getRoomByOnetimeKey(String to) async {
    return await DBProvider.database.rooms
        .filter()
        .onetimekeyEqualTo(to)
        .findFirst();
  }

  Future<Room?> getRoomById(int id) async {
    Isar database = DBProvider.database;

    return await database.rooms.filter().idEqualTo(id).findFirst();
  }

  Future<List<Room>> getRoomBySignalIdPubkey(String pubkey) async {
    Isar database = DBProvider.database;
    return await database.rooms
        .filter()
        .signalIdPubkeyEqualTo(pubkey)
        .findAll();
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
    return DBProvider.database.rooms.filter().idEqualTo(id).findFirstSync();
  }

  Future<Map<String, List<Room>>> getRoomList(int indetityId) async {
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
      room.unReadCount =
          await MessageService.instance.unreadCountByRoom(room.id);
      var lastMessageModel =
          await MessageService.instance.getLastMessageByRoom(room.id);
      if (lastMessageModel != null) {
        if (lastMessageModel.content.length > 50) {
          lastMessageModel.content = lastMessageModel.content.substring(0, 50);
        }
        Utils.getGetxController<HomeController>()?.roomLastMessage[room.id] =
            lastMessageModel;
      }
      if (room.type != RoomType.common) {
        friendsRoom.add(room);
        continue;
      }
      if (room.type == RoomType.common) {
        room.contact = await contactService.getOrCreateContact(
            room.identityId, room.toMainPubkey,
            curve25519PkHex: room.curve25519PkHex);
      }
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

    return {
      'friends': RoomUtil.sortRoomList(friendsRoom),
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
      KeychatMessage km,
      NostrEventModel event, // as subEvent
      Relay relay,
      {NostrEventModel? sourceEvent, // parent event
      Room? room}) async {
    String toAddress = event.tags[0][1];
    // group room message
    room ??= await _getGroupRoom(toAddress);
    if (room == null) {}
    if (room == null) {
      Identity? identity;
      Mykey? mykey;
      List<Identity> identities = Utils.getGetxController<HomeController>()!
          .allIdentities
          .values
          .where((element) => element.secp256k1PKHex == toAddress)
          .toList();
      if (identities.isNotEmpty) {
        identity = identities[0];
      } else {
        // onetime-key is receive address
        mykey = await IdentityService.instance.getMykeyByPubkey(toAddress);
        if (mykey != null) {
          identity = Utils.getGetxController<HomeController>()
              ?.allIdentities[mykey.identityId];
        }
      }
      if (identity == null) throw Exception('My receive address is null');

      room = await getOrCreateRoomByIdentity(
          event.pubkey, identity, RoomStatus.init);
    }

    await km.service.proccessMessage(
        room: room, event: event, km: km, sourceEvent: sourceEvent);

    return;
  }

  @override
  Future proccessMessage(
      {required Room room,
      required NostrEventModel event,
      NostrEventModel? sourceEvent,
      String? msgKeyHash,
      String? fromIdPubkey,
      Function(String error)? failedCallback,
      required KeychatMessage km}) async {
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

  Future receiveDM(Room room, NostrEventModel event,
      {bool? isSystem,
      NostrEventModel? sourceEvent,
      KeychatMessage? km,
      String? realMessage,
      String? decodedContent,
      bool? isRead,
      String? senderPubkey,
      String? senderName,
      RequestConfrimEnum? requestConfrim,
      MessageMediaType? mediaType,
      String? msgKeyHash,
      MessageEncryptType? encryptType,
      String? requestId}) async {
    MsgReply? reply;
    if (km != null) {
      if (km.type == KeyChatEventKinds.dm && km.name != null) {
        try {
          reply = MsgReply.fromJson(jsonDecode(km.name!));
          decodedContent = km.msg!;
          // ignore: empty_catches
        } catch (e) {}
      }
    }
    senderPubkey ??= (room.type == RoomType.common || room.type == RoomType.bot)
        ? room.toMainPubkey
        : event.pubkey;
    await MessageService.instance.saveMessageToDB(
        events: [sourceEvent ?? event],
        room: room,
        from: sourceEvent?.pubkey ?? event.pubkey,
        to: sourceEvent?.tags[0][1] ?? event.tags[0][1],
        senderPubkey: senderPubkey,
        senderName: senderName,
        isSystem: isSystem,
        realMessage: realMessage,
        subEvent: sourceEvent != null ? event.toJson().toString() : null,
        content: decodedContent ?? km?.msg ?? event.content,
        encryptType: encryptType ?? RoomUtil.getEncryptMode(event, sourceEvent),
        reply: reply,
        sent: SendStatusType.success,
        isMeSend: senderPubkey == room.myIdPubkey,
        isRead: isRead,
        mediaType: mediaType,
        requestConfrim: requestConfrim,
        requestId: requestId,
        createdAt: event.createdAt,
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
      ..hash = fileInfo.hash
      ..updateAt = DateTime.now()
      ..ecashToken = fileInfo.ecashToken
      ..sourceName = fileInfo.sourceName
      ..status = FileStatus.decryptSuccess;
    return await RoomService.instance.sendMessage(
        room, mfi.getUriString(type.name, fileInfo),
        realMessage: mfi.toString(), mediaType: type);
  }

  Future forwardFileMessage(
      {required List<Room> rooms,
      required String content,
      required MsgFileInfo mfi,
      required MessageMediaType mediaType}) async {
    for (Room room in rooms) {
      await RoomService.instance.sendMessage(room, content,
          realMessage: mfi.toString(), mediaType: mediaType);
    }
  }

  @override
  Future<SendMessageResponse> sendMessage(Room room, String content,
      {MessageMediaType? mediaType,
      EncryptMode? encryptMode,
      MsgReply? reply,
      String? realMessage,
      String? toAddress,
      bool save = true,
      bool? isSystem}) async {
    String? realMessageContent = realMessage;
    if (realMessage == null && reply != null) {
      realMessageContent = content;
    }
    await checkWebsocketConnect();

    if (room.type == RoomType.group) {
      room = await getRoomByIdOrFail(room.id);
      return await _sendTextMessageToGroup(room, content,
          reply: reply, realMessage: realMessageContent, mediaType: mediaType);
    }
    if (room.type == RoomType.bot && !content.startsWith('cashu')) {
      return await sendMessageToBot(room, room.getIdentity(), content,
          realMessage: realMessage);
    }

    SendMessageResponse map;
    encryptMode ??= room.encryptMode;
    if (encryptMode == EncryptMode.nip04) {
      Identity identity = room.getIdentity();

      String sm =
          KeychatMessage.getTextMessage(MessageType.nip04, content, reply);
      map = await NostrAPI.instance.sendNip17Message(room, sm, identity,
          toPubkey: toAddress ?? room.toMainPubkey,
          save: save,
          realMessage: realMessageContent,
          reply: reply,
          mediaType: mediaType);
    } else {
      String sm = realMessage == null
          ? KeychatMessage.getTextMessage(MessageType.signal, content, reply)
          : content;
      map = await SignalChatService.instance.sendMessage(room, sm,
          realMessage: realMessageContent,
          reply: reply,
          isSystem: isSystem,
          mediaType: mediaType,
          save: save);
    }
    return map;
  }

  Future<SendMessageResponse> sendMessageToBot(
      Room room, Identity identity, String message,
      {String? realMessage}) async {
    BotClientMessageModel? cmm;
    try {
      cmm = BotClientMessageModel.fromJson(jsonDecode(message));
    } catch (e) {}
    if (cmm == null) {
      cmm ??= BotClientMessageModel(
          type: MessageMediaType.botText, message: message);
      BotMessageData? bmd = room.getBotMessagePriceModel();
      if (bmd != null && !message.startsWith('/')) {
        String? cashuTokenString;
        if (bmd.price > 0) {
          CashuInfoModel cashuToken = await CashuUtil.getStamp(
              amount: bmd.price, token: bmd.unit, mints: bmd.mints);
          cashuTokenString = cashuToken.token;
          var ecashBill = EcashBill(
              amount: cashuToken.amount,
              unit: cashuToken.unit ?? 'sat',
              token: cashuTokenString,
              roomId: room.id,
              createdAt: DateTime.now());
          await DBProvider.database.writeTxn(() async {
            await DBProvider.database.ecashBills.put(ecashBill);
          });
        }
        cmm = cmm.copyWith(priceModel: bmd.name, payToken: cashuTokenString);
      }
    }
    if (realMessage == null && message.startsWith('/')) {
      realMessage = message;
    }

    String toSendMessage = jsonEncode(cmm.toJson());
    logger.i('toSendMessage: $toSendMessage');
    if (room.encryptMode == EncryptMode.signal) {
      try {
        return await SignalChatService.instance.sendMessage(room, toSendMessage,
            realMessage: realMessage ?? message);
      } catch (e) {
        logger.e('send signal message to bot error', error: e);
      }
    }
    return await NostrAPI.instance.sendNip17Message(
      room,
      toSendMessage,
      identity,
      realMessage: realMessage ?? message,
    );
  }

  Future sendMessageToMultiRooms(
      {required String message,
      required String realMessage,
      required List<Room> rooms,
      required Identity identity,
      bool save = true,
      MessageMediaType? mediaType}) async {
    final queue = Queue(parallel: 5);
    var todo = collection.Queue.from(rooms);
    int membersLength = todo.length;
    for (int i = 0; i < membersLength; i++) {
      queue.add(() async {
        if (todo.isEmpty) return;
        Room room = todo.removeFirst();
        if (room.toMainPubkey == identity.secp256k1PKHex) return;
        await RoomService.instance.sendMessage(room, message,
            realMessage: realMessage, save: save, mediaType: mediaType);
      });
    }
    await queue.onComplete;
  }

  Future<ChatController?> updateChatRoomPage(Room room) async {
    ChatController? cc = RoomService.getController(room.id);
    if (cc == null) return null;

    if (room.type == RoomType.common) {
      room.contact ??=
          await contactService.getContact(room.identityId, room.toMainPubkey);
    }
    cc.setRoom(room);
    return null;
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

  Future<void> updateRoomAndRefresh(Room room) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.rooms.put(room);
    });
    updateChatRoomPage(room);
  }

  Future checkWebsocketConnect() async {
    bool netStatus =
        Utils.getGetxController<HomeController>()!.isConnectedNetwork.value;
    if (!netStatus) {
      throw Exception('Lost Network');
    }
    List online = Get.find<WebsocketService>().getOnlineSocketString();
    if (online.isEmpty) {
      throw Exception('Not connected with relay server, please retry');
    }
  }

  Future<Room?> getRoomByReceiveKey(String address) async {
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
    switch (room.groupType) {
      case GroupType.mls:
        return await MlsGroupService.instance.sendMessage(room, message,
            reply: reply, realMessage: realMessage, mediaType: mediaType);
      case GroupType.sendAll:
        return await groupService.sendToAllMessage(room, message,
            reply: reply, realMessage: realMessage, mediaType: mediaType);
      case GroupType.shareKey:
      case GroupType.kdf:
        throw Exception('not support');
    }
  }

  static ChatController? getController(int roomId) {
    ChatController? cc;
    try {
      cc = Get.find<ChatController>(tag: roomId.toString());
      // ignore: empty_catches
    } catch (e) {}
    return cc;
  }

  Future<Room?> createRoomAndsendInvite(String input,
      {bool autoJump = true, Identity? identity, String? greeting}) async {
    HomeController? hc = Utils.getGetxController<HomeController>();
    if (hc == null) {
      throw Exception('home controller is null');
    }
    identity ??= hc.getSelectedIdentity();
    // input is a hex string, decode in json
    if (!(input.length == 64 || input.length == 63)) return null;
    String hexPubkey = input;
    if (input.startsWith('npub') && input.length == 63) {
      hexPubkey = rust_nostr.getHexPubkeyByBech32(bech32: input);
    }

    try {
      late Room room;
      // add myself
      if (identity.secp256k1PKHex == hexPubkey) {
        room = await RoomService.instance
            .getOrCreateRoomByIdentity(hexPubkey, identity, RoomStatus.enabled);
      } else {
        for (var iden in hc.allIdentities.values) {
          if (iden.secp256k1PKHex == hexPubkey) {
            throw Exception('Can not add other identity\' pubkey');
          }
        }
        room = await RoomService.instance.getOrCreateRoomByIdentity(
            hexPubkey, identity, RoomStatus.requesting);
        await SignalChatService.instance
            .sendHelloMessage(room, identity, greeting: greeting);
        if (room.status != RoomStatus.requesting) {
          room.status = RoomStatus.requesting;
          await RoomService.instance.updateRoom(room);
        }
        EasyLoading.showSuccess('Request sent successfully');
      }

      if (autoJump) {
        await Utils.offAndToNamedRoom(room);
        Utils.getGetxController<HomeController>()
            ?.loadIdentityRoomList(identity.id);
      }
      return room;
    } catch (e, s) {
      logger.e('add contact failed', error: e, stackTrace: s);
      EasyLoading.showError(e.toString());
    }
    return null;
  }

  Future markAllRead({required int identityId, required int roomId}) async {
    var refresh = await MessageService.instance.setViewedMessage(roomId);
    if (refresh) {
      Utils.getGetxController<HomeController>()
          ?.loadIdentityRoomList(identityId);
    }
  }

  Future markAllReadSimple(Room room) async {
    Room? homeRoom =
        Get.find<HomeController>().getRoomByIdentity(room.identityId, room.id);
    if (homeRoom == null) return;
    if (homeRoom.unReadCount == 0) return;
    await markAllRead(identityId: room.identityId, roomId: room.id);
  }

  Future mute(Room room, bool value) async {
    EasyThrottle.throttle(
        'mute_notification:${room.id}', const Duration(seconds: 1), () async {
      List<String> pubkeys = [];

      if (room.type == RoomType.group) {
        if (room.isMLSGroup && room.onetimekey != null) {
          pubkeys.add(room.onetimekey!);
        } else if (room.mykey.value?.pubkey != null) {
          pubkeys.add(room.mykey.value!.pubkey);
        }
      } else {
        List<String>? data = ContactService.instance.getMyReceiveKeys(room);
        if (data != null) pubkeys.addAll(data);
      }
      bool res = false;
      if (value) {
        res = await NotifyService.removePubkeys(pubkeys);
      } else {
        res = await NotifyService.addPubkeys(pubkeys);
      }
      if (!res) {
        EasyLoading.showError('Failed, Please try again');
        return;
      }
      if (room.type == RoomType.common) {
        await ContactService.instance.updateReceiveKeyIsMute(room, value);
      }
      room.isMute = value;
      await RoomService.instance.updateRoomAndRefresh(room);
      EasyLoading.showSuccess('Saved');
      await Get.find<HomeController>().loadIdentityRoomList(room.identityId);
    });
  }

  // mls group , signal private chat room
  Future<Room?> getRoomByMyReceiveKey(String pubkey) async {
    Room? room = await SignalChatService.instance.getSignalChatRoomByTo(pubkey);
    if (room != null) {
      return room;
    }
    Room? mlsRoom = await RoomService.instance.getRoomByOnetimeKey(pubkey);
    return mlsRoom;
  }

  Future<List<Room>> getCommonRoomByPubkey(String hexPubkey) async {
    return await DBProvider.database.rooms
        .filter()
        .toMainPubkeyEqualTo(hexPubkey)
        .typeEqualTo(RoomType.common)
        .findAll();
  }
}

class SendMessageResponse {
  List<NostrEventModel> events = [];
  Message? message;
  List<String>? toAddPubkeys;
  String? msgKeyHash;
  SendMessageResponse({required this.events, this.message, this.msgKeyHash});
}
