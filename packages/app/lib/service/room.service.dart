import 'dart:collection' as collection;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:keychat/bot/bot_client_message_model.dart';
import 'package:keychat/constants.dart';
import 'package:keychat/controller/chat.controller.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/nostr-core/nostr.dart';
import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat/page/chat/RoomUtil.dart';
import 'package:keychat/service/chat.service.dart';
import 'package:keychat/service/chatx.service.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/service/group.service.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/message.service.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/signalId.service.dart';
import 'package:keychat/service/signal_chat.service.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_ecash/utils.dart';
import 'package:keychat_rust_ffi_plugin/api_mls.dart' as rust_mls;
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:queue/queue.dart';

class RoomService extends BaseChatService {
  // Avoid self instance
  RoomService._();
  static RoomService? _instance;
  static RoomService get instance => _instance ??= RoomService._();
  static final DBProvider dbProvider = DBProvider.instance;
  static final GroupService groupService = GroupService.instance;
  static final ContactService contactService = ContactService.instance;

  Future<void> checkRoomStatus(Room room) async {
    if (room.status == RoomStatus.dissolved) {
      throw Exception('Room had been dissolved');
    }

    if (room.status == RoomStatus.removedFromGroup) {
      throw Exception('You have been removed by admin.');
    }
  }

  Future<Room> createPrivateRoom({
    required String toMainPubkey,
    required Identity identity,
    required RoomStatus status,
    required EncryptMode encryptMode,
    String? name,
    Contact? contact,
    String? curve25519PkHex,
    String? onetimekey,
    SignalId? signalId,
    RoomType? type,
  }) async {
    final identityId = identity.id;
    final exist = await getRoomByIdentity(toMainPubkey, identityId);
    if (exist != null) return exist;
    signalId ??= await SignalIdService.instance.createSignalId(identityId);

    var room =
        Room(
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
          ..signalIdPubkey = signalId.pubkey;
    // set bot room's name
    if (room.type == RoomType.bot) {
      room.name = name;
    }
    if (toMainPubkey == identity.secp256k1PKHex) {
      room.encryptMode = EncryptMode.nip04;
      name = KeychatGlobal.selfName;
    }

    room = await updateRoom(room)
      ..contact = contact;

    Utils.getGetxController<HomeController>()?.loadIdentityRoomList(
      room.identityId,
    );
    return room;
  }

  Future<void> deleteRoomHandler(String pubkey, int identityId) async {
    Room? room;
    await ContactService.instance.deleteContactByPubkey(pubkey, identityId);
    room = await RoomService.instance.getRoomByIdentity(pubkey, identityId);
    if (room != null) {
      await RoomService.instance.deleteRoom(room);
      Get.find<HomeController>().loadIdentityRoomList(identityId);
    }
  }

  Future<void> deleteRoom(Room room, {bool websocketInited = true}) async {
    final database = DBProvider.database;
    final roomMykeyId = room.mykey.value?.id;
    final listenPubkey = room.mykey.value?.pubkey;
    final groupType = room.groupType;
    final roomType = room.type;
    final roomId = room.id;
    final toMainPubkey = room.toMainPubkey;
    final mlsListenPubkey = room.onetimekey;
    // delete room's signalId
    final signalIdPubkey = room.signalIdPubkey;
    var sameSignalIdrooms = <Room>[];
    if (signalIdPubkey != null) {
      sameSignalIdrooms = await RoomService.instance.getRoomBySignalIdPubkey(
        signalIdPubkey,
      );
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
        NotifyService.instance.removePubkeys([listenPubkey]);
        if (websocketInited) {
          Get.find<WebsocketService>().removePubkeyFromSubscription(
            listenPubkey,
          );
        }
      }
    }
    if (roomType == RoomType.group && groupType == GroupType.mls) {
      if (mlsListenPubkey != null) {
        if (websocketInited) {
          Get.find<WebsocketService>().removePubkeyFromSubscription(
            mlsListenPubkey,
          );
        }
        NotifyService.instance.removePubkeys([mlsListenPubkey]);
      }
      final identity = await IdentityService.instance.getIdentityById(
        room.identityId,
      );
      final myIdPubkey = identity?.secp256k1PKHex;
      if (myIdPubkey != null) {
        try {
          await rust_mls.deleteGroup(
            nostrId: myIdPubkey,
            groupId: toMainPubkey,
          );
        } catch (e) {
          logger.i('delete mls group error', error: e);
        }
      }
    }
  }

