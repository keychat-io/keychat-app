import 'dart:convert';

import 'package:app/constants.dart';
import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/nostr-core/nostr.dart';
import 'package:app/nostr-core/nostr_event.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/file.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/secure_storage.dart';

import 'package:app/service/chatx.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;

class IdentityService {
  // Avoid self instance
  IdentityService._();
  static IdentityService? _instance;
  static IdentityService get instance => _instance ??= IdentityService._();

  Future<bool> checkPrikeyExist(String prikey) async {
    final res = await DBProvider.database.mykeys
        .filter()
        .prikeyEqualTo(prikey)
        .findFirst();
    return res != null;
  }

  Future<int> count() async {
    final database = DBProvider.database;
    return database.identitys.where().count();
  }

  Future<Mykey> createOneTimeKey(int identityId) async {
    final database = DBProvider.database;
    final keychain = await rust_nostr.generateSecp256K1();
    final ontTimeKey = Mykey(
        prikey: keychain.prikey,
        identityId: identityId,
        pubkey: keychain.pubkey)
      ..isOneTime = true
      ..oneTimeUsed = false;
    await database.writeTxn(() async {
      await database.mykeys.put(ontTimeKey);
    });
    return ontTimeKey;
  }

  Future<Identity> createIdentity(
      {required String name,
      required rust_nostr.Secp256k1Account account,
      required int index,
      bool isFirstAccount = false}) async {
    if (account.mnemonic == null) throw Exception('mnemonic is null');
    final database = DBProvider.database;
    final homeController = Get.find<HomeController>();
    final exist = await getIdentityByNostrPubkey(account.pubkey);
    if (exist != null) throw Exception('Identity already exist');
    final iden = Identity(
        name: name, secp256k1PKHex: account.pubkey, npub: account.pubkeyBech32)
      ..curve25519PkHex = account.curve25519PkHex
      ..index = index;
    await database.writeTxn(() async {
      await database.identitys.put(iden);

      // store the prikey in secure storage
      await SecureStorage.instance
          .writePhraseWordsWhenNotExist(account.mnemonic!);

      await SecureStorage.instance.write(iden.secp256k1PKHex, account.prikey);
      await SecureStorage.instance
          .write(iden.curve25519PkHex!, account.curve25519SkHex!);
    });
    await homeController.loadRoomList(init: true);

    Utils.waitRelayOnline().then((_) async {
      Get.find<WebsocketService>()
          .listenPubkey([account.pubkey], kinds: [EventKinds.nip04]);
      Get.find<WebsocketService>().listenPubkeyNip17([account.pubkey]);
      final identity = await getIdentityByNostrPubkey(iden.secp256k1PKHex);
      if (identity != null) {
        syncProfileFromRelay(iden);
      }
    });

    if (isFirstAccount) {
      try {
        Get.find<EcashController>().initIdentity(iden);

        // create ai identity
        await homeController.createAIIdentity([iden], KeychatGlobal.bot);
        homeController.loadAppRemoteConfig();

        // init notifycation
        NotifyService.init().then((c) {
          NotifyService.addPubkeys([account.pubkey]);
        }).catchError((e, s) {
          logger.e('initNotifycation error', error: e, stackTrace: s);
        });
        RelayService.instance.initRelay();
      } catch (e, s) {
        logger.e(e.toString(), error: e, stackTrace: s);
      }
    } else {
      NotifyService.addPubkeys([account.pubkey]);
    }
    MlsGroupService.instance.initIdentities([iden]).then((_) {
      MlsGroupService.instance.uploadKeyPackages(identities: [iden]);
    });
    return iden;
  }

  Future<Identity> createIdentityByPrikey(
      {required String name,
      required String hexPubkey,
      required String prikey}) async {
    final database = DBProvider.database;
    final npub = rust_nostr.getBech32PubkeyByHex(hex: hexPubkey);
    final exist = await getIdentityByNostrPubkey(hexPubkey);
    if (exist != null) throw Exception('Identity already exist');
    final iden = Identity(name: name, secp256k1PKHex: hexPubkey, npub: npub)
      ..index = -1;
    await database.writeTxn(() async {
      await database.identitys.put(iden);
      await SecureStorage.instance.write(hexPubkey, prikey);
    });

    await Get.find<HomeController>().loadRoomList(init: true);
    Utils.waitRelayOnline().then((_) async {
      Get.find<WebsocketService>()
          .listenPubkey([hexPubkey], kinds: [EventKinds.nip04]);
      Get.find<WebsocketService>().listenPubkeyNip17([hexPubkey]);
      final identity = await getIdentityByNostrPubkey(hexPubkey);
      if (identity != null) {
        syncProfileFromRelay(iden);
      }
    });

    NotifyService.addPubkeys([hexPubkey]);
    MlsGroupService.instance.initIdentities([iden]).then((_) {
      MlsGroupService.instance.uploadKeyPackages(identities: [iden]);
    });
    return iden;
  }

