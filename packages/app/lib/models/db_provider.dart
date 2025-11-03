import 'package:app/app.dart';
import 'package:app/desktop/DesktopController.dart';
import 'package:flutter/foundation.dart';

import 'package:get/get.dart';
import 'package:isar_community/isar.dart';

class DBProvider {
  // Avoid self instance
  DBProvider._();
  static DBProvider? _instance;
  static DBProvider get instance => _instance ??= DBProvider._();
  static bool _isInitializing = false;
  static late Isar database;

  static Future<Isar> initDB(String dbFolder) async {
    if (_isInitializing) return database;

    _isInitializing = true;
    database = await Isar.open(
      [
        ContactSchema,
        ContactReceiveKeySchema,
        MykeySchema,
        MessageSchema,
        RoomSchema,
        RelaySchema,
        IdentitySchema,
        RoomMemberSchema,
        SignalIdSchema,
        NostrEventStatusSchema,
        EcashBillSchema,
        BrowserBookmarkSchema,
        BrowserHistorySchema,
        BrowserConnectSchema,
        BrowserFavoriteSchema,
      ],
      directory: dbFolder,
      name: 'keychat',
    );
    await performMigrationIfNeeded(database);
    return database;
  }

  static Future<void> performMigrationIfNeeded(Isar isar) async {
    var currentVersion = Storage.getIntOrZero(StorageKeyString.dbVersion);
    if (currentVersion < 30) {
      currentVersion = 34;
    }
    switch (currentVersion) {
      case 34:
        await migrationTo35();
        currentVersion = 35;
        await Storage.setInt(StorageKeyString.dbVersion, currentVersion);
      default:
    }
    logger.i('db version: $currentVersion');
  }

  static Future<void> close() async {
    await database.close();
  }

  bool isCurrentPage(int roomId) {
    if (GetPlatform.isDesktop) {
      return Get.find<DesktopController>().selectedRoom.value.id == roomId;
    }
    final route = Get.currentRoute;
    if (route.startsWith('/room/')) {
      try {
        final currentRoomId = int.parse(route.split('/room/')[1]);
        return currentRoomId == roomId;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  void deleteAll() {
    database.writeTxnSync(() {
      database.clearSync();
    });
  }

  static Future<void> migrationTo35() async {
    final contacts = await DBProvider.database.contacts.where().findAll();
    await database.writeTxn(() async {
      for (final item in contacts) {
        item.autoCreateFromGroup = false;
        await database.contacts.put(item);
      }
    });
  }
}
