import 'dart:convert' show jsonEncode;

import 'package:app/app.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/service/secure_storage.dart';
import 'package:flutter/foundation.dart';

import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

class DBProvider {
  static bool _isInitializing = false;
  static final DBProvider _instance = DBProvider._internal();
  static late Isar database;
  DBProvider._internal();
  factory DBProvider() => _instance;

  static initDB(String dbFolder) async {
    if (_isInitializing) return;

    _isInitializing = true;
    database = await Isar.open([
      ContactSchema,
      ContactReceiveKeySchema,
      EventLogSchema,
      MykeySchema,
      MessageSchema,
      MessageBillSchema,
      RoomSchema,
      RelaySchema,
      IdentitySchema,
      RoomMemberSchema,
      SignalIdSchema,
    ], directory: dbFolder, name: 'keychat', inspector: kDebugMode);
    await performMigrationIfNeeded(database);
    return database;
  }

  static Future<void> performMigrationIfNeeded(Isar isar) async {
    int currentVersion = await Storage.getIntOrZero(StorageKeyString.dbVersion);
    logger.i('current db version: $currentVersion');
    if (currentVersion < 30) {
      await _migrateToVersion30();
      await Storage.setInt(StorageKeyString.dbVersion, 30);
      return;
    }
    // var model =
    //     await DBProvider.database.identitys.filter().idEqualTo(4).findFirst();
    // DBProvider.database.writeTxn(() async {
    //   await DBProvider.database.identitys.delete(model!.id);
    // });

    switch (currentVersion) {
      case 30:
        await _migrateToVersion31();
        await Storage.setInt(StorageKeyString.dbVersion, 31);
        return;
      default:
        break;
      //throw Exception('Unknown version: $currentVersion');
    }
  }

  static close() async {
    await database.close();
  }

  bool isCurrentPage(int roomId) {
    String route = Get.currentRoute;
    if (route.startsWith('/room/')) {
      int currentRoomId = int.parse(route.split('/room/')[1]);
      return currentRoomId == roomId;
    }
    return false;
  }

  deleteAll() {
    database.writeTxnSync(() {
      database.clearSync();
    });
  }

  static Future mykeySetUpdate() async {}

  Future<EventLog?> getEventLog(String eventId, String to) async {
    return await database.eventLogs
        .filter()
        .eventIdEqualTo(eventId)
        .toEqualTo(to)
        .findFirst();
  }

  Future<List<EventLog>> getLatestEvents([int limit = 20]) async {
    return await database.eventLogs
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  Future<EventLog?> getEventLogByEventId(String eventId) async {
    return await database.eventLogs
        .filter()
        .eventIdEqualTo(eventId)
        .findFirst();
  }

  Future<List<EventLog>> getFaildEventLog() async {
    return await database.eventLogs
        .filter()
        .resCodeEqualTo(0)
        .createdAtGreaterThan(DateTime.now().subtract(const Duration(days: 1)))
        .createdAtLessThan(DateTime.now().subtract(const Duration(seconds: 2)))
        .kindEqualTo(EventKinds.encryptedDirectMessage)
        .sortByCreatedAtDesc()
        .limit(10)
        .findAll();
  }

  Future<bool> checkEventExist(String eventId, String to) async {
    var e2 = await database.eventLogs
        .filter()
        .toEqualTo(to)
        .eventIdEqualTo(eventId)
        .findFirst();
    if (e2 != null) return true;
    return false;
  }

  Future<EventLog> receiveNewEventLog(
      {required NostrEventModel event,
      required String relay,
      int kind = EventKinds.encryptedDirectMessage}) async {
    List tags = event.tags[0];
    String to = event.pubkey;
    if (tags.isNotEmpty) to = tags[1];
    EventLog model = EventLog(
        eventId: event.id, resCode: 200, to: to, createdAt: DateTime.now())
      ..kind = kind
      ..okRelays = [relay]
      ..snapshot = jsonEncode(event.toJson());

    await updateEventLog(model);
    return model;
  }

  saveMyEventLog(
      {required NostrEventModel event,
      required List<String> relays,
      String? toIdPubkey,
      int kind = EventKinds.encryptedDirectMessage}) async {
    List tags = event.tags[0];
    String to = event.pubkey;
    if (tags.isNotEmpty) to = tags[1];
    EventLog model = EventLog(
        eventId: event.id, resCode: 0, to: to, createdAt: DateTime.now())
      ..toIdPubkey = toIdPubkey
      ..kind = kind
      ..sentRelays = relays
      ..snapshot = jsonEncode(event.toJson());

    await updateEventLog(model);
  }

  Future updateEventLog(EventLog model) async {
    try {
      await database.writeTxn(() async {
        await database.eventLogs.put(model);
      });
    } catch (e) {
      // logger.i('save event error ${s.toString()}');
    }
  }

  static Future _migrateToVersion30() async {
    List<Identity> list = await database.identitys.where().findAll();
    if (list.isEmpty) return;
    var i = 0;
    for (var item in list) {
      if (item.secp256k1SKHex == null) continue;
      if (item.secp256k1SKHex!.isEmpty) continue;

      if (item.secp256k1SKHex != null) {
        await SecureStorage.instance
            .writePrikey(item.secp256k1PKHex, item.secp256k1SKHex!);
      }
      if (item.curve25519PkHex != null && item.curve25519SkHex != null) {
        await SecureStorage.instance
            .writePrikey(item.curve25519PkHex!, item.curve25519SkHex!);
      }
      // only remove the first mnemonic
      if (i == 0 && item.mnemonic != null) {
        await SecureStorage.instance.writePhraseWords(item.mnemonic!);
      }
      item.mnemonic = null;
      item.secp256k1SKHex = null;
      item.curve25519SkHex = null;
      await database.writeTxn(() async {
        await database.identitys.put(item);
      });
      i++;
    }
    // Map<String, String> allValues = await SecureStorage.instance.readAll();
    // logger.d(allValues);
  }

  // set index for identity
  static _migrateToVersion31() async {
    String? mnemonic = await SecureStorage.instance.getPhraseWords();
    if (mnemonic == null) return;
    List<Identity> identities =
        await DBProvider.database.identitys.where().findAll();
    List<rust_nostr.Secp256k1Account> sa = await rust_nostr
        .importFromPhraseWith(phrase: mnemonic, offset: 0, count: 10);
    for (var i = 0; i < identities.length; i++) {
      for (var j = 0; j < sa.length; j++) {
        // if (identities[i].index > -1) continue;
        if (identities[i].secp256k1PKHex == sa[j].pubkey) {
          identities[i].index = j;
          await DBProvider.database.writeTxn(() async {
            await DBProvider.database.identitys.put(identities[i]);
          });
          break;
        }
      }
    }
  }
}
