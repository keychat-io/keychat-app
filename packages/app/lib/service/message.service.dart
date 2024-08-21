import 'dart:convert' show jsonDecode;

import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/rust_api.dart';
import 'package:app/service/file_util.dart';
import 'package:app/service/storage.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:app/service/room.service.dart';
import 'package:app/models/models.dart';

import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';

import '../controller/chat.controller.dart';
import '../controller/home.controller.dart';
import '../models/db_provider.dart';

class MessageService {
  static final MessageService _singleton = MessageService._internal();
  static final DBProvider dbProvider = DBProvider();
  factory MessageService() {
    return _singleton;
  }

  MessageService._internal();

  Future saveMessageModel(Message model, [bool persist = true]) async {
    if (!model.isMeSend) {
      model.receiveAt = DateTime.now();
    }
    if (!model.isRead) {
      bool isCurrentPage = dbProvider.isCurrentPage(model.roomId);
      if (isCurrentPage) model.isRead = true;
    }
    // none text type: media, file, cashu...
    model = await _fillTypeForMessage(model);

    if (persist) {
      await DBProvider.database.writeTxn(() async {
        await DBProvider.database.messages.put(model);
      });
    } else {
      await DBProvider.database.messages.put(model);
    }

    logger.i(
        'message_room:${model.roomId} ${model.isMeSend ? 'Send' : 'Receive'}: ${model.content} ');

    await Get.find<HomeController>().loadIdentityRoomList(model.identityId);

    await RoomService.getController(model.roomId)?.addMessage(model);
  }

  Future updateMessageAndRefresh(Message message) async {
    await MessageService().updateMessage(message);
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
      required String idPubkey,
      required MessageEncryptType encryptType,
      bool persist = true,
      String? realMessage,
      String? subEvent,
      MsgReply? reply,
      SendStatusType sent = SendStatusType.sending,
      MessageMediaType? mediaType,
      RequestConfrimEnum? requestConfrim,
      int? createdAt,
      bool? isRead,
      bool? isSystem,
      String? msgKeyHash}) async {
    Message model = Message(
        msgid: events[0].id,
        eventIds: events.map((e) => e.id).toList(),
        identityId: room.identityId,
        idPubkey: idPubkey,
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
            (createdAt ?? events[0].createdAt) * 1000))
      ..subEvent = subEvent;
    if (isRead != null) model.isRead = isRead;
    if (isSystem != null) model.isSystem = isSystem;
    if (mediaType != null) model.mediaType = mediaType;
    if (requestConfrim != null) model.requestConfrim = requestConfrim;

    await saveMessageModel(model, persist);
    return model;
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
      return DateTime.fromMillisecondsSinceEpoch(lastMessageAt * 1000);
    }
    DateTime? time = await MessageService().getLastMessageTime();
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
    required DateTime from,
    required bool isRead,
    limit = 100,
  }) async {
    return DBProvider.database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .createdAtLessThan(from)
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
      return database.messages.filter().idEqualTo(id).deleteAll();
    });
  }

  Future deleteMessageByRoomId(int roomId) async {
    Isar database = DBProvider.database;
    await database.writeTxn(() async {
      return database.messages.filter().roomIdEqualTo(roomId).deleteAll();
    });
  }

  Future setViewedMessage(int roomId) async {
    List messages = await listMessageUnread(roomId);
    Isar database = DBProvider.database;

    await database.writeTxn(() async {
      for (var item in messages) {
        item.isRead = true;
        await database.messages.put(item);
      }
    });
  }

  Future updateMessage(Message message) async {
    await DBProvider.database.writeTxn(() async {
      return await DBProvider.database.messages.put(message);
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

  Future insertMessageBill(MessageBill model) async {
    Isar database = DBProvider.database;

    await database.writeTxn(() async {
      return await database.messageBills.put(model);
    });
  }

  Future<List<MessageBill>> getMessageBills(String eventId) async {
    Isar database = DBProvider.database;

    return await database.messageBills
        .filter()
        .eventIdEndsWith(eventId)
        .findAll();
  }

  Future<List<MessageBill>> getBillByRoomId(int roomId,
      {int minId = 99999999, int limit = 20}) async {
    return await DBProvider.database.messageBills
        .filter()
        .idLessThan(minId)
        .roomIdEqualTo(roomId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  Future<Message> _fillTypeForMessage(Message m) async {
    // cashuA
    if (m.mediaType == MessageMediaType.cashuA ||
        m.content.startsWith('cashu')) {
      return await _cashuAInfo(m);
    }
    if (m.realMessage != null) return m;

    // image
    MsgFileInfo? mfi = m.convertToMsgFileInfo();
    if (mfi == null) return m;
    m.realMessage = mfi.toString();
    if (mfi.type == MessageMediaType.image.name) {
      m.mediaType = MessageMediaType.image;
      FileUtils.downloadForMessage(m, mfi);
      return m;
    }

    if (mfi.type == MessageMediaType.video.name) {
      m.mediaType = MessageMediaType.video;
    } else if (mfi.type == MessageMediaType.file.name) {
      m.mediaType = MessageMediaType.file;
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
}
