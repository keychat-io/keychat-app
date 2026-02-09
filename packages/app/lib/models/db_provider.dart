import 'dart:convert';

import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat/app.dart';
import 'package:keychat/desktop/DesktopController.dart';
import 'package:keychat/service/secure_storage.dart';
import 'package:keychat/service/wallet_connection_crypto.dart';
import 'package:keychat_ecash/unified_wallet/models/wallet_base.dart'
    show WalletProtocol;

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
        WalletConnectionSchema,
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
        continue migration35;
      migration35:
      case 35:
        await migrationTo36();
        currentVersion = 36;
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

  /// Migrates NWC connections from FlutterSecureStorage to Isar.
  ///
  /// Reads the old JSON array from secure storage, encrypts each URI,
  /// and writes a WalletConnection record to Isar. Deletes the old key
  /// after successful migration.
  static Future<void> migrationTo36() async {
    // Migrate NWC connections
    try {
      final nwcJson =
          await SecureStorage.storage.read(key: 'nwc_connections_list');
      if (nwcJson != null) {
        final jsonList = jsonDecode(nwcJson) as List<dynamic>;
        final crypto = WalletConnectionCrypto.instance;

        await database.writeTxn(() async {
          for (final item in jsonList) {
            final map = item as Map<String, dynamic>;
            final uri = map['uri'] as String;
            final name = map['name'] as String?;
            final weight = map['weight'] as int? ?? 0;

            // Extract wallet pubkey from NWC URI as identifier
            final identifier = _extractNwcIdentifier(uri);
            if (identifier == null) continue;

            // Check for duplicates within the same protocol
            final existing = await database.walletConnections
                .filter()
                .protocolEqualTo(WalletProtocol.nwc)
                .and()
                .identifierEqualTo(identifier)
                .findFirst();
            if (existing != null) continue;

            final encryptedUri = await crypto.encryptText(uri);
            final connection = WalletConnection.create(
              protocol: WalletProtocol.nwc,
              identifier: identifier,
              encryptedUri: encryptedUri,
              name: name,
              weight: weight,
            );
            await database.walletConnections.put(connection);
          }
        });

        // Delete old key after successful migration
        await SecureStorage.storage.delete(key: 'nwc_connections_list');
        logger.i('Migrated ${jsonList.length} NWC connections to Isar');
      }
    } catch (e, s) {
      logger.e('NWC migration failed', error: e, stackTrace: s);
    }
  }

  /// Extracts the wallet pubkey from a NWC URI for use as identifier.
  ///
  /// NWC URI format: `nostr+walletconnect://<pubkey>?relay=...&secret=...`
  static String? _extractNwcIdentifier(String uri) {
    const prefix = 'nostr+walletconnect://';
    if (!uri.startsWith(prefix)) return null;
    final withoutScheme = uri.substring(prefix.length);
    final questionMark = withoutScheme.indexOf('?');
    final identifier =
        questionMark == -1 ? withoutScheme : withoutScheme.substring(0, questionMark);
    if (identifier.isEmpty) return null;
    return identifier;
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