  Future<void> deleteRoomMessage(Room room) async {
    await FileService.instance.deleteFolderByRoomId(room.identityId, room.id);

    await DBProvider.database.writeTxn(() async {
      return DBProvider.database.messages
          .filter()
          .roomIdEqualTo(room.id)
          .deleteAll();
    });
  }

  Future<List<Room>> getGroupsSharedKey() async {
    return DBProvider.database.rooms
        .filter()
        .typeEqualTo(RoomType.group)
        .group(
          (q) => q
              .groupTypeEqualTo(GroupType.shareKey)
              .or()
              .groupTypeEqualTo(GroupType.kdf),
        )
        .findAll();
  }

  Future<List<Room>> getMlsRooms() async {
    return DBProvider.database.rooms
        .filter()
        .groupTypeEqualTo(GroupType.mls)
        .typeEqualTo(RoomType.group)
        .onetimekeyIsNotEmpty()
        .findAll();
  }

  Future<List<Room>> getMlsRoomsSkipMute() async {
    return DBProvider.database.rooms
        .filter()
        .groupTypeEqualTo(GroupType.mls)
        .isMuteEqualTo(false)
        .onetimekeyIsNotEmpty()
        .findAll();
  }

  // get room by send_pubkey and bob_pubkey
  Future<Room> getOrCreateRoom(
    String from,
    String to,
    RoomStatus initStatus, {
    String? contactName,
    Identity? identity,
    RoomType? type,
  }) async {
    final room = await getRoom(from, to, identity);
    if (room != null && room.type == RoomType.common && contactName != null) {
      await ContactService.instance.updateOrCreateByRoom(room, contactName);
      return room;
    }

    identity ??= await IdentityService.instance.getIdentityByNostrPubkey(to);
    if (identity == null) {
      throw Exception('no this identity');
    }
    return createPrivateRoom(
      toMainPubkey: from,
      identity: identity,
      status: initStatus,
      encryptMode: EncryptMode.nip04,
      type: type,
      name: contactName,
    );
  }

  Future<Room> getOrCreateRoomByIdentity(
    String toMainPubkey,
    Identity identity,
    RoomStatus status,
  ) async {
    final room = await getRoomByIdentity(toMainPubkey, identity.id);
    if (room != null) return room;

    return createPrivateRoom(
      encryptMode: EncryptMode.nip04,
      toMainPubkey: toMainPubkey,
      identity: identity,
      status: status,
    );
  }

  Future<Room?> getRoom(String from, String to, [Identity? identity]) async {
    final database = DBProvider.database;

    final signalRatchetRoom = await getRoomByReceiveKey(to);
    if (signalRatchetRoom != null) return signalRatchetRoom;

    // common chat. from is room mainkey, to is my identity'pubkey
    final nip4Rooms = await database.rooms
        .filter()
        .toMainPubkeyEqualTo(from)
        .findAll();

    for (final room in nip4Rooms) {
      identity ??= await IdentityService.instance.getIdentityById(
        room.identityId,
      );
      if (identity != null && identity.secp256k1PKHex == to) {
        return room;
      }
    }

    // group share key
    if (from == to) {
      return _getGroupRoom(to);
    }
    return null;
  }

  Future<Room?> _getGroupRoom(String to) async {
    return DBProvider.database.rooms
        .filter()
        .typeEqualTo(RoomType.group)
        .mykey((q) => q.pubkeyEqualTo(to))
        .findFirst();
  }

