import 'dart:convert';

import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat/constants.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/models.dart';
import 'package:keychat/nostr-core/nostr.dart';
import 'package:keychat/service/chatx.service.dart';
import 'package:keychat/service/contact.service.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/relay.service.dart';
import 'package:keychat/service/room.service.dart';
import 'package:keychat/service/secure_storage.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;
import 'package:keychat_rust_ffi_plugin/api_signal/types.dart'
    show KeychatIdentityKeyPair;

class IdentityService {
  // Avoid self instance
  IdentityService._();
  static IdentityService? _instance;
  static IdentityService get instance => _instance ??= IdentityService._();

  /// Returns true if [prikey] is already stored in the database.
  Future<bool> checkPrikeyExist(String prikey) async {
    final res = await DBProvider.database.mykeys
        .filter()
        .prikeyEqualTo(prikey)
        .findFirst();
    return res != null;
  }

  /// Returns the total number of identities stored in the database.
  Future<int> count() async {
    final database = DBProvider.database;
    return database.identitys.where().count();
  }

  /// Generates a fresh secp256k1 one-time key for [identityId] and persists it.
  ///
  /// One-time keys are advertised publicly so other users can initiate a Signal
  /// session without knowing the recipient's long-term identity key.
  Future<Mykey> createOneTimeKey(int identityId) async {
    final database = DBProvider.database;
    final keychain = await rust_nostr.generateSecp256K1();
    final ontTimeKey =
        Mykey(
            prikey: keychain.prikey,
            identityId: identityId,
            pubkey: keychain.pubkey,
          )
          ..isOneTime = true
          ..oneTimeUsed = false;
    await database.writeTxn(() async {
      await database.mykeys.put(ontTimeKey);
    });
    return ontTimeKey;
  }

  /// Common initialization logic after identity creation
  Future<void> _postCreateIdentity(
    Identity identity,
    String pubkey, {
    required bool isFirstAccount,
  }) async {
    final homeController = Get.find<HomeController>();

    // Reload room list
    await homeController.loadRoomList(init: true);

    // Listen to pubkey when relay is online
    Utils.waitRelayOnline().then((_) async {
      Get.find<WebsocketService>().listenPubkey(
        [pubkey],
        kinds: [EventKinds.nip04],
      );
      Get.find<WebsocketService>().listenPubkeyNip17([pubkey]);
      final reloadedIdentity = await getIdentityByNostrPubkey(pubkey);
      if (reloadedIdentity != null) {
        syncProfileFromRelay(identity);
      }
    });

    // Handle first account specific initialization
    if (isFirstAccount) {
      try {
        Get.find<EcashController>().initIdentity(identity);
        homeController.loadAppRemoteConfig();

        // Request notification permission for first account
        NotifyService.instance
            .init(requestPermission: true)
            .then((_) => NotifyService.instance.addPubkeys([pubkey]))
            .catchError((Object e, StackTrace s) {
              logger.e('initNotification error', error: e, stackTrace: s);
              return false;
            });
        RelayService.instance.initRelay();
      } catch (e, s) {
        logger.e('First account init error', error: e, stackTrace: s);
      }
    } else {
      // For non-first accounts, just add pubkeys
      NotifyService.instance.addPubkeys([pubkey]);
    }

    // Initialize MLS
    MlsGroupService.instance.initIdentities([identity]).then((_) {
      MlsGroupService.instance.uploadKeyPackages(identities: [identity]);
    });
  }