  Future<Identity> createIdentityByAmberPubkey(
      {required String name, required String pubkey}) async {
    final database = DBProvider.database;
    final hexPubkey = rust_nostr.getHexPubkeyByBech32(bech32: pubkey);
    final exist = await getIdentityByNostrPubkey(hexPubkey);
    if (exist != null) throw Exception('Identity already exist');
    final npub = rust_nostr.getBech32PubkeyByHex(hex: hexPubkey);
    final iden = Identity(name: name, secp256k1PKHex: hexPubkey, npub: npub)
      ..index = -1
      ..isFromSigner = true;
    await database.writeTxn(() async {
      await database.identitys.put(iden);
    });

    await Get.find<HomeController>().loadRoomList(init: true);

    Utils.waitRelayOnline().then((_) async {
      Get.find<WebsocketService>()
          .listenPubkey([hexPubkey], kinds: [EventKinds.nip04]);
      Get.find<WebsocketService>().listenPubkeyNip17([hexPubkey]);
      final identity = await getIdentityByNostrPubkey(hexPubkey);
      if (identity != null) {
        syncProfileFromRelay(iden);
      }
    });

    NotifyService.addPubkeys([hexPubkey]);
    MlsGroupService.instance.initIdentities([iden]).then((_) {
      MlsGroupService.instance.uploadKeyPackages(identities: [iden]);
    });
    return iden;
  }

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

      final rooms =
          await database.rooms.filter().identityIdEqualTo(id).findAll();

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
        final signalIdPubkey = element.signalIdPubkey;
        late rust_signal.KeychatIdentityKeyPair keyPair;
        final chatxService = Get.find<ChatxService>();