  Future<Room?> getGroupByReceivePubkey(String to) async {
    return DBProvider.database.rooms
        .filter()
        .typeEqualTo(RoomType.group)
        .mykey((q) => q.pubkeyEqualTo(to))
        .findFirst();
  }

  Future<Room?> getRoomByOnetimeKey(String to) async {
    return DBProvider.database.rooms.filter().onetimekeyEqualTo(to).findFirst();
  }

  Future<Room?> getRoomById(int id) async {
    final database = DBProvider.database;

    return database.rooms.filter().idEqualTo(id).findFirst();
  }

  Future<List<Room>> getRoomBySignalIdPubkey(String pubkey) async {
    final database = DBProvider.database;
    return database.rooms.filter().signalIdPubkeyEqualTo(pubkey).findAll();
  }

  Future<Room?> getRoomByIdentity(String from, int identityId) async {
    final database = DBProvider.database;

    return database.rooms
        .filter()
        .toMainPubkeyEqualTo(from)
        .identityIdEqualTo(identityId)
        .findFirst();
  }

  Future<Room?> getRoomAndContainSession(String from, int identityId) async {
    final room = await DBProvider.database.rooms
        .filter()
        .toMainPubkeyEqualTo(from)
        .identityIdEqualTo(identityId)
        .findFirst();
    if (room == null) return null;
    if (room.curve25519PkHex != null) {
      final res = await Get.find<ChatxService>().getRoomKPA(room);
      return res == null ? null : room;
    }
    return null;
  }

  Future<Room> getRoomByIdOrFail(int id) async {
    final exist = await getRoomById(id);
    if (exist == null) throw Exception('room is null');
    return exist;
  }

  Room? getRoomByIdSync(int id) {
    return DBProvider.database.rooms.filter().idEqualTo(id).findFirstSync();
  }