  /// Creates a new identity from a freshly generated [account] (mnemonic-derived).
  ///
  /// Persists the identity and its keys to the database and secure storage,
  /// then performs first-account initialisation (relay setup, notifications, MLS).
  /// Throws if [account.mnemonic] is null or if the identity already exists.
  Future<Identity> createIdentity({
    required String name,
    required rust_nostr.Secp256k1Account account,
    required int index,
  }) async {
    if (account.mnemonic == null) throw Exception('mnemonic is null');
    final isFirstAccount = await count() == 0;
    final database = DBProvider.database;

    final exist = await getIdentityByNostrPubkey(account.pubkey);
    if (exist != null) throw Exception('Identity already exist');

    final identity =
        Identity(
            name: name,
            secp256k1PKHex: account.pubkey,
            npub: account.pubkeyBech32,
          )
          ..curve25519PkHex = account.curve25519PkHex
          ..index = index;

    // Save to database with keys
    await database.writeTxn(() async {
      await database.identitys.put(identity);
      await SecureStorage.instance.writePhraseWordsWhenNotExist(
        account.mnemonic!,
      );
      await SecureStorage.instance.write(
        identity.secp256k1PKHex,
        account.prikey,
      );
      await SecureStorage.instance.write(
        identity.curve25519PkHex!,
        account.curve25519SkHex!,
      );
    });

    // Common post-creation initialization
    await _postCreateIdentity(
      identity,
      account.pubkey,
      isFirstAccount: isFirstAccount,
    );

    return identity;
  }

  /// Creates a new identity from an existing private key (import flow).
  ///
  /// The identity is stored with [index] = -1 to indicate it was imported rather
  /// than derived from a mnemonic. No mnemonic is persisted.
  /// Throws if the identity already exists.
  Future<Identity> createIdentityByPrikey({
    required String name,
    required String hexPubkey,
    required String prikey,
  }) async {
    final isFirstAccount = await count() == 0;
    final database = DBProvider.database;

    final exist = await getIdentityByNostrPubkey(hexPubkey);
    if (exist != null) throw Exception('Identity already exist');

    final npub = rust_nostr.getBech32PubkeyByHex(hex: hexPubkey);
    final identity = Identity(name: name, secp256k1PKHex: hexPubkey, npub: npub)
      ..index = -1;

    // Save to database with private key
    await database.writeTxn(() async {
      await database.identitys.put(identity);
      await SecureStorage.instance.write(hexPubkey, prikey);
    });

    // Common post-creation initialization
    await _postCreateIdentity(
      identity,
      hexPubkey,
      isFirstAccount: isFirstAccount,
    );

    return identity;
  }

  /// Creates a new identity using a public key from an external signer (e.g. Amber).
  ///
  /// No private key is stored; signing is delegated to the external signer app.
  /// [pubkey] may be either bech32 (npub) or hex format.
  /// Throws if the identity already exists.
  Future<Identity> createIdentityByAmberPubkey({
    required String name,
    required String pubkey,
  }) async {
    final isFirstAccount = await count() == 0;
    final database = DBProvider.database;

    final hexPubkey = rust_nostr.getHexPubkeyByBech32(bech32: pubkey);
    final exist = await getIdentityByNostrPubkey(hexPubkey);
    if (exist != null) throw Exception('Identity already exist');

    final npub = rust_nostr.getBech32PubkeyByHex(hex: hexPubkey);
    final identity = Identity(name: name, secp256k1PKHex: hexPubkey, npub: npub)
      ..index = -1
      ..isFromSigner = true;

    // Save to database (no private key for Amber/Signer)
    await database.writeTxn(() async {
      await database.identitys.put(identity);
    });

    // Common post-creation initialization
    await _postCreateIdentity(
      identity,
      hexPubkey,
      isFirstAccount: isFirstAccount,
    );

    return identity;
  }

