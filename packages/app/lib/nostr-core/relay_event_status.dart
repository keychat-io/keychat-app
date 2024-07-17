import 'package:app/global.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/models.dart';
import 'package:app/service/room.service.dart';
import 'package:isar/isar.dart';

class MesssageToRelayEOSE {
  int maxRelay = 0;
  List<String> okRelays = [];
  List<String> failedRelays = [];
  List<String> errorMessages = [];

  receiveRelayEOSE(String url, bool isSuccess, [String? errorMessage]) {
    if (isSuccess) {
      okRelays.add(url);
    } else {
      failedRelays.add(url);
      errorMessages.add(errorMessage ?? '');
    }
  }

  MesssageToRelayEOSE(this.maxRelay);
}

class WriteEventStatus {
  static final Map<String, MesssageToRelayEOSE> _map = {};

  static addSubscripton(String eventId, int maxRelay,
      {Function(bool)? sentCallback}) async {
    _map[eventId] = MesssageToRelayEOSE(maxRelay);

    // wait for relay response 3s
    final deadline = DateTime.now().add(
        const Duration(seconds: KeychatGlobal.messageFailedAfterSeconds - 1));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));

      if (await WriteEventStatus.isFilled(eventId)) {
        if (sentCallback != null) sentCallback(true);
        return removeSubscripton(eventId);
      }
    }
    if (sentCallback != null) sentCallback(false);
    return removeSubscripton(eventId);
  }

  static MesssageToRelayEOSE removeSubscripton(String eventId) {
    MesssageToRelayEOSE me = _map[eventId] ?? MesssageToRelayEOSE(0);
    updateEventLogAndMessageStatus(eventId, me);
    _map.remove(eventId);
    return me;
  }

  static bool fillSubscripton(String eventId, String url, bool isSuccess,
      [String? errorMessage]) {
    MesssageToRelayEOSE? m = _map[eventId];
    if (m == null) return false;
    m.receiveRelayEOSE(url, isSuccess, errorMessage);
    return true;
  }

  static isFilled(String eventId) {
    MesssageToRelayEOSE? m = _map[eventId];
    if (m == null) return false;
    return m.maxRelay == m.okRelays.length + m.failedRelays.length;
  }

  static void clear() {
    _map.clear();
  }

  static Future updateEventLogAndMessageStatus(
      String eventId, MesssageToRelayEOSE me) async {
    Isar database = DBProvider.database;

    EventLog? el =
        await database.eventLogs.filter().eventIdEqualTo(eventId).findFirst();
    if (el == null) return;

    el.okRelays = me.okRelays;
    el.failedRelays = me.failedRelays;
    el.failedReasons = me.errorMessages;
    await database.writeTxn(() async {
      el.resCode = me.okRelays.isNotEmpty ? 200 : 500;
      el.updatedAt = DateTime.now();
      await database.eventLogs.put(el);
    });

    // update mesage status
    Message? message = await database.messages
        .filter()
        .eventIdsElementContains(eventId)
        .findFirst();
    if (message == null) return;
    if (message.sent == SendStatusType.success) return;

    await database.writeTxn(() async {
      message.sent = el.okRelays.isNotEmpty
          ? SendStatusType.success
          : SendStatusType.failed;
      return await database.messages.put(message);
    });
    RoomService.getController(message.roomId)?.updateMessageStatus([message]);
  }

  static updateEventStatus(
      String relay, String eventId, bool status, String msg) async {
    MesssageToRelayEOSE me = MesssageToRelayEOSE(1);
    if (status) {
      me.okRelays = [relay];
    } else {
      me.failedRelays = [relay];
      me.errorMessages = [msg];
    }
    await updateEventLogAndMessageStatus(eventId, me);
  }
}
