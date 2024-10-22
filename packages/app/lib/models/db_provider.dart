import 'package:app/app.dart';
import 'package:app/models/ecash_bill.dart';
import 'package:app/models/nostr_event_status.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/service/secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:get/get.dart';
import 'package:isar/isar.dart';

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
      MykeySchema,
      MessageSchema,
      RoomSchema,
      RelaySchema,
      IdentitySchema,
      RoomMemberSchema,
      SignalIdSchema,
      NostrEventStatusSchema,
      EcashBillSchema,
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
