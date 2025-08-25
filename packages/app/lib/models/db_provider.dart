import 'package:app/app.dart';
import 'package:app/desktop/DesktopController.dart';
import 'package:flutter/foundation.dart';

import 'package:get/get.dart';
import 'package:isar_community/isar.dart';

class DBProvider {
  static DBProvider? _instance;
  static DBProvider get instance => _instance ??= DBProvider._();
  // Avoid self instance
  DBProvider._();
  static bool _isInitializing = false;
  static late Isar database;

  static initDB(String dbFolder) async {
    if (_isInitializing) return;

    _isInitializing = true;
    database = await Isar.open([
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
    ], directory: dbFolder, name: 'keychat', inspector: kDebugMode);
    await performMigrationIfNeeded(database);
    return database;
  }

  static Future<void> performMigrationIfNeeded(Isar isar) async {
    int currentVersion = await Storage.getIntOrZero(StorageKeyString.dbVersion);
    if (currentVersion < 30) {
      currentVersion = 34;
    }
    logger.i('db version: $currentVersion');
    // await Storage.setInt(StorageKeyString.dbVersion, currentVersion);
  }

  static close() async {
    await database.close();
  }

  bool isCurrentPage(int roomId) {
    if (GetPlatform.isDesktop) {
      return Get.find<DesktopController>().selectedRoom.value.id == roomId;
    }
    String route = Get.currentRoute;
    if (route.startsWith('/room/')) {
      try {
        int currentRoomId = int.parse(route.split('/room/')[1]);
        return currentRoomId == roomId;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  deleteAll() {
    database.writeTxnSync(() {
      database.clearSync();
    });
  }
}
