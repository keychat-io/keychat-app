import 'package:app/global.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/nostr_event_status.dart';
import 'package:app/models/models.dart';
import 'package:app/service/message.service.dart';
import 'package:isar/isar.dart';

class MesssageToRelayEOSE {
  int maxRelay = 0;
  List<String> okRelays = [];
  Map<String, String> errors = {};

  receiveRelayEOSE(String url, bool isSuccess, [String? errorMessage]) {
    if (isSuccess) {
      okRelays.add(url);
    } else {
      errors[url] = errorMessage ?? '';
    }
  }

  MesssageToRelayEOSE(this.maxRelay);
}

class SubscribeEventStatus {
  static final Map<String, MesssageToRelayEOSE> _map = {};

  static addSubscripton(String eventId, int maxRelay,
      {Function(bool)? sentCallback}) async {
    if (maxRelay == 0) return;
    _map[eventId] = MesssageToRelayEOSE(maxRelay);

    // wait for relay response 3s
    final deadline = DateTime.now()
        .add(const Duration(seconds: KeychatGlobal.messageFailedAfterSeconds));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));

      if (await SubscribeEventStatus.isFilled(eventId)) {
        if (sentCallback != null) sentCallback(true);
        return removeSubscripton(eventId);
      }
    }
    if (sentCallback != null) sentCallback(false);
    return removeSubscripton(eventId);
  }

  static MesssageToRelayEOSE removeSubscripton(String eventId) {
    MesssageToRelayEOSE me = _map[eventId] ?? MesssageToRelayEOSE(0);
    updateEventAndMessageStatus(eventId, me);
    _map.remove(eventId);
    return me;
  }

  static fillSubscripton(String eventId, String url, bool isSuccess,
      [String? errorMessage]) {
    MesssageToRelayEOSE? m = _map[eventId];
    if (m != null) {
      m.receiveRelayEOSE(url, isSuccess, errorMessage);
      return;
    }
    MesssageToRelayEOSE me = MesssageToRelayEOSE(1);
    me.receiveRelayEOSE(url, isSuccess, errorMessage);
    updateEventAndMessageStatus(eventId, me);
  }

  static isFilled(String eventId) {
    MesssageToRelayEOSE? m = _map[eventId];
    if (m == null) return false;
    return m.maxRelay == m.okRelays.length + m.errors.keys.length;
  }

  static void clear() {
    _map.clear();
  }

  static Future updateEventAndMessageStatus(
      String eventId, MesssageToRelayEOSE me) async {
    Isar database = DBProvider.database;

    List<NostrEventStatus> ess = await database.nostrEventStatus
        .filter()
        .eventIdEqualTo(eventId)
        .isReceiveEqualTo(false)
        .findAll();

    if (ess.isEmpty) return;
    // update sent status
    int sentSuccessRelay = 0;
    await database.writeTxn(() async {
      for (NostrEventStatus es in ess) {
        if (me.okRelays.contains(es.relay)) {
          sentSuccessRelay++;
          es.sendStatus = EventSendEnum.success;
          await database.nostrEventStatus.put(es);
          continue;
        }
        if (me.errors[es.relay] != null) {
          es.sendStatus = EventSendEnum.serverReturnFailed;
          es.error = me.errors[es.relay];
          await database.nostrEventStatus.put(es);
        }
      }
    });
    // update mesage status
    Message? message = await database.messages
        .filter()
        .eventIdsElementContains(eventId)
        .findFirst();
    if (message == null) return;
    if (message.sent == SendStatusType.success) return;

    if (message.sent != SendStatusType.success) {
      message.sent =
          sentSuccessRelay > 0 ? SendStatusType.success : SendStatusType.failed;
    }
    MessageService().updateMessageAndRefresh(message);
  }
}