  /// Permanently deletes [identity] and all associated data.
  ///
  /// Cascades to: rooms, messages, contacts, one-time keys, receive keys,
  /// Signal sessions, MLS state, and files.  Also removes the identity's
  /// pubkeys from the notification server.
  Future<void> delete(Identity identity) async {
    final database = DBProvider.database;

    final id = identity.id;
    final secp256k1PKHex = identity.secp256k1PKHex;
    final curve25519PkHex = identity.curve25519PkHex;
    await database.writeTxn(() async {
      await database.identitys.delete(id);
      await database.mykeys.filter().identityIdEqualTo(id).deleteAll();
      await database.contactReceiveKeys
          .filter()
          .identityIdEqualTo(id)
          .deleteAll();

      final rooms = await database.rooms
          .filter()
          .identityIdEqualTo(id)
          .findAll();

      for (final element in rooms) {
        await database.messages.filter().roomIdEqualTo(element.id).deleteAll();
        await database.rooms.delete(element.id);
        await database.roomMembers
            .filter()
            .roomIdEqualTo(element.id)
            .deleteAll();
        await database.nostrEventStatus
            .filter()
            .roomIdEqualTo(element.id)
            .deleteAll();
        try {
          final signalIdPubkey = element.signalIdPubkey;
          KeychatIdentityKeyPair? keyPair;
          final chatxService = Get.find<ChatxService>();
          if (signalIdPubkey != null) {
            keyPair = await chatxService.setupSignalStoreBySignalId(
              signalIdPubkey,
            );
          } else {
            keyPair = await chatxService.getKeyPairByIdentity(identity);
          }
          // delete signal session by remote address
          await chatxService.deleteSignalSessionKPA(element);
          // delete signal session by identity id
          await rust_signal.deleteSessionByDeviceId(
            keyPair: keyPair,
            deviceId: id,
          );
        } catch (e, s) {
          logger.e('delete signal session error: $e', stackTrace: s);
        }
      }
      await database.contacts.filter().identityIdEqualTo(id).deleteAll();
      await FileService.instance.deleteAllByIdentity(id);
      await SecureStorage.instance.deletePrikey(secp256k1PKHex);
      if (curve25519PkHex != null) {
        await SecureStorage.instance.deletePrikey(curve25519PkHex);
      }
    });
    await Get.find<HomeController>().loadRoomList(init: true);
    await NotifyService.instance.syncPubkeysToServer();
  }

  /// Deletes one-time keys by their Isar [ids].
  Future<void> deleteMykey(List<int> ids) async {
    final database = DBProvider.database;

    return database.writeTxn(() async {
      await database.mykeys.deleteAll(ids);
    });
  }

  /// Returns the identity with the given Isar [id], or throws if not found.
  Future<Identity?> getIdentityById(int id) async {
    final database = DBProvider.database;

    final identity = await database.identitys
        .filter()
        .idEqualTo(id)
        .findFirst();
    if (identity == null) throw Exception('identity is null');
    return identity;
  }

  /// Looks up a [Mykey] record by its secp256k1 public key.
  Future<Mykey?> getMykeyByPubkey(String pubkey) async {
    return DBProvider.database.mykeys
        .filter()
        .pubkeyEqualTo(pubkey)
        .findFirst();
  }

  /// Returns all pubkeys that should be subscribed to on Nostr relays.
  ///
  /// Includes identity pubkeys, shared-key group pubkeys, and one-time keys.
  /// If [skipMute] is true, muted rooms are excluded from the result.
  Future<List<String>> getListenPubkeys({bool skipMute = false}) async {
    final pubkeys = <String>{};

    final list = Get.find<HomeController>().allIdentities.values.toList();
    final skipedIdentityIDs = <int>[];
    for (final identity in list) {
      if (!identity.enableChat) {
        skipedIdentityIDs.add(identity.id);
        continue;
      }
      pubkeys.add(identity.secp256k1PKHex);
    }
    if (pubkeys.isEmpty) return [];

    // my receive onetime key
    final oneTimeKeys = await getOneTimeKeys();
    pubkeys.addAll(oneTimeKeys.map((e) => e.pubkey));

    return pubkeys.toList();
  }

  /// Returns all [Mykey] records in the database.
  Future<List<Mykey>> getMykeyList() async {
    final database = DBProvider.database;
    return database.mykeys.where().findAll();
  }

  /// Returns all [Mykey] records sorted by creation date ascending.
  Future<List<Mykey>> list() async {
    final database = DBProvider.database;

    return database.mykeys.where().sortByCreatedAt().findAll();
  }

  /// Returns all [Identity] records in the database.
  Future<List<Identity>> listIdentity() async {
    return DBProvider.database.identitys.where().findAll();
  }

  /// Persists an updated [Mykey] record to the database.
  Future<void> updateMykey(Mykey my) async {
    final database = DBProvider.database;

    await database.writeTxn(() async {
      return database.mykeys.put(my);
    });
  }

  /// Persists an updated [Identity] record to the database.
  Future<void> updateIdentity(Identity identity) async {
    final database = DBProvider.database;
    await database.writeTxn(() async {
      await database.identitys.put(identity);
    });
  }

