import 'package:app/models/db_provider.dart';
import 'package:equatable/equatable.dart';
import 'package:isar_community/isar.dart';

part 'nostr_event_status.g.dart';

enum EventSendEnum {
  init,
  noAcitveRelay,
  relayConnecting,
  relayDisconnected,
  cashuError,
  serverReturnFailed,
  proccessError,
  success,
}

@Collection(ignore: {'props', 'rawEvent'})
// ignore: must_be_immutable
class NostrEventStatus extends Equatable {
  // ['event',id, json string]

  NostrEventStatus({
    required this.eventId,
    required this.relay,
    required this.sendStatus,
    required this.roomId,
  }) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }
  Id id = Isar.autoIncrement;

  late String eventId;
  late String relay;

  @Enumerated(EnumType.ordinal32)
  EventSendEnum sendStatus = EventSendEnum.init;

  String? error;
  int resCode = 0;
  late DateTime createdAt;
  late DateTime updatedAt;
  int version = 0;
  double ecashAmount = 0;
  String? ecashName;
  String? ecashToken;
  String? ecashMint;
  int roomId;
  bool isReceive = false;
  String? receiveSnapshot; // json string
  String? rawEvent;

  @override
  List<Object> get props => [
    eventId,
    isReceive,
    resCode,
    relay,
    sendStatus,
    createdAt,
  ];

  static Future<NostrEventStatus?> getReceiveEvent(String eventId) async {
    return DBProvider.database.nostrEventStatus
        .filter()
        .eventIdEqualTo(eventId)
        .isReceiveEqualTo(true)
        .findFirst();
  }

  static Future<void> deleteById(String eventId) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.nostrEventStatus
          .filter()
          .eventIdEqualTo(eventId)
          .deleteAll();
    });
  }

  static Future<NostrEventStatus> createReceiveEvent(
    String relay,
    String eventId,
    String receiveSnapshot,
  ) async {
    final ess =
        NostrEventStatus(
            eventId: eventId,
            relay: relay,
            sendStatus: EventSendEnum.success,
            roomId: -1,
          )
          ..receiveSnapshot = receiveSnapshot
          ..isReceive = true;
    await DBProvider.database.writeTxn(() async {
      final id = await DBProvider.database.nostrEventStatus.put(ess);
      ess.id = id;
    });
    // EasyDebounce.debounce(
    //     'createReceiveEvent$eventId', const Duration(seconds: 1), () {
    //   final count = DBProvider.database.nostrEventStatus
    //       .filter()
    //       .eventIdEqualTo(eventId)
    //       .isReceiveEqualTo(true)
    //       .count();
    // });
    return ess;
  }

  Future<void> setError(String msg) async {
    error = msg;
    sendStatus = EventSendEnum.proccessError;
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.nostrEventStatus.put(this);
    });
  }

  static Future<List<NostrEventStatus>> getLatestErrorEvents(int limit) {
    return DBProvider.database.nostrEventStatus
        .filter()
        .isReceiveEqualTo(true)
        .not()
        .sendStatusEqualTo(EventSendEnum.success)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  static Future<List<NostrEventStatus>> getPaidEvents({
    int minId = 99999999,
    int limit = 20,
  }) async {
    return DBProvider.database.nostrEventStatus
        .filter()
        .idLessThan(minId)
        .ecashAmountGreaterThan(0)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }
}
