import 'package:app/app.dart';
import 'package:app/desktop/DesktopController.dart';
import 'package:app/service/secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:get/get.dart';
import 'package:isar/isar.dart';

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
    // logger.i('current db version: $currentVersion');
    if (currentVersion < 30) {
      currentVersion = 34; // skip old versions for new users
      await _migrateToVersion30();
    }
    if (currentVersion >= 30 && currentVersion < 31) {
      currentVersion = 31;
      await _migrateToVersion31();
    }
    if (currentVersion >= 31 && currentVersion < 32) {
      currentVersion = 32;
      await _migrateToVersion32();
    }
    if (currentVersion >= 32 && currentVersion < 33) {
      currentVersion = 33;
      await _migrateToVersion33();
    }
    if (currentVersion >= 33 && currentVersion < 34) {
      currentVersion = 34;
      await _migrateToVersion34();
    }
    logger.i('db version: $currentVersion');
    await Storage.setInt(StorageKeyString.dbVersion, currentVersion);
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
      if (identities[i].index != 0) continue;

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

  static Future _migrateToVersion32() async {
    List<Identity> identities =
        await DBProvider.database.identitys.where().findAll();
    await DBProvider.database.writeTxn(() async {
      for (var i = 0; i < identities.length; i++) {
        identities[i].enableBrowser = true;
        identities[i].enableChat = true;
        await DBProvider.database.identitys.put(identities[i]);
      }
    });
  }

  // delete all shareKey and kdf group
  static _migrateToVersion33() async {
    List<Room> list = await DBProvider.database.rooms
        .filter()
        .typeEqualTo(RoomType.group)
        .group((q) => q
            .groupTypeEqualTo(GroupType.shareKey)
            .or()
            .groupTypeEqualTo(GroupType.kdf))
        .findAll();
    await Future.wait(list.map((room) =>
        RoomService.instance.deleteRoom(room, websocketInited: false)));
  }

  // delete all mls group
  static _migrateToVersion34() async {
    List<Room> list = await DBProvider.database.rooms
        .filter()
        .typeEqualTo(RoomType.group)
        .groupTypeEqualTo(GroupType.mls)
        .findAll();
    await Future.wait(list.map((room) =>
        RoomService.instance.deleteRoom(room, websocketInited: false)));
  }
}
