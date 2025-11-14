import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:easy_debounce/easy_debounce.dart';
import 'package:keychat/bot/bot_server_message_model.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/nostr-core/nostr_event.dart';
import 'package:keychat/page/routes.dart';
import 'package:keychat/rust_api.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/service/storage.dart';
import 'package:keychat/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_cashu.dart' as rust_cashu;
import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';

class MessageService {
  // Avoid self instance
  MessageService._();
  static MessageService? _instance;
  static MessageService get instance => _instance ??= MessageService._();
  static final DBProvider dbProvider = DBProvider.instance;

  Future<Message> saveMessageModel(
    Message model, {
    required Room room,
    bool persist = true,
  }) async {
    model.receiveAt ??= DateTime.now();
    // none text type: media, file, cashu...
    model = await _fillTypeForMessage(model, room.type == RoomType.bot);

    var isCurrentPage = false;
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
          'Duplicate: msgId[${model.msgid}] roomId[${model.roomId}] ${model.content}',
        );
      }
    } else {
      await DBProvider.database.messages.put(model);
    }
    logger.i(
      '[message]:room:${model.roomId} ${model.isMeSend ? 'Send' : 'Receive'}: ${model.content} ',
    );
    _messageNotifyToPage(isCurrentPage, model, room);
    return model;
  }

  Future<void> _messageNotifyToPage(
    bool isCurrentPage,
    Message model,
    Room room,
  ) async {
    RoomService.getController(model.roomId)?.addMessage(model);
    final hc = Get.find<HomeController>();
    hc.roomLastMessage[model.roomId] = model;
    hc.loadIdentityRoomList(model.identityId);

    // show snackbar in other page
    if (model.isRead ||
        isCurrentPage ||
        Get.currentRoute == '/' ||
        Get.currentRoute == '/BiometricAuthScreen') {
      return;
    }

    final content = model.mediaType == MessageMediaType.text
        ? (model.realMessage ?? model.content)
        : '[${model.mediaType.name}]';

    if (GetPlatform.isDesktop) {
      if (!Get.find<HomeController>().resumed) {
        Get.find<HomeController>().addUnreadCount();
      }
      return;
    }
    EasyThrottle.throttle(
      'newMessageSnackbar',
      const Duration(seconds: 2),
      () async {
        final cc = RoomService.getController(model.roomId);
        final isCurrentRoomPage = Get.currentRoute.startsWith(
          Routes.room.replaceFirst(':id', room.id.toString()),
        );
        if (Get.isSnackbarOpen) {
          try {
            Get.closeAllSnackbars();
          } catch (e) {}
        }
        final roomName = room.getRoomName();
        Get.snackbar(
          roomName,
          content,
          titleText: Text(
            roomName,
            style: Theme.of(Get.context!).textTheme.titleMedium,
          ),
          messageText: Text(
            content,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Theme.of(Get.context!).colorScheme.surfaceContainer,
          snackPosition: SnackPosition.TOP,
          isDismissible: true,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          duration: const Duration(seconds: 4),
          mainButton: isCurrentRoomPage || cc != null
              ? null
              : TextButton(
                  child: const Text('View'),
                  onPressed: () {
                    pressSnackbar(room);
                  },
                ),
          icon: Utils.getAvatarByRoom(room),
          onTap: (c) {
            if (isCurrentRoomPage || cc != null) return;
            pressSnackbar(room);
          },
        );
      },
    );
  }

  void pressSnackbar(Room room) {
    Get.closeAllSnackbars();
    if (Get.currentRoute.startsWith('/room/')) {
      Get.offNamed('/room/${room.id}', arguments: room);
    } else {
      Utils.toNamedRoom(room);
    }
  }

  Future<void> saveSystemMessage(
    Room room,
    String content, {
    DateTime? createdAt,
    String suffix = 'SystemMessage',
    bool isMeSend = true,
  }) async {
    final identity = room.getIdentity();
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
        rawEvents: const [],
      ),
      room: room,
    );
  }

  Future<void> updateMessageAndRefresh(Message message) async {
    await MessageService.instance.updateMessage(message);
    refreshMessageInPage(message);
  }

  void refreshMessageInPage(Message message) {
    try {
      final cc = RoomService.getController(message.roomId);
      if (cc == null) return;
      for (var i = 0; i < cc.messages.length; i++) {
        if (cc.messages[i].id == message.id) {
          cc.messages[i] = message;
          EasyDebounce.debounce(
            'refreshMessageInPage${message.id}',
            const Duration(milliseconds: 100),
            () {
              cc.messages.refresh();
            },
          );
          break;
        }
      }
      // ignore: empty_catches
    } catch (e) {}
  }

  Future<Message> saveMessageToDB({
    required String from,
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
    String? msgKeyHash,
    int? connectedRelays,
  }) async {
    final model =
        Message(
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
              (createdAt ?? events[0].createdAt) * 1000,
            ),
            rawEvents: events.map((e) {
              final m = e.toJson();
              m['toIdPubkey'] = e.toIdPubkey;
              return jsonEncode(m);
            }).toList(),
          )
          ..subEvent = subEvent
          ..requestConfrim = requestConfrim
          ..requestId = requestId
          ..senderName = senderName
          ..connectedRelays = connectedRelays ?? -1;

    if (isRead != null) model.isRead = isRead;
    if (isSystem != null) model.isSystem = isSystem;
    if (mediaType != null) model.mediaType = mediaType;

    return saveMessageModel(model, persist: persist, room: room);
  }

  Future<int> unreadCount() async {
    return DBProvider.database.messages.filter().isReadEqualTo(false).count();
  }

  Future<int> unreadCountById(int identityId) async {
    final database = DBProvider.database;

    return database.messages
        .filter()
        .identityIdEqualTo(identityId)
        .isReadEqualTo(false)
        .count();
  }

  Future<int> unreadCountByRoom(int roomId) async {
    final database = DBProvider.database;

    final count = await database.messages
        .filter()
        .isReadEqualTo(false)
        .roomIdEqualTo(roomId)
        .count();
    return count;
  }

  Future<List<Message>> listMessageUnread(int roomId) async {
    return DBProvider.database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .isReadEqualTo(false)
        .findAll();
  }

  Future<Future<List<Message>>> distinctByRoomId() async {
    final database = DBProvider.database;

    return database.messages.where().distinctByRoomId().findAll();
  }

  Future<Message?> getMessageByMsgId(String id) async {
    return DBProvider.database.messages.filter().msgidEqualTo(id).findFirst();
  }

  Future<Message?> getMessageByEventId(String id) async {
    return DBProvider.database.messages
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

  Future<Message?> getMessageById(int id) async {
    final database = DBProvider.database;
    return database.messages.filter().idEqualTo(id).findFirst();
  }

  Future<List<Message>> getMessageByIdentityId(int identityId) async {
    final database = DBProvider.database;
    return database.messages.filter().identityIdEqualTo(identityId).findAll();
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
    var key = StorageKeyString.lastMessageAt;
    if (relay != null) {
      key = '$key:$relay';
    }
    final lastMessageAt = Storage.getIntOrZero(key);

    if (lastMessageAt > 0) {
      return DateTime.fromMillisecondsSinceEpoch(
        lastMessageAt * 1000,
      ).subtract(const Duration(minutes: 3));
    }
    final time = await MessageService.instance.getLastMessageTime();
    if (time != null) return time.subtract(const Duration(minutes: 30));

    return DateTime.now().subtract(const Duration(days: 14));
  }

  Future<List<Message>> listMessageFromDB({
    required int roomId,
    int limit = 100,
    int offset = 0,
  }) async {
    final database = DBProvider.database;

    return database.messages
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
    int limit = 100,
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

  Future<List<Message>> listOldMessageByTime({
    required int roomId,
    required int messageId,
    int limit = 100,
  }) async {
    final database = DBProvider.database;

    return database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .idLessThan(messageId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  Future<List<Message>> listLatestMessageByTime({
    required int roomId,
    required int messageId,
    int limit = 100,
  }) async {
    final database = DBProvider.database;

    return database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .idGreaterThan(messageId)
        .sortByCreatedAt()
        .limit(limit)
        .findAll();
  }

  List<Message> listMessageByTimeSync({
    required int roomId,
    required DateTime from,
    int limit = 100,
  }) {
    final database = DBProvider.database;

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
    int limit = 1,
  }) {
    final database = DBProvider.database;

    return database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findFirstSync();
  }

  Future<DateTime?> getLastMessageTime() async {
    final m = await DBProvider.database.messages
        .filter()
        .isMeSendEqualTo(false)
        .sortByCreatedAtDesc()
        .findFirst();
    return m?.createdAt;
  }

  Future<Message?> getLastMessageByRoom(int roomId) async {
    final m = await DBProvider.database.messages
        .filter()
        .roomIdEqualTo(roomId)
        .sortByCreatedAtDesc()
        .findFirst();
    return m;
  }

  Future<void> deleteMessageById(int id) async {
    final database = DBProvider.database;
    await database.writeTxn(() async {
      await database.messages.filter().idEqualTo(id).deleteAll();
    });
  }

  Future<void> deleteMessageByRoomId(int roomId) async {
    final database = DBProvider.database;
    await database.writeTxn(() async {
      await database.messages.filter().roomIdEqualTo(roomId).deleteAll();
    });
  }

  Future<bool> setViewedMessage(int roomId) async {
    final unreads = await listMessageUnread(roomId);
    final database = DBProvider.database;

    await database.writeTxn(() async {
      for (final item in unreads) {
        item.isRead = true;
        await database.messages.put(item);
      }
    });
    return unreads.isNotEmpty;
  }

  Future<void> clearUnreadMessage() async {
    final database = DBProvider.database;
    final messages = await database.messages
        .filter()
        .isReadEqualTo(false)
        .findAll();

    await database.writeTxn(() async {
      for (final item in messages) {
        item.isRead = true;
        await database.messages.put(item);
      }
    });
  }

  Future<void> updateMessage(Message message) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.messages.put(message);
    });
  }

  Future<Message?> updateMessageCashuStatus(int id) async {
    final m = await getMessageById(id);
    if (m == null) return null;
    if (m.cashuInfo == null) return m;
    // if (m.cashuInfo!.status == status) return;

    m.cashuInfo!.status = TransactionStatus.success;
    m.isRead = true;
    await updateMessageAndRefresh(m);
    return m;
  }

  Future<List<Message>> getCashuPendingMessage() async {
    final database = DBProvider.database;
    return database.messages
        .filter()
        .cashuInfoIsNotNull()
        .cashuInfo((q) => q.statusEqualTo(TransactionStatus.pending))
        .findAll();
  }

  Future<Message> _fillTypeForMessage(Message m, bool isBot) async {
    // cashu token
    if (m.mediaType == MessageMediaType.cashu ||
        m.content.startsWith('cashu')) {
      return _cashuMessage(m);
    }
    // lightning invoice
    if (m.mediaType == MessageMediaType.lightningInvoice ||
        m.content.startsWith('lightning:') ||
        m.content.startsWith('lnbc')) {
      return _lightningInvoiceMessage(m);
    }

    if (m.realMessage != null) return m;

    // image/video/file
    final mfi = m.convertToMsgFileInfo();
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
        final map = jsonDecode(m.content) as Map<String, dynamic>;
        bmm = BotServerMessageModel.fromJson(map);
        m.mediaType = bmm.type;
        m.realMessage = bmm.message;
      } catch (e) {
        // logger.i(e, stackTrace: s);
      }
    }
    return m;
  }

  Future<Message> _cashuMessage(Message model) async {
    try {
      late CashuInfoModel cim;
      if (model.isMeSend && model.realMessage != null) {
        cim = CashuInfoModel.fromJson(jsonDecode(model.realMessage!));
      } else {
        cim = await RustAPI.decodeToken(encodedToken: model.content);
        cim.id = null; // local id
      }
      model.mediaType = MessageMediaType.cashu;
      model.cashuInfo = cim;
      // ignore: empty_catches
    } catch (e) {}

    return model;
  }

  Future<Message> _lightningInvoiceMessage(Message model) async {
    try {
      late CashuInfoModel cim;
      if (model.isMeSend && model.realMessage != null) {
        cim = CashuInfoModel.fromJson(jsonDecode(model.realMessage!));
      } else {
        var invoice = model.content;
        if (invoice.startsWith('lightning:')) {
          invoice = invoice.replaceFirst('lightning:', '');
        }
        final ii = await rust_cashu.decodeInvoice(encodedInvoice: invoice);
        cim = CashuInfoModel()
          ..amount = ii.amount.toInt()
          ..token = invoice
          ..mint = ii.mint ?? ''
          ..hash = ii.hash
          ..expiredAt = ii.expiryTs == BigInt.zero
              ? null
              : DateTime.fromMillisecondsSinceEpoch(ii.expiryTs.toInt());
      }
      model.mediaType = MessageMediaType.lightningInvoice;
      model.cashuInfo = cim;
      // ignore: empty_catches
    } catch (e) {}

    return model;
  }

  Future<void> deleteAll() async {
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
    final m = await getMessageByMsgId(message.msgid);
    if (m == null || m.sent == SendStatusType.success) return;
    final ess = message.rawEvents.map((e) {
      final data = jsonDecode(e) as Map<String, dynamic>;
      return data['id'] as String;
    }).toList();
    var isSuccess = false;
    for (final eventId in ess) {
      final nes = await DBProvider.database.nostrEventStatus
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

  Future<void> addReactionToMessage({
    required Message sourceMessage,
    required String emoji,
    required Message replyMessage,
    required Room room,
  }) async {
    final message = await MessageService.instance.getMessageById(
      sourceMessage.id,
    );
    if (message == null) return;
    final react = {
      'eventId': replyMessage.msgid,
      'pubkey': replyMessage.idPubkey,
      'emoji': emoji,
    };
    message.reactionMessages = [...message.reactionMessages, jsonEncode(react)];
    await MessageService.instance.updateMessageAndRefresh(message);
  }
}
