import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/service/message.service.dart';
import 'package:isar_community/isar.dart';

class MesssageToRelayEOSE {
  MesssageToRelayEOSE(this.maxRelay);
  int maxRelay = 0;
  List<String> okRelays = [];
  Map<String, String> errors = {};

  void receiveRelayEOSE(String url, bool isSuccess, [String? errorMessage]) {
    if (isSuccess) {
      okRelays.add(url);
    } else {
      errors[url] = errorMessage ?? '';
    }
  }
}

class SubscribeEventStatus {
  static final Map<String, MesssageToRelayEOSE> _map = {};

  static Future<void> addSubscripton(String eventId, int maxRelay,
      {Function(bool)? sentCallback}) async {
    if (maxRelay == 0) return;
    _map[eventId] = MesssageToRelayEOSE(maxRelay);

    // wait for relay response 3s
    final deadline = DateTime.now()
        .add(const Duration(seconds: KeychatGlobal.messageFailedAfterSeconds));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));

      if (SubscribeEventStatus.isFilled(eventId)) {
        if (sentCallback != null) sentCallback(true);
        removeSubscripton(eventId);
        return;
      }
    }
    if (sentCallback != null) sentCallback(false);
    removeSubscripton(eventId);
    return;
  }

  static MesssageToRelayEOSE removeSubscripton(String eventId) {
    final me = _map[eventId] ?? MesssageToRelayEOSE(0);
    updateEventAndMessageStatus(eventId, me);
    _map.remove(eventId);
    return me;
  }

  static void fillSubscripton(String eventId, String url, bool isSuccess,
      [String? errorMessage]) {
    final m = _map[eventId];
    if (m != null) {
      m.receiveRelayEOSE(url, isSuccess, errorMessage);
      return;
    }
    final me = MesssageToRelayEOSE(1);
    me.receiveRelayEOSE(url, isSuccess, errorMessage);
    updateEventAndMessageStatus(eventId, me);
  }

  static bool isFilled(String eventId) {
    final m = _map[eventId];
    if (m == null) return false;
    return m.maxRelay == m.okRelays.length + m.errors.keys.length;
  }

  static void clear() {
    _map.clear();
  }

  static Future<void> updateEventAndMessageStatus(
      String eventId, MesssageToRelayEOSE me) async {
    final database = DBProvider.database;

    final ess = await database.nostrEventStatus
        .filter()
        .eventIdEqualTo(eventId)
        .isReceiveEqualTo(false)
        .findAll();

    if (ess.isEmpty) return;
    // update sent status
    var sentSuccessRelay = 0;
    await database.writeTxn(() async {
      for (final es in ess) {
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
    final message = await database.messages
        .filter()
        .eventIdsElementContains(eventId)
        .findFirst();
    if (message == null) return;
    if (message.sent == SendStatusType.success) return;

    if (message.sent != SendStatusType.success) {
      message.sent =
          sentSuccessRelay > 0 ? SendStatusType.success : SendStatusType.failed;
    }
    MessageService.instance.updateMessageAndRefresh(message);
  }
}