        if (signalIdPubkey != null) {
          keyPair =
              await chatxService.setupSignalStoreBySignalId(signalIdPubkey);
        } else {
          keyPair = await chatxService.getKeyPairByIdentity(identity);
        }
        // delete signal session by remote address
        await chatxService.deleteSignalSessionKPA(element);
        // delete signal session by identity id
        await rust_signal.deleteSessionByDeviceId(
            keyPair: keyPair, deviceId: id);
      }
      await database.contacts.filter().identityIdEqualTo(id).deleteAll();
      await FileService.instance.deleteAllByIdentity(id);
      await SecureStorage.instance.deletePrikey(secp256k1PKHex);
      if (curve25519PkHex != null) {
        await SecureStorage.instance.deletePrikey(curve25519PkHex);
      }
    });
    Get.find<HomeController>().loadRoomList(init: true);
    NotifyService.syncPubkeysToServer();
  }

  Future<void> deleteMykey(List<int> ids) async {
    final database = DBProvider.database;

    return database.writeTxn(() async {
      await database.mykeys.deleteAll(ids);
    });
  }

  Future<Identity?> getIdentityById(int id) async {
    final database = DBProvider.database;

    final identity =
        await database.identitys.filter().idEqualTo(id).findFirst();
    if (identity == null) throw Exception('identity is null');
    return identity;
  }

  Future<Mykey?> getMykeyByPubkey(String pubkey) async {
    return DBProvider.database.mykeys
        .filter()
        .pubkeyEqualTo(pubkey)
        .findFirst();
  }

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

    // sharing group 's mykey
    final rooms = await RoomService.instance.getGroupsSharedKey();
    for (final room in rooms) {
      if (skipedIdentityIDs.contains(room.identityId)) {
        continue;
      }
      if (skipMute && room.isMute) {
        continue;
      }
      final pubkey = room.mykey.value?.pubkey;
      if (pubkey != null) {
        pubkeys.add(pubkey);
      }
    }
    // my receive onetime key
    final oneTimeKeys = await getOneTimeKeys();
    pubkeys.addAll(oneTimeKeys.map((e) => e.pubkey));

    return pubkeys.toList();
  }

  Future<List<Mykey>> getMykeyList() async {
    final database = DBProvider.database;
    return database.mykeys.where().findAll();
  }

  Future<List<Mykey>> list() async {
    final database = DBProvider.database;

    return database.mykeys.where().sortByCreatedAt().findAll();
  }

  Future<List<Identity>> listIdentity() async {
    return DBProvider.database.identitys.where().findAll();
  }

  Future<void> updateMykey(Mykey my) async {
    final database = DBProvider.database;

    await database.writeTxn(() async {
      return database.mykeys.put(my);
    });
  }

  Future<void> updateIdentity(Identity identity) async {
    final database = DBProvider.database;
    await database.writeTxn(() async {
      await database.identitys.put(identity);
    });
  }

  Future<Mykey?> isFromOnetimeKey(String toAddress) async {
    final res = await DBProvider.database.mykeys
        .filter()
        .isOneTimeEqualTo(true)
        .pubkeyEqualTo(toAddress)
        .findAll();
    return res.isNotEmpty ? res[0] : null;
  }

  Future<List<Mykey>> getOneTimeKeys() async {
    return DBProvider.database.mykeys
        .filter()
        .isOneTimeEqualTo(true)
        .sortByCreatedAt()
        .findAll();
  }

  Future<List<Mykey>> getOneTimeKeyByIdentity(int identityId) async {
    return DBProvider.database.mykeys
        .filter()
        .identityIdEqualTo(identityId)
        .isOneTimeEqualTo(true)
        .oneTimeUsedEqualTo(false)
        .sortByCreatedAt()
        .findAll();
  }

  Future<void> deleteExpiredOneTimeKeys() async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.mykeys
          .filter()
          .isOneTimeEqualTo(true)
          .oneTimeUsedEqualTo(true)
          .updatedAtLessThan(DateTime.now().subtract(
              const Duration(hours: KeychatGlobal.oneTimePubkeysLifetime)))
          .deleteAll();
    });
  }

  Future<List<Identity>> getIdentityList() async {
    return DBProvider.database.identitys.where().findAll();
  }

  Future<List<Identity>> getEnableChatIdentityList() async {
    return DBProvider.database.identitys
        .filter()
        .enableChatEqualTo(true)
        .findAll();
  }

  Future<List<int>> getDisableChatIdentityIDList() async {
    final list = await DBProvider.database.identitys
        .filter()
        .enableChatEqualTo(false)
        .findAll();
    return list.map((e) => e.id).toList();
  }

  Future<List<Identity>> getEnableBrowserIdentityList() async {
    return DBProvider.database.identitys
        .filter()
        .enableBrowserEqualTo(true)
        .findAll();
  }

  Future<Identity?> getIdentityByNostrPubkey(String pubkey) async {
    return DBProvider.database.identitys
        .filter()
        .secp256k1PKHexEqualTo(pubkey)
        .findFirst();
  }

  Future<Identity?> getIdentityBySignalPubkey(String pubkey) async {
    return DBProvider.database.identitys
        .filter()
        .curve25519SkHexEqualTo(pubkey)
        .findFirst();
  }

  Map prikeys = {};
  Future<String?> getPrikeyByPubkey(String pubkey) async {
    if (prikeys[pubkey] != null)
      return Future.value(prikeys[pubkey] as String?);

    final identities = Get.find<HomeController>()
        .allIdentities
        .values
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

  Future<List<String>> getSignalRoomPubkeys() async {
    final skipedIdentityIds = await getDisableChatIdentityIDList();
    // only listen nip04
    final signal = await ContactService.instance
        .getAllReceiveKeys(skipIDs: skipedIdentityIds);
    return signal;
  }

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

  Future<List<String>> getRoomPubkeysSkipMute() async {
    final skipedIdentityIds = await getDisableChatIdentityIDList();
    // only listen nip04
    final signal = await ContactService.instance
        .getAllReceiveKeysSkipMute(skipIDs: skipedIdentityIds);
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

  Future<Identity?> syncProfileFromRelay(Identity identity) async {
    final list =
        await NostrAPI.instance.fetchMetadata([identity.secp256k1PKHex]);
    if (list.isEmpty) {
      logger.d(
          'No metadata event found from relay for ${identity.secp256k1PKHex}');
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
        final localPath = await FileService.instance
            .downloadAndSaveAvatar(avatarFromRelay, identity.secp256k1PKHex);
        if (localPath != null) {
          identity.avatarFromRelayLocalPath = localPath;
        }
      }
    }
    final description = (metadata['description'] ??
        metadata['about'] ??
        metadata['bio']) as String?;

    identity
      ..aboutFromRelay = description
      ..metadataFromRelay = res.content
      ..fetchFromRelayAt = DateTime.now()
      ..versionFromRelay = res.createdAt;

    await updateIdentity(identity);
    await Get.find<HomeController>().loadIdentity();
    Get.find<HomeController>().tabBodyDatas.refresh();
    return identity;
  }
}