  /// Returns the [Mykey] if [toAddress] is one of this device's one-time keys,
  /// or null otherwise.
  Future<Mykey?> isFromOnetimeKey(String toAddress) async {
    final res = await DBProvider.database.mykeys
        .filter()
        .isOneTimeEqualTo(true)
        .pubkeyEqualTo(toAddress)
        .findAll();
    return res.isNotEmpty ? res[0] : null;
  }

  /// Returns all one-time keys across all identities, sorted by creation date.
  Future<List<Mykey>> getOneTimeKeys() async {
    return DBProvider.database.mykeys
        .filter()
        .isOneTimeEqualTo(true)
        .sortByCreatedAt()
        .findAll();
  }

  /// Returns unused one-time keys for the given [identityId], sorted by creation date.
  Future<List<Mykey>> getOneTimeKeyByIdentity(int identityId) async {
    return DBProvider.database.mykeys
        .filter()
        .identityIdEqualTo(identityId)
        .isOneTimeEqualTo(true)
        .oneTimeUsedEqualTo(false)
        .sortByCreatedAt()
        .findAll();
  }

  /// Deletes one-time keys that were used more than 3 days ago.
  ///
  /// Keeps a short grace period so in-flight messages can still be decrypted
  /// before the keys are purged.
  Future<void> deleteExpiredOneTimeKeys() async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.mykeys
          .filter()
          .isOneTimeEqualTo(true)
          .oneTimeUsedEqualTo(true)
          .updatedAtLessThan(
            DateTime.now().subtract(
              const Duration(days: 3),
            ),
          )
          .deleteAll();
    });
  }

  /// Returns all identities stored in the database.
  Future<List<Identity>> getIdentityList() async {
    return DBProvider.database.identitys.where().findAll();
  }

  /// Returns identities that have chat features enabled.
  Future<List<Identity>> getEnableChatIdentityList() async {
    return DBProvider.database.identitys
        .filter()
        .enableChatEqualTo(true)
        .findAll();
  }

  /// Returns Isar IDs of identities that have chat features disabled.
  ///
  /// Used to filter out pubkeys from relay subscriptions and notification lists.
  Future<List<int>> getDisableChatIdentityIDList() async {
    final list = await DBProvider.database.identitys
        .filter()
        .enableChatEqualTo(false)
        .findAll();
    return list.map((e) => e.id).toList();
  }

  /// Returns identities that have the built-in browser enabled.
  Future<List<Identity>> getEnableBrowserIdentityList() async {
    return DBProvider.database.identitys
        .filter()
        .enableBrowserEqualTo(true)
        .findAll();
  }

  /// Looks up an identity by its secp256k1 (Nostr) public key.
  Future<Identity?> getIdentityByNostrPubkey(String pubkey) async {
    return DBProvider.database.identitys
        .filter()
        .secp256k1PKHexEqualTo(pubkey)
        .findFirst();
  }

  /// Looks up an identity by its curve25519 (Signal) secret key hex.
  ///
  /// Note: the Isar field name is `curve25519SkHex` despite searching by pubkey
  /// — this is a naming inconsistency in the original schema.
  Future<Identity?> getIdentityBySignalPubkey(String pubkey) async {
    return DBProvider.database.identitys
        .filter()
        .curve25519SkHexEqualTo(pubkey)
        .findFirst();
  }

  // In-memory cache of pubkey → private key to avoid repeated secure-storage reads.
  Map<String, String?> prikeys = {};

  /// Returns the secp256k1 private key for [pubkey], using an in-memory cache.
  ///
  /// Searches the loaded identities first, then falls back to [Mykey] records.
  /// Throws 'ExceptionIsFromSigner' if the identity uses an external signer.
  Future<String?> getPrikeyByPubkey(String pubkey) async {
    if (prikeys[pubkey] != null) return prikeys[pubkey];

    final identities = Get.find<HomeController>().allIdentities.values
        .where((element) => element.secp256k1PKHex == pubkey)
        .toList();
    String? prikey;
    if (identities.isNotEmpty) {
      if (identities[0].isFromSigner) {
        throw Exception('ExceptionIsFromSigner');
      }
      prikey = await identities[0].getSecp256k1SKHex();
    } else {
      final mykey = await IdentityService.instance.getMykeyByPubkey(pubkey);
      if (mykey == null) return null;
      prikey = mykey.prikey;
    }
    prikeys[pubkey] = prikey;
    return prikey;
  }

  /// Returns all Signal-protocol receive pubkeys for enabled identities.
  ///
  /// These are the NIP-04 addresses used to receive Signal handshake messages.
  Future<List<String>> getSignalRoomPubkeys() async {
    final skipedIdentityIds = await getDisableChatIdentityIDList();
    // only listen nip04
    final signal = await ContactService.instance.getAllReceiveKeys(
      skipIDs: skipedIdentityIds,
    );
    return signal;
  }

  /// Returns the receive pubkeys for all MLS group rooms owned by enabled identities.
  Future<List<String>> getMlsRoomPubkeys() async {
    final skipedIdentityIds = await getDisableChatIdentityIDList();
    final mlsPubkeys = <String>{};
    // mls room's receive key
    final mlsRooms = await RoomService.instance.getMlsRooms();
    for (final room in mlsRooms) {
      if (skipedIdentityIds.contains(room.identityId)) {
        continue;
      }
      mlsPubkeys.add(room.onetimekey!);
    }
    return mlsPubkeys.toList();
  }

  /// Returns all room receive pubkeys (Signal + MLS) for enabled identities,
  /// excluding muted rooms.
  Future<List<String>> getRoomPubkeysSkipMute() async {
    final skipedIdentityIds = await getDisableChatIdentityIDList();
    // only listen nip04
    final signal = await ContactService.instance.getAllReceiveKeysSkipMute(
      skipIDs: skipedIdentityIds,
    );
    final mlsPubkeys = <String>{};
    // mls room's receive key
    final mlsRooms = await RoomService.instance.getMlsRoomsSkipMute();
    for (final room in mlsRooms) {
      if (skipedIdentityIds.contains(room.identityId)) {
        continue;
      }
      mlsPubkeys.add(room.onetimekey!);
    }
    return <String>{...signal, ...mlsPubkeys}.toList();
  }

  /// Fetches the latest NIP-01 metadata event for [identity] from connected relays
  /// and updates the local profile fields (name, avatar, about).
  ///
  /// Returns the updated [Identity], or null if no event was found or the local
  /// version is already up to date.
  Future<Identity?> syncProfileFromRelay(Identity identity) async {
    final list = await NostrAPI.instance.fetchMetadata([
      identity.secp256k1PKHex,
    ]);
    if (list.isEmpty) {
      logger.d(
        'No metadata event found from relay for ${identity.secp256k1PKHex}',
      );
      return null;
    }
    final res = list.last;
    final metadata = jsonDecode(res.content) as Map<String, dynamic>;
    logger.i('Sync profile from relay: $metadata');

    if (identity.versionFromRelay >= res.createdAt) {
      logger.d('Identity version is up to date, skip sync');
      return identity;
    }
    final nameFromRelay =
        (metadata['displayName'] ?? metadata['name']) as String?;
    final avatarFromRelay =
        (metadata['picture'] ?? metadata['avatar']) as String?;

    identity.nameFromRelay = nameFromRelay;
    if (avatarFromRelay != null && avatarFromRelay.isNotEmpty) {
      if (avatarFromRelay.startsWith('http') ||
          avatarFromRelay.startsWith('https')) {
        identity.avatarFromRelay = avatarFromRelay;
        final localPath = await FileService.instance.downloadAndSaveAvatar(
          avatarFromRelay,
          identity.secp256k1PKHex,
        );
        if (localPath != null) {
          identity.avatarFromRelayLocalPath = localPath;
        }
      }
    }
    final description =
        (metadata['description'] ?? metadata['about'] ?? metadata['bio'])
            as String?;

    identity
      ..aboutFromRelay = description
      ..metadataFromRelay = res.content
      ..fetchFromRelayAt = DateTime.now()
      ..versionFromRelay = res.createdAt;

    await updateIdentity(identity);
    await Get.find<HomeController>().loadIdentity();
    Utils.removeAvatarCacheByPubkey(identity.secp256k1PKHex);
    Get.find<HomeController>().tabBodyDatas.refresh();
    return identity;
  }
}
