import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:app/bot/bot_server_message_model.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/page/routes.dart';
import 'package:app/rust_api.dart';
import 'package:app/service/file.service.dart';
import 'package:app/service/storage.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:app/service/room.service.dart';
import 'package:app/models/models.dart';

import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';

import '../controller/chat.controller.dart';
import '../controller/home.controller.dart';

class MessageService {
  static MessageService? _instance;
  static MessageService get instance => _instance ??= MessageService._();
  // Avoid self instance
  MessageService._();
  static final DBProvider dbProvider = DBProvider.instance;

  Future saveMessageModel(Message model,
      {bool persist = true, required Room room}) async {
    model.receiveAt ??= DateTime.now();
    // none text type: media, file, cashu...
    model = await _fillTypeForMessage(model, room.type == RoomType.bot);

    bool isCurrentPage = false;
    if (!model.isRead) {
      isCurrentPage = dbProvider.isCurrentPage(model.roomId);
      if (isCurrentPage) model.isRead = true;
    }

    if (persist) {
      try {
        await DBProvider.database.writeTxn(() async {
          await DBProvider.database.messages.put(model);
        });
      } catch (e) {
        logger.e('persist message error: $e, ${model.content}');
        throw Exception(
            'duplicate_db: msgId:${model.msgid} roomId[${model.roomId}] ${model.content}');
      }
    } else {
      await DBProvider.database.messages.put(model);
    }
    logger.i(
        '[message]:room:${model.roomId} ${model.isMeSend ? 'Send' : 'Receive'}: ${model.content} ');
    _messageNotifyToPage(isCurrentPage, model, room);
    return model;
  }

  _messageNotifyToPage(bool isCurrentPage, Message model, Room room) async {
    await RoomService.getController(model.roomId)?.addMessage(model);
    var hc = Get.find<HomeController>();
    hc.roomLastMessage[model.roomId] = model;
    hc.loadIdentityRoomList(model.identityId);

    // show snackbar in other page
    if (!model.isRead && !isCurrentPage && Get.currentRoute != '/') {
      String contenet = model.mediaType == MessageMediaType.text
          ? (model.realMessage ?? model.content)
          : '[${model.mediaType.name}]';

      if (GetPlatform.isDesktop) {
        if (Get.find<HomeController>().resumed == false) {
          Get.find<HomeController>().addUnreadCount();
        }
        return;
      }
      EasyThrottle.throttle('newMessageSnackbar', Duration(seconds: 2), () {
        ChatController? cc = RoomService.getController(model.roomId);
        bool isCurrentRoomPage = Get.currentRoute
            .startsWith(Routes.room.replaceFirst(':id', room.id.toString()));
        if (Get.isSnackbarOpen) {
          try {
            Get.closeAllSnackbars();
            // ignore: empty_catches
          } catch (e) {}
        }
        Get.snackbar(room.getRoomName(), contenet,
            titleText: Text(room.getRoomName(),
                style: Theme.of(Get.context!).textTheme.titleMedium),
            messageText:
                Text(contenet, maxLines: 4, overflow: TextOverflow.ellipsis),
            backgroundColor:
                Theme.of(Get.context!).colorScheme.surfaceContainer,
            snackPosition: SnackPosition.TOP,
            isDismissible: true,
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            duration: const Duration(seconds: 5),
            mainButton: isCurrentRoomPage || cc != null
                ? null
                : TextButton(
                    child: const Text('View'),
                    onPressed: () {
                      pressSnackbar(room);
                    }),
            icon: Utils.getRandomAvatar(room.toMainPubkey), onTap: (c) {
          if (isCurrentRoomPage || cc != null) return;
          pressSnackbar(room);
        });
      });
    }
  }

  void pressSnackbar(Room room) {
    Get.closeAllSnackbars();
    if (Get.currentRoute.startsWith('/room/')) {
      Get.offNamed('/room/${room.id}', arguments: room);
    } else {
      Utils.toNamedRoom(room);
    }
  }

