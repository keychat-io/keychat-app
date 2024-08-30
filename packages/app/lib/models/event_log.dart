import 'package:app/models/db_provider.dart';
import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

import 'message.dart';

part 'event_log.g.dart';

@Collection(ignore: {'props', 'bobAddress', 'message'})
// ignore: must_be_immutable
class EventLog extends Equatable {
  Id id = Isar.autoIncrement;

  late String eventId;
  late String to;
  String? toIdPubkey; // receive's ID

  DateTime createdAt;
  late String snapshot;
  int kind = -1;
  DateTime? updatedAt;
  String? note; // for debug
  int resCode = 0; // init: 0  success: 200 error: 500
  List<String> sentRelays = const []; // send to relays
  List<String> okRelays = const []; // send success
  List<String> failedRelays = const []; // send failed
  List<String> failedReasons = const []; // response of relay
  Message? message;
  get bobAddress => toIdPubkey ?? to;

  EventLog(
      {required this.eventId,
      required this.to,
      required this.resCode,
      required this.createdAt});

  @override
  List<Object> get props => [
        eventId,
        to,
        resCode,
        snapshot,
        createdAt,
        kind,
        sentRelays,
        okRelays,
        failedReasons,
        failedRelays,
      ];

  Map<String, int> getRelayStatusMap() {
    Map<String, int> relayStatusMap = {};
    for (var relay in [...sentRelays, ...failedRelays]) {
      relayStatusMap[relay] = 0;
    }
    for (var relay in okRelays) {
      relayStatusMap[relay] = 1;
    }
    return relayStatusMap;
  }

  Future setNote(String message) async {
    try {
      note = 'Error: $message';
      await DBProvider.database.writeTxn(() async {
        await DBProvider.database.eventLogs.put(this);
      });
    } catch (e) {
      // logger.i('save event error ${s.toString()}');
    }
  }
}