  Future<Map<String, List<Room>>> getRoomList(int indetityId) async {
    final database = DBProvider.database;

    final list = await database.rooms
        .filter()
        .identityIdEqualTo(indetityId)
        .not()
        .statusEqualTo(RoomStatus.groupUser) // not include init
        .sortByCreatedAtDesc()
        .findAll();
    final friendsRoom = <Room>[];
    final approving = <Room>[];
    final requesting = <Room>[];
    for (final room in list) {
      room.unReadCount = await MessageService.instance.unreadCountByRoom(
        room.id,
      );
      final lastMessageModel = await MessageService.instance
          .getLastMessageByRoom(room.id);
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
          identityId: room.identityId,
          pubkey: room.toMainPubkey,
          curve25519PkHex: room.curve25519PkHex,
        );
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
      'requesting': requesting,
    };
  }

  Future<Room> getRoomOrFail(String from, String to) async {
    final room = await getRoom(from, to);
    if (room == null) throw Exception('room is null');
    return room;
  }

  Future<void> processKeychatMessage(
    KeychatMessage km,
    NostrEventModel event, // as subEvent
    Relay relay, {
    NostrEventModel? sourceEvent, // parent event
    Room? room,
  }) async {
    final toAddress = event.tags[0][1];
    // group room message
    room ??= await _getGroupRoom(toAddress);
    if (room == null) {}
    if (room == null) {
      Identity? identity;
      Mykey? mykey;
      final identities = Utils.getGetxController<HomeController>()!
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
        event.pubkey,
        identity,
        RoomStatus.init,
      );
    }

    await km.service.proccessMessage(
      room: room,
      event: event,
      km: km,
      sourceEvent: sourceEvent,
    );

    return;
  }

  @override
  Future<void> proccessMessage({
    required Room room,
    required NostrEventModel event,
    required KeychatMessage km,
    NostrEventModel? sourceEvent,
    String? msgKeyHash,
    String? fromIdPubkey,
    Function(String error)? failedCallback,
  }) async {
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

  Future<void> receiveDM(
    Room room,
    NostrEventModel event, {
    bool? isSystem,
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
    String? requestId,
  }) async {
    var content = decodedContent ?? km?.msg ?? event.content;
    senderPubkey ??= (room.type == RoomType.common || room.type == RoomType.bot)
        ? room.toMainPubkey
        : event.pubkey;
    final isMeSend = senderPubkey == room.myIdPubkey;

    MsgReply? reply;
    if (km != null) {
      if (km.type == KeyChatEventKinds.dm && km.name != null) {
        try {
          reply = MsgReply.fromJson(jsonDecode(km.name!));
          if (km.msg != null) {
            content = km.msg!;
          }
        } catch (e) {}
      }
      if (!isMeSend) {
        if (km.type == KeyChatEventKinds.signalSendProfile) {
          mediaType = MessageMediaType.profileRequest;
          content = km.toString();
        }
      }
    }

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
      content: content,
      encryptType: encryptType ?? RoomUtil.getEncryptMode(event, sourceEvent),
      reply: reply,
      sent: SendStatusType.success,
      isMeSend: isMeSend,
      isRead: isRead,
      mediaType: mediaType,
      requestConfrim: requestConfrim,
      requestId: requestId,
      createdAt: event.createdAt,
      msgKeyHash: msgKeyHash,
    );
  }

  @override
  Future<SendMessageResponse> sendMessage(
    Room room,
    String content, {
    MessageMediaType? mediaType,
    EncryptMode? encryptMode,
    MsgReply? reply,
    String? realMessage,
    String? toAddress,
    bool save = true,
    bool? isSystem,
  }) async {
    var realMessageContent = realMessage;
    if (realMessage == null && reply != null) {
      realMessageContent = content;
    }
    await checkWebsocketConnect();

    if (room.type == RoomType.group) {
      room = await getRoomByIdOrFail(room.id);
      return _sendTextMessageToGroup(
        room,
        content,
        reply: reply,
        realMessage: realMessageContent,
        mediaType: mediaType,
      );
    }
    if (room.type == RoomType.bot && !content.startsWith('cashu')) {
      return sendMessageToBot(
        room,
        room.getIdentity(),
        content,
        realMessage: realMessage,
      );
    }

    SendMessageResponse map;
    encryptMode ??= room.encryptMode;
    if (encryptMode == EncryptMode.nip04) {
      final identity = room.getIdentity();

      final sm = KeychatMessage.getTextMessage(
        MessageType.nip04,
        content,
        reply,
      );
      map = await NostrAPI.instance.sendNip17Message(
        room,
        sm,
        identity,
        toPubkey: toAddress ?? room.toMainPubkey,
        save: save,
        realMessage: realMessageContent,
        reply: reply,
        mediaType: mediaType,
      );
    } else {
      final sm = realMessage == null
          ? KeychatMessage.getTextMessage(MessageType.signal, content, reply)
          : content;
      map = await SignalChatService.instance.sendMessage(
        room,
        sm,
        realMessage: realMessageContent,
        reply: reply,
        isSystem: isSystem,
        mediaType: mediaType,
        save: save,
      );
    }
    return map;
  }

  Future<SendMessageResponse> sendMessageToBot(
    Room room,
    Identity identity,
    String message, {
    String? realMessage,
  }) async {
    BotClientMessageModel? cmm;
    try {
      cmm = BotClientMessageModel.fromJson(jsonDecode(message));
      // ignore: empty_catches
    } catch (e) {}
    if (cmm == null) {
      cmm ??= BotClientMessageModel(
        type: MessageMediaType.botText,
        message: message,
      );
      final bmd = room.getBotMessagePriceModel();
      if (bmd != null && !message.startsWith('/')) {
        String? cashuTokenString;
        if (bmd.price > 0) {
          final cashuToken = await EcashUtils.getStamp(
            amount: bmd.price,
            token: bmd.unit,
            mints: bmd.mints ?? [],
          );
          cashuTokenString = cashuToken.token;
          final ecashBill = EcashBill(
            amount: cashuToken.amount,
            unit: cashuToken.unit ?? 'sat',
            token: cashuTokenString,
            roomId: room.id,
            createdAt: DateTime.now(),
          );
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

    final toSendMessage = jsonEncode(cmm.toJson());
    logger.i('sendMessageToBot: $toSendMessage');
    if (room.encryptMode == EncryptMode.signal) {
      try {
        return await SignalChatService.instance.sendMessage(
          room,
          toSendMessage,
          realMessage: realMessage ?? message,
        );
      } catch (e) {
        logger.e('send signal message to bot error', error: e);
      }
    }
    return NostrAPI.instance.sendNip17Message(
      room,
      toSendMessage,
      identity,
      realMessage: realMessage ?? message,
    );
  }

  Future<void> sendMessageToMultiRooms({
    required String message,
    required String realMessage,
    required List<Room> rooms,
    required Identity identity,
    bool save = true,
    MessageMediaType? mediaType,
  }) async {
    final queue = Queue(parallel: 5);
    final todo = collection.Queue.from(rooms);
    final membersLength = todo.length;
    for (var i = 0; i < membersLength; i++) {
      queue.add(() async {
        if (todo.isEmpty) return;
        final room = todo.removeFirst() as Room;
        if (room.toMainPubkey == identity.secp256k1PKHex) return;
        await RoomService.instance.sendMessage(
          room,
          message,
          realMessage: realMessage,
          save: save,
          mediaType: mediaType,
        );
      });
    }
    await queue.onComplete;
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

  Future<void> updateRoomAndRefresh(
    Room room, {
    bool refreshContact = false,
  }) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.rooms.put(room);
    });
    await refreshRoom(room, refreshContact: refreshContact);
  }

  Future<void> checkWebsocketConnect() async {
    final netStatus =
        Utils.getGetxController<HomeController>()!.isConnectedNetwork.value;
    if (!netStatus) {
      throw Exception('Lost Network');
    }
    final List online = Get.find<WebsocketService>().getOnlineSocketString();
    if (online.isEmpty) {
      throw Exception('Not connected with relay server, please retry');
    }
  }

  Future<Room?> getRoomByReceiveKey(String address) async {
    final crk = await DBProvider.database.contactReceiveKeys
        .filter()
        .receiveKeysElementContains(address)
        .findFirst();
    if (crk == null) return null;
    final room = await DBProvider.database.rooms
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
        return MlsGroupService.instance.sendMessage(
          room,
          message,
          reply: reply,
          realMessage: realMessage,
          mediaType: mediaType,
        );
      case GroupType.sendAll:
        return groupService.sendToAllMessage(
          room,
          message,
          reply: reply,
          realMessage: realMessage,
          mediaType: mediaType,
        );
      case GroupType.shareKey:
      case GroupType.kdf:
        throw Exception('not support');
      case GroupType.common:
        // TODO: Handle this case.
        throw UnimplementedError();
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

  Future<Room?> createRoomAndsendInvite(
    String input, {
    bool autoJump = true,
    Identity? identity,
    String? greeting,
  }) async {
    final hc = Utils.getGetxController<HomeController>();
    if (hc == null) {
      throw Exception('home controller is null');
    }
    identity ??= hc.getSelectedIdentity();
    // input is a hex string, decode in json
    if (!(input.length == 64 || input.length == 63)) return null;
    var hexPubkey = input;
    if (input.startsWith('npub') && input.length == 63) {
      hexPubkey = rust_nostr.getHexPubkeyByBech32(bech32: input);
    }

    try {
      late Room room;
      // add myself
      if (identity.secp256k1PKHex == hexPubkey) {
        room = await RoomService.instance.getOrCreateRoomByIdentity(
          hexPubkey,
          identity,
          RoomStatus.enabled,
        );
      } else {
        for (final iden in hc.allIdentities.values) {
          if (iden.secp256k1PKHex == hexPubkey) {
            throw Exception("Can not add other identity' pubkey");
          }
        }
        room = await RoomService.instance.getOrCreateRoomByIdentity(
          hexPubkey,
          identity,
          RoomStatus.requesting,
        );
        await SignalChatService.instance.sendHelloMessage(
          room,
          identity,
          greeting: greeting,
          fromNpub: true,
        );
        await ContactService.instance.addContactToFriend(
          pubkey: room.toMainPubkey,
          identityId: room.identityId,
        );
        if (room.status != RoomStatus.requesting) {
          room.status = RoomStatus.requesting;
          await RoomService.instance.updateRoom(room);
        }
        EasyLoading.showSuccess('Request sent successfully');
      }

      if (autoJump) {
        await Utils.offAndToNamedRoom(room);
        Utils.getGetxController<HomeController>()?.loadIdentityRoomList(
          identity.id,
        );
      }
      return room;
    } catch (e, s) {
      logger.e('add contact failed', error: e, stackTrace: s);
      EasyLoading.showError(e.toString());
    }
    return null;
  }

  Future<bool> markAllRead(Room room) async {
    final refresh = await MessageService.instance.setViewedMessage(room.id);
    if (refresh) {
      Utils.getGetxController<HomeController>()?.loadIdentityRoomList(
        room.identityId,
      );
      return true;
    }
    return false;
  }

  Future<void> markAllReadSimple(Room room) async {
    final homeRoom = Get.find<HomeController>().getRoomByIdentity(
      room.identityId,
      room.id,
    );
    if (homeRoom == null) return;
    if (homeRoom.unReadCount == 0) return;
    await markAllRead(room);
  }

  Future<void> mute(Room room, bool value) async {
    EasyThrottle.throttle(
      'mute_notification:${room.id}',
      const Duration(seconds: 1),
      () async {
        final pubkeys = <String>[];

        if (room.type == RoomType.group) {
          if (room.isMLSGroup && room.onetimekey != null) {
            pubkeys.add(room.onetimekey!);
          } else if (room.mykey.value?.pubkey != null) {
            pubkeys.add(room.mykey.value!.pubkey);
          }
        } else {
          final data = ContactService.instance.getMyReceiveKeys(room);
          if (data != null) pubkeys.addAll(data);
        }
        var res = false;
        if (value) {
          res = await NotifyService.instance.removePubkeys(pubkeys);
        } else {
          res = await NotifyService.instance.addPubkeys(pubkeys);
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
        Get.find<HomeController>().loadIdentityRoomList(room.identityId);
      },
    );
  }

  // mls group , signal private chat room
  Future<Room?> getRoomByMyReceiveKey(String pubkey) async {
    final room = await SignalChatService.instance.getSignalChatRoomByTo(pubkey);
    if (room != null) {
      return room;
    }
    final mlsRoom = await RoomService.instance.getRoomByOnetimeKey(pubkey);
    return mlsRoom;
  }

  Future<List<Room>> getCommonRoomByPubkey(String hexPubkey) async {
    return DBProvider.database.rooms
        .filter()
        .toMainPubkeyEqualTo(hexPubkey)
        .typeEqualTo(RoomType.common)
        .findAll();
  }

  Future<void> refreshRoom(Room room, {bool refreshContact = false}) async {
    final cc = RoomService.getController(room.id);
    if (cc == null) return;

    if (room.type == RoomType.common) {
      if (room.contact == null || refreshContact) {
        room.contact = await contactService.getContact(
          room.identityId,
          room.toMainPubkey,
        );
      }
    }
    cc.setRoom(room);
  }
}

class SendMessageResponse {
  SendMessageResponse({required this.events, this.message, this.msgKeyHash});
  List<NostrEventModel> events = [];
  Message? message;
  List<String>? toAddPubkeys;
  String? msgKeyHash;
}