  Future saveSystemMessage(Room room, String content,
      {DateTime? createdAt,
      String suffix = 'SystemMessage',
      bool isMeSend = true}) async {
    Identity identity = room.getIdentity();
    await saveMessageModel(
        Message(
            msgid: Utils.randomString(16),
            idPubkey: isMeSend ? identity.secp256k1PKHex : room.toMainPubkey,
            identityId: room.identityId,
            roomId: room.id,
            from: isMeSend ? identity.secp256k1PKHex : room.toMainPubkey,
            to: isMeSend ? room.toMainPubkey : identity.secp256k1PKHex,
            content: suffix.isNotEmpty
                ? '''[$suffix]
$content'''
                : content,
            createdAt: createdAt ?? DateTime.now(),
            sent: SendStatusType.success,
            isMeSend: isMeSend,
            isSystem: true,
            eventIds: const [],
            encryptType: MessageEncryptType.signal,
            rawEvents: const []),
        room: room);
  }

  Future updateMessageAndRefresh(Message message) async {
    await MessageService.instance.updateMessage(message);
    refreshMessageInPage(message);
  }

  refreshMessageInPage(Message message) {
    try {
      ChatController? cc = RoomService.getController(message.roomId);
      if (cc == null) return;
      for (var i = 0; i < cc.messages.length; i++) {
        if (cc.messages[i].id == message.id) {
          cc.messages[i] = message;
          cc.messages.refresh();
          break;
        }
      }
      // ignore: empty_catches
    } catch (e) {}
  }

  Future<Message> saveMessageToDB(
      {required String from,
      required String content,
      required String to,
      required bool isMeSend,
      required Room room,
      required List<NostrEventModel> events,
      required String senderPubkey,
      required MessageEncryptType encryptType,
      bool persist = true,
      String? realMessage,
      String? senderName,
      String? subEvent,
      MsgReply? reply,
      SendStatusType sent = SendStatusType.sending,
      MessageMediaType? mediaType,
      RequestConfrimEnum? requestConfrim,
      String? requestId,
      int? createdAt,
      bool? isRead,
      bool? isSystem,
      String? msgKeyHash}) async {
    Message model = Message(
        msgid: events[0].id,
        eventIds: events.map((e) => e.id).toList(),
        identityId: room.identityId,
        idPubkey: senderPubkey,
        roomId: room.id,
        from: from,
        to: to,
        sent: sent,
        isMeSend: isMeSend,
        content: content,
        realMessage: realMessage,
        reply: reply,
        encryptType: encryptType,
        msgKeyHash: msgKeyHash,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (createdAt ?? events[0].createdAt) * 1000),
        rawEvents: events.map((e) {
          Map m = e.toJson();
          m['toIdPubkey'] = e.toIdPubkey;
          return jsonEncode(m);
        }).toList())
      ..subEvent = subEvent
      ..requestConfrim = requestConfrim
      ..requestId = requestId
      ..senderName = senderName;

    if (isRead != null) model.isRead = isRead;
    if (isSystem != null) model.isSystem = isSystem;
    if (mediaType != null) model.mediaType = mediaType;

