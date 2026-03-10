import 'dart:collection' as collection;
import 'dart:convert' show jsonDecode, jsonEncode;
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
import 'package:keychat/service/nip4_chat.service.dart';
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

/// Central service that coordinates rooms, message routing, and send logic.
///
/// Acts as a dispatcher: routes outgoing messages to the correct protocol
/// service (Signal, MLS, NIP-04, NIP-17) based on room settings, and routes
/// incoming events to the correct room via [processKeychatMessage].
class RoomService extends BaseChatService {
  // Avoid self instance
  RoomService._();
  static RoomService? _instance;
  static RoomService get instance => _instance ??= RoomService._();
  static final DBProvider dbProvider = DBProvider.instance;
  static final GroupService groupService = GroupService.instance;
  static final ContactService contactService = ContactService.instance;

  /// Throws if [room] is in a terminal state (dissolved or removed from group).
  Future<void> checkRoomStatus(Room room) async {
    if (room.status == RoomStatus.dissolved) {
      throw Exception('Room had been dissolved');
    }

    if (room.status == RoomStatus.removedFromGroup) {
      throw Exception('You have been removed by admin.');
    }
  }

  /// Creates a new private (1:1) room for [identity] ↔ [toMainPubkey].
  ///
  /// Returns the existing room if one already exists.  Allocates a new [SignalId]
  /// if [signalId] is not provided.  Sets the default encrypt mode to NIP-17.
  Future<Room> createPrivateRoom({
    required String toMainPubkey,
    required Identity identity,
    required RoomStatus status,
    EncryptMode? encryptMode,
    String? name,
    Contact? contact,
    String? peerSignalIdentityKey,
    String? receiveAddress,
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
          ..receiveAddress = receiveAddress
          ..status = status
          ..type = type ?? RoomType.common
          ..encryptMode = encryptMode ?? EncryptMode.nip17
          ..peerSignalIdentityKey = peerSignalIdentityKey
          ..mySignalIdentityKey = signalId.pubkey;
    // set bot room's name
    if (room.type == RoomType.bot) {
      room.name = name;
    }
    // chat with myself
    if (toMainPubkey == identity.nostrIdentityKey) {
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

  /// Permanently deletes [room] and all associated data.
  ///
  /// Cascades to: messages, room members, event status records, Signal sessions,
  /// MLS group state, shared SignalIds, receive keys, and file attachments.
  /// Also unsubscribes the room's listen pubkeys from the relay and notification server.
  /// [websocketInited] controls whether WebSocket unsubscription is attempted.
  Future<void> deleteRoom(Room room, {bool websocketInited = true}) async {
    final database = DBProvider.database;
    final identityId = room.identityId;
    final roomMykeyId = room.mykey.value?.id;
    final listenPubkey = room.mykey.value?.pubkey;
    final groupType = room.groupType;
    final roomType = room.type;
    final roomId = room.id;
    final toMainPubkey = room.toMainPubkey;
    final mlsListenPubkey = room.receiveAddress;
    // delete room's signalId
    final signalIdPubkey = room.mySignalIdentityKey;
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
      final myIdPubkey = identity?.nostrIdentityKey;
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
    Get.find<HomeController>().loadIdentityRoomList(identityId);
  }

  /// Deletes all messages and file attachments for [room] without deleting the room itself.
  Future<void> deleteRoomMessage(Room room) async {
    await FileService.instance.deleteFolderByRoomId(room.identityId, room.id);

    await DBProvider.database.writeTxn(() async {
      return DBProvider.database.messages
          .filter()
          .roomIdEqualTo(room.id)
          .deleteAll();
    });
  }

  /// Returns all MLS group rooms that have a receive address.
  Future<List<Room>> getMlsRooms() async {
    return DBProvider.database.rooms
        .filter()
        .groupTypeEqualTo(GroupType.mls)
        .typeEqualTo(RoomType.group)
        .onetimekeyIsNotEmpty()
        .findAll();
  }

  /// Returns non-muted MLS group rooms that have a receive address.
  Future<List<Room>> getMlsRoomsSkipMute() async {
    return DBProvider.database.rooms
        .filter()
        .groupTypeEqualTo(GroupType.mls)
        .isMuteEqualTo(false)
        .onetimekeyIsNotEmpty()
        .findAll();
  }

  /// Returns an existing room where [from] is the contact and [to] is the identity
  /// pubkey, creating one if it does not exist.
  ///
  /// [from] is the sender's main pubkey; [to] is the receiving identity's pubkey.
  Future<Room> getOrCreateRoom(
    String from,
    String to,
    RoomStatus initStatus, {
    String? contactName,
    Identity? identity,
    RoomType? type,
    EncryptMode? encryptMode,
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
      encryptMode: encryptMode,
      type: type,
      name: contactName,
    );
  }

  /// Returns the room for [toMainPubkey] under [identity], creating one if absent.
  Future<Room> getOrCreateRoomByIdentity(
    String toMainPubkey,
    Identity identity,
    RoomStatus status, {
    EncryptMode? encryptMode,
  }) async {
    final room = await getRoomByIdentity(toMainPubkey, identity.id);
    if (room != null) return room;

    return createPrivateRoom(
      encryptMode: encryptMode ?? EncryptMode.nip17,
      toMainPubkey: toMainPubkey,
      identity: identity,
      status: status,
    );
  }

  /// Resolves a room from an incoming event's `from` pubkey and receiving `to` pubkey.
  ///
  /// Checks Signal ratchet receive keys first, then common rooms, then group shared-key rooms.
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
      if (identity != null && identity.nostrIdentityKey == to) {
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

  Future<Room?> getRoomByReceiveAddress(String to) async {
    return DBProvider.database.rooms.filter().onetimekeyEqualTo(to).findFirst();
  }

  /// Returns the room with the given Isar [id], or null if not found.
  Future<Room?> getRoomById(int id) async {
    final database = DBProvider.database;

    return database.rooms.filter().idEqualTo(id).findFirst();
  }

  /// Returns all rooms that share the same [signalIdPubkey].
  ///
  /// Used to determine whether a SignalId can be safely deleted when a room
  /// is removed.
  Future<List<Room>> getRoomBySignalIdPubkey(String pubkey) async {
    final database = DBProvider.database;
    return database.rooms.filter().signalIdPubkeyEqualTo(pubkey).findAll();
  }

  /// Returns the room where [from] is the peer pubkey and [identityId] is the local identity.
  Future<Room?> getRoomByIdentity(String from, int identityId) async {
    final database = DBProvider.database;

    return database.rooms
        .filter()
        .toMainPubkeyEqualTo(from)
        .identityIdEqualTo(identityId)
        .findFirst();
  }

  /// Returns the room only if it exists AND has an active Signal session.
  ///
  /// Used to quickly check whether a session is ready before attempting decryption.
  Future<Room?> getRoomAndContainSession(String from, int identityId) async {
    final room = await DBProvider.database.rooms
        .filter()
        .toMainPubkeyEqualTo(from)
        .identityIdEqualTo(identityId)
        .findFirst();
    if (room == null) return null;
    if (room.peerSignalIdentityKey != null) {
      final res = await Get.find<ChatxService>().getRoomKPA(room);
      return res == null ? null : room;
    }
    return null;
  }

  /// Returns the room with [id], throwing if not found.
  Future<Room> getRoomByIdOrFail(int id) async {
    final exist = await getRoomById(id);
    if (exist == null) throw Exception('room is null');
    return exist;
  }

  /// Synchronously returns the room with [id], or null if not found.
  Room? getRoomByIdSync(int id) {
    return DBProvider.database.rooms.filter().idEqualTo(id).findFirstSync();
  }

  /// Returns a categorised room list for [indetityId].
  ///
  /// The result map has three keys:
  /// - `'friends'`: active chat rooms (enabled + groups)
  /// - `'approving'`: rooms awaiting the peer's acceptance
  /// - `'requesting'`: rooms where the peer is waiting for our acceptance
  ///
  /// Unread counts and last messages are batch-fetched in parallel for performance.
  Future<Map<String, List<Room>>> getRoomList(int indetityId) async {
    final database = DBProvider.database;

    final list = await database.rooms
        .filter()
        .identityIdEqualTo(indetityId)
        .not()
        .statusEqualTo(RoomStatus.groupUser) // not include init
        .sortByCreatedAtDesc()
        .findAll();

    // Batch fetch unread counts and last messages in parallel
    final roomIds = list.map((r) => r.id).toList();
    final results = await Future.wait([
      _batchUnreadCounts(roomIds),
      _batchLastMessages(roomIds),
    ]);
    final unreadCounts = results[0] as Map<int, int>;
    final lastMessages = results[1] as Map<int, Message?>;

    final hc = Utils.getGetxController<HomeController>();
    final friendsRoom = <Room>[];
    final approving = <Room>[];
    final requesting = <Room>[];
    for (final room in list) {
      room.unReadCount = unreadCounts[room.id] ?? 0;
      final lastMessageModel = lastMessages[room.id];
      if (lastMessageModel != null) {
        if (lastMessageModel.content.length > 50) {
          lastMessageModel.content = lastMessageModel.content.substring(0, 50);
        }
        hc?.roomLastMessage[room.id] = lastMessageModel;
      }
      if (room.type != RoomType.common) {
        friendsRoom.add(room);
        continue;
      }
      if (room.type == RoomType.common) {
        room.contact = await contactService.getOrCreateContact(
          identityId: room.identityId,
          pubkey: room.toMainPubkey,
          signalIdentityKey: room.peerSignalIdentityKey,
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

  /// Batch fetch unread counts for multiple rooms in parallel.
  Future<Map<int, int>> _batchUnreadCounts(List<int> roomIds) async {
    final futures = roomIds.map(
      (id) => MessageService.instance.unreadCountByRoom(id),
    );
    final counts = await Future.wait(futures);
    final map = <int, int>{};
    for (var i = 0; i < roomIds.length; i++) {
      map[roomIds[i]] = counts[i];
    }
    return map;
  }

  /// Batch fetch last messages for multiple rooms in parallel.
  Future<Map<int, Message?>> _batchLastMessages(List<int> roomIds) async {
    final futures = roomIds.map(
      (id) => MessageService.instance.getLastMessageByRoom(id),
    );
    final messages = await Future.wait(futures);
    final map = <int, Message?>{};
    for (var i = 0; i < roomIds.length; i++) {
      map[roomIds[i]] = messages[i];
    }
    return map;
  }

  /// Returns the room for [from] ↔ [to], throwing if not found.
  Future<Room> getRoomOrFail(String from, String to) async {
    final room = await getRoom(from, to);
    if (room == null) throw Exception('room is null');
    return room;
  }

  /// Routes a decrypted [KeychatMessage] to the correct room and protocol handler.
  ///
  /// [event] is the inner decrypted event; [sourceEvent] is the outer wrapper if any.
  /// Resolves or creates the room from the event's recipient address, then
  /// delegates to [km.service.processMessage].
  Future<void> processKeychatMessage(
    KeychatMessage km,
    NostrEventModel event, // as subEvent
    Relay relay, {
    Room? room,
    EncryptMode? encryptMode,
    NostrEventModel? sourceEvent, // parent event
  }) async {
    final toAddress = event.tags[0][1];
    // group room message
    room ??= await _getGroupRoom(toAddress);
    if (room == null) {
      Identity? identity;
      Mykey? mykey;
      final identities = Utils.getGetxController<HomeController>()!
          .allIdentities
          .values
          .where((element) => element.nostrIdentityKey == toAddress)
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
        encryptMode: encryptMode,
      );
    }

    await km.service.processMessage(
      room: room,
      event: event,
      km: km,
      sourceEvent: sourceEvent,
    );

    return;
  }

  // DEPRECATED: WebRTC call handling was removed; all cases are commented out.
  // This override is now a no-op and should be removed once the BaseChatService
  // contract no longer requires it — candidate for removal.
  @override
  Future<void> processMessage({
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

  /// Saves an incoming decrypted direct message to the database and notifies the UI.
  ///
  /// Handles reply parsing, profile-request media types, and sender resolution.
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
          reply = MsgReply.fromJson(
            jsonDecode(km.name!) as Map<String, dynamic>,
          );
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
    if (content.isEmpty &&
        (realMessageContent == null || realMessageContent.isEmpty)) {
      throw Exception('message content is empty');
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

    // signal chat
    if (room.encryptMode == EncryptMode.signal) {
      final sm = realMessage == null
          ? KeychatMessage.getTextMessage(MessageType.signal, content, reply)
          : content;
      return SignalChatService.instance.sendMessage(
        room,
        sm,
        realMessage: realMessageContent,
        reply: reply,
        isSystem: isSystem,
        mediaType: mediaType,
        save: save,
      );
    }

    // nip04 private chat
    final identity = room.getIdentity();

    final sm = KeychatMessage.getTextMessage(
      MessageType.nip04,
      content,
      reply,
    );
    if (room.encryptMode == EncryptMode.nip17) {
      return NostrAPI.instance.sendNip17Message(
        room,
        sm,
        identity,
        toPubkey: toAddress ?? room.toMainPubkey,
        save: save,
        realMessage: realMessageContent,
        reply: reply,
        mediaType: mediaType,
      );
    }
    if (room.encryptMode == EncryptMode.nip04) {
      return Nip4ChatService.instance.sendMessage(
        room,
        sm,
        save: save,
        realMessage: realMessageContent,
        reply: reply,
        mediaType: mediaType,
      );
    }
    throw Exception('not support encrypt mode');
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
    final tasks = collection.Queue.from(rooms);
    final membersLength = tasks.length;
    for (var i = 0; i < membersLength; i++) {
      queue.add(() async {
        if (tasks.isEmpty) return;
        final room = tasks.removeFirst() as Room;
        if (room.toMainPubkey == identity.nostrIdentityKey) return;
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

  /// Persists [room] to the database, optionally saving its linked [Mykey] as well.
  Future<Room> updateRoom(Room room, {bool updateMykey = false}) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.rooms.put(room);
      if (updateMykey) {
        await room.mykey.save();
      }
    });
    return room;
  }

  /// Persists [room] and pushes the updated model to any open [ChatController].
  Future<void> updateRoomAndRefresh(
    Room room, {
    bool refreshContact = false,
  }) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.rooms.put(room);
    });
    await refreshRoom(room, refreshContact: refreshContact);
  }

  /// Throws if there is no network connection or no online relay.
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

  /// Resolves a room from a Signal ratchet receive-key address.
  ///
  /// Looks up the [ContactReceiveKey] record whose `receiveKeys` list contains
  /// [address], then returns the matching room.
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
      default:
        throw UnimplementedError();
    }
  }

  /// Returns the [ChatController] for [roomId] if the chat screen is currently open,
  /// or null otherwise.
  static ChatController? getController(int roomId) {
    ChatController? cc;
    try {
      cc = Get.find<ChatController>(tag: roomId.toString());
      // ignore: empty_catches
    } catch (e) {}
    return cc;
  }

  /// Creates a room for [input] (hex or bech32 pubkey) and sends a Signal hello message.
  ///
  /// If [input] is the current identity's own pubkey, creates a self-chat room.
  /// Returns null if [input] is not a valid 64/63-character pubkey.
  /// [autoJump] navigates the UI to the newly created room.
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
      if (identity.nostrIdentityKey == hexPubkey) {
        room = await RoomService.instance.getOrCreateRoomByIdentity(
          hexPubkey,
          identity,
          RoomStatus.enabled,
        );
      } else {
        for (final iden in hc.allIdentities.values) {
          if (iden.nostrIdentityKey == hexPubkey) {
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

  /// Marks all unread messages in [room] as read and refreshes the room list.
  ///
  /// Returns true if any messages were updated.
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

  /// Marks all messages as read only if the room has unread messages.
  ///
  /// A lightweight variant that skips the DB call if unread count is already zero.
  Future<void> markAllReadSimple(Room room) async {
    final homeRoom = Get.find<HomeController>().getRoomByIdentity(
      room.identityId,
      room.id,
    );
    if (homeRoom == null) return;
    if (homeRoom.unReadCount == 0) return;
    await markAllRead(room);
  }

  /// Mutes or unmutes [room] by updating the notification server and local state.
  ///
  /// Throttled to once per second per room to prevent rapid toggling.
  Future<void> mute(Room room, bool value) async {
    EasyThrottle.throttle(
      'mute_notification:${room.id}',
      const Duration(seconds: 1),
      () async {
        final pubkeys = <String>[];

        if (room.type == RoomType.group) {
          if (room.isMLSGroup && room.receiveAddress != null) {
            pubkeys.add(room.receiveAddress!);
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

  /// Returns the room that uses [pubkey] as its receive address.
  ///
  /// Checks Signal private-chat rooms first, then MLS group rooms.
  Future<Room?> getRoomByMyReceiveKey(String pubkey) async {
    final room = await SignalChatService.instance.getSignalChatRoomByTo(pubkey);
    if (room != null) {
      return room;
    }
    final mlsRoom = await RoomService.instance.getRoomByReceiveAddress(pubkey);
    return mlsRoom;
  }

  /// Returns all common (non-group) rooms where [hexPubkey] is the peer.
  Future<List<Room>> getCommonRoomByPubkey(String hexPubkey) async {
    return DBProvider.database.rooms
        .filter()
        .toMainPubkeyEqualTo(hexPubkey)
        .typeEqualTo(RoomType.common)
        .findAll();
  }

  /// Pushes an updated [room] model to the open [ChatController], if any.
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