    return await saveMessageModel(model, persist: persist, room: room);
  }

  Future<int> unreadCount() async {
    return await DBProvider.database.messages
        .filter()
        .isReadEqualTo(false)
        .count();
  }

  Future<int> unreadCountById(int identityId) async {
    Isar database = DBProvider.database;

    return await database.messages
        .filter()
        .identityIdEqualTo(identityId)
        .isReadEqualTo(false)
        .count();
  }

  Future<int> unreadCountByRoom(int roomId) async {
    Isar database = DBProvider.database;

    var count = await database.messages
        .filter()
        .isReadEqualTo(false)
        .roomIdEqualTo(roomId)
        .count();
    return count;
  }

  Future<List<Message>> listMessageUnread(int roomId) async {
    Isar database = DBProvider.database;

    return await database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .isReadEqualTo(false)
        .findAll();
  }

  distinctByRoomId() async {
    Isar database = DBProvider.database;

    return database.messages.where().distinctByRoomId().findAll();
  }

  Future<Message?> getMessageByMsgId(String id) async {
    return await DBProvider.database.messages
        .filter()
        .msgidEqualTo(id)
        .findFirst();
  }

  Future<Message?> getMessageByEventId(String id) async {
    return await DBProvider.database.messages
        .filter()
        .eventIdsElementContains(id)
        .findFirst();
  }

  Message? getMessageByMsgIdSync(String id) {
    return DBProvider.database.messages
        .filter()
        .msgidEqualTo(id)
        .findFirstSync();
  }

  Future getMessageById(int id) async {
    Isar database = DBProvider.database;
    return await database.messages.filter().idEqualTo(id).findFirst();
  }

  Future<List<Message>> getMessageByIdentityId(int identityId) async {
    Isar database = DBProvider.database;
    return await database.messages
        .filter()
        .identityIdEqualTo(identityId)
        .findAll();
  }

  Future<List<Message>> getMessageByContent(String content, int identityId) {
    return DBProvider.database.messages
        .filter()
        .contentContains(content)
        .isSystemEqualTo(false)
        .identityIdEqualTo(identityId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<DateTime> getNostrListenStartAt(String? relay) async {
    String key = StorageKeyString.lastMessageAt;
    if (relay != null) {
      key = '$key:$relay';
    }
    int lastMessageAt = await Storage.getIntOrZero(key);

    if (lastMessageAt > 0) {
      return DateTime.fromMillisecondsSinceEpoch(lastMessageAt * 1000)
          .subtract(const Duration(minutes: 3));
    }
    DateTime? time = await MessageService.instance.getLastMessageTime();
    if (time != null) return time.subtract(const Duration(minutes: 30));

    return DateTime.now().subtract(const Duration(days: 14));
  }

  Future<List<Message>> listMessageFromDB({
    required int roomId,
    limit = 100,
    int offset = 0,
  }) async {
    Isar database = DBProvider.database;

    return await database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
  }

  Future<List<Message>> getMessagesByView({
    required int roomId,
    required int maxId,
    required bool isRead,
    limit = 100,
  }) async {
    return DBProvider.database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .idLessThan(maxId)
        .isReadEqualTo(isRead)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  Future<List<Message>> listMessageByTime({
    required int roomId,
    required DateTime from,
    limit = 100,
  }) async {
    Isar database = DBProvider.database;

    return database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .createdAtLessThan(from)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  List<Message> listMessageByTimeSync({
    required int roomId,
    required DateTime from,
    limit = 100,
  }) {
    Isar database = DBProvider.database;

    return database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .createdAtGreaterThan(from)
        .sortByCreatedAt()
        .limit(limit)
        .findAllSync();
  }

  Message? listLastestMessage({
    required int roomId,
    limit = 1,
  }) {
    Isar database = DBProvider.database;

    return database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findFirstSync();
  }

  Future<List<Message>> listMessageBySearch({
    required int roomId,
    required DateTime from,
    limit = 10,
  }) async {
    Isar database = DBProvider.database;
    List<Message> msgEqual = await database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .createdAtEqualTo(from)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
    List<Message> msgLess = await database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .createdAtLessThan(from)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
    List<Message> msgMore = await database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .createdAtGreaterThan(from)
        .sortByCreatedAt()
        .limit(limit)
        .findAll();
    msgEqual.addAll(msgLess);
    msgEqual.addAll(msgMore);
    return msgEqual;
  }

  List<Message> listMessageBySearchSroll({
    required int roomId,
    required DateTime from,
    limit = 10,
  }) {
    Isar database = DBProvider.database;
    List<Message> msgEqual = database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .createdAtEqualTo(from)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAllSync();
    List<Message> msgLess = database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .createdAtLessThan(from)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAllSync();
    List<Message> msgMore = database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .createdAtGreaterThan(from)
        .sortByCreatedAt()
        .limit(limit)
        .findAllSync();
    msgEqual.addAll(msgLess);
    msgEqual.addAll(msgMore);
    return msgEqual;
  }

  Future<List<Message>> listLatestMessage({
    required int roomId,
    required DateTime from,
    limit = 100,
  }) async {
    Isar database = DBProvider.database;

    return database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .createdAtGreaterThan(from)
        .limit(limit)
        .findAll();
  }

  Future<List<Message>> listMySendingMessage({
    required int roomId,
    limit = 10,
  }) async {
    return DBProvider.database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .sentEqualTo(SendStatusType.sending)
        .isMeSendEqualTo(true)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  Future<DateTime?> getLastMessageTime() async {
    Message? m = await DBProvider.database.messages
        .filter()
        .isMeSendEqualTo(false)
        .sortByCreatedAtDesc()
        .findFirst();
    return m?.createdAt;
  }

  Future<Message?> getLastMessageByRoom(int roomId) async {
    Message? m = await DBProvider.database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .sortByCreatedAtDesc()
        .findFirst();
    return m;
  }

  Future deleteMessageById(int id) async {
    Isar database = DBProvider.database;
    await database.writeTxn(() async {
      await database.messages.filter().idEqualTo(id).deleteAll();
    });
  }

  Future deleteMessageByRoomId(int roomId) async {
    Isar database = DBProvider.database;
    await database.writeTxn(() async {
      await database.messages.filter().roomIdEqualTo(roomId).deleteAll();
    });
  }

  Future<bool> setViewedMessage(int roomId) async {
    List messages = await listMessageUnread(roomId);
    Isar database = DBProvider.database;

    await database.writeTxn(() async {
      for (var item in messages) {
        item.isRead = true;
        await database.messages.put(item);
      }
    });
    return messages.isNotEmpty;
  }

  Future clearUnreadMessage() async {
    Isar database = DBProvider.database;
    List<Message> messages =
        await database.messages.filter().isReadEqualTo(false).findAll();

    await database.writeTxn(() async {
      for (var item in messages) {
        item.isRead = true;
        await database.messages.put(item);
      }
    });
  }

  Future updateMessage(Message message) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.messages.put(message);
    });
  }

  Future updateMessageCashuStatus(int id) async {
    Message? m = await getMessageById(id);
    if (m == null) return;
    if (m.cashuInfo == null) return;
    // if (m.cashuInfo!.status == status) return;

    m.cashuInfo!.status = TransactionStatus.success;
    m.isRead = true;
    await updateMessage(m);
    return m;
  }

  Future<List<Message>> getCashuPendingMessage() async {
    Isar database = DBProvider.database;
    return await database.messages
        .filter()
        .cashuInfoIsNotNull()
        .cashuInfo((q) => q.statusEqualTo(TransactionStatus.pending))
        .findAll();
  }

  Future<Message> _fillTypeForMessage(Message m, bool isBot) async {
    // cashuA
    if (m.mediaType == MessageMediaType.cashuA ||
        m.content.startsWith('cashu')) {
      return await _cashuAInfo(m);
    }
    if (m.realMessage != null) return m;

    // image/video/file
    MsgFileInfo? mfi = m.convertToMsgFileInfo();
    if (mfi != null) {
      m.realMessage = mfi.toString();
      if (mfi.type == MessageMediaType.image.name) {
        m.mediaType = MessageMediaType.image;
        await FileService.instance.downloadForMessage(m, mfi);
        return m;
      }

      if (mfi.type == MessageMediaType.video.name) {
        m.mediaType = MessageMediaType.video;
      } else if (mfi.type == MessageMediaType.file.name) {
        m.mediaType = MessageMediaType.file;
      }
      return m;
    }

    // bot message
    if (isBot && !m.isMeSend) {
      BotServerMessageModel? bmm;
      try {
        Map<String, dynamic> map = jsonDecode(m.content);
        bmm = BotServerMessageModel.fromJson(map);
        m.mediaType = bmm.type;
        m.realMessage = bmm.message;
      } catch (e) {
        // logger.i(e, stackTrace: s);
      }
    }
    return m;
  }

  Future<Message> _cashuAInfo(Message model) async {
    try {
      late CashuInfoModel cim;
      if (model.isMeSend && model.realMessage != null) {
        cim = CashuInfoModel.fromJson(jsonDecode(model.realMessage!));
      } else {
        cim = await RustAPI.decodeToken(encodedToken: model.content);
      }
      model.mediaType = MessageMediaType.cashuA;
      model.cashuInfo = cim;
      // ignore: empty_catches
    } catch (e) {}

    return model;
  }

  deleteAll() async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.messages.clear();
    });
  }

  Future<List<Message>> getMessageByRequestId(String requestId) async {
    return DBProvider.database.messages
        .filter()
        .requestIdEqualTo(requestId)
        .requestConfrimIsNull()
        .findAll();
  }

  Future<void> checkMessageStatus({required Message message}) async {
    Message? m = await getMessageByMsgId(message.msgid);
    if (m == null || m.sent == SendStatusType.success) return;
    List<String> ess = message.rawEvents.map((e) {
      Map<String, dynamic> data = jsonDecode(e);
      return data['id'] as String;
    }).toList();
    bool isSuccess = false;
    for (var eventId in ess) {
      NostrEventStatus? nes = await DBProvider.database.nostrEventStatus
          .filter()
          .eventIdEqualTo(eventId)
          .sendStatusEqualTo(EventSendEnum.success)
          .findFirst();
      if (nes != null) {
        isSuccess = true;
        break;
      }
    }
    if (isSuccess) {
      m.sent = SendStatusType.success;
      await updateMessageAndRefresh(m);
    }
  }
}
