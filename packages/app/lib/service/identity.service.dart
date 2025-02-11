import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/models/nostr_event_status.dart';
import 'package:app/service/contact.service.dart';
import 'package:app/service/mls_group.service.dart';
import 'package:app/service/relay.service.dart';
import 'package:app/service/secure_storage.dart';

import 'package:app/service/chatx.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:app/utils.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:keychat_ecash/ecash_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;

import '../models/db_provider.dart';
import 'file_util.dart';

class IdentityService {
  static IdentityService? _instance;
  static IdentityService get instance => _instance ??= IdentityService._();
  // Avoid self instance
  IdentityService._();
  static final DBProvider dbProvider = DBProvider.instance;

  Future<bool> checkPrikeyExist(String prikey) async {
    var res = await DBProvider.database.mykeys
        .filter()
        .prikeyEqualTo(prikey)
        .findFirst();
    return res != null;
  }

  Future<int> count() async {
    Isar database = DBProvider.database;
    return await database.identitys.where().count();
  }

  Future createOneTimeKey(int identityId) async {
    Isar database = DBProvider.database;
    var keychain = await rust_nostr.generateSecp256K1();
    var ontTimeKey = Mykey(
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
    Isar database = DBProvider.database;
    HomeController homeController = Get.find<HomeController>();
    Identity iden = Identity(
        name: name, secp256k1PKHex: account.pubkey, npub: account.pubkeyBech32)
      ..curve25519PkHex = account.curve25519PkHex!
      ..index = index;
    await database.writeTxn(() async {
      await database.identitys.put(iden);

      // store the prikey in secure storage
      if (account.mnemonic != null) {
        await SecureStorage.instance
            .writePhraseWordsWhenNotExist(account.mnemonic!);
      }
      await SecureStorage.instance
          .writePrikey(iden.secp256k1PKHex, account.prikey);
      await SecureStorage.instance
          .writePrikey(iden.curve25519PkHex!, account.curve25519SkHex!);
    });
    await homeController.loadRoomList(init: true);
    try {
      Get.find<WebsocketService>().listenPubkey([account.pubkey]);
      Get.find<WebsocketService>().listenPubkeyNip17([account.pubkey]);
    } catch (e) {}

    if (isFirstAccount) {
      try {
        Get.find<EcashController>().initIdentity(iden);
        // create ai identity
        await homeController.createAIIdentity([iden], KeychatGlobal.bot);
        homeController.loadAppRemoteConfig();
        NotifyService.requestPremissionAndInit().then((c) {
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
    MlsGroupService.instance.initIdentities([iden]);
    return iden;
  }

  Future<Identity> createIdentityByPrikey(
      {required String name,
      required String hexPubkey,
      required String prikey}) async {
    Isar database = DBProvider.database;
    String npub = rust_nostr.getBech32PubkeyByHex(hex: hexPubkey);
    Identity iden = Identity(name: name, secp256k1PKHex: hexPubkey, npub: npub)
      ..index = -1;
    await database.writeTxn(() async {
      await database.identitys.put(iden);
      await SecureStorage.instance.writePrikey(hexPubkey, prikey);
    });

    await Get.find<HomeController>().loadRoomList(init: true);
    Get.find<WebsocketService>().listenPubkey([hexPubkey]);
    Get.find<WebsocketService>().listenPubkeyNip17([hexPubkey]);
    NotifyService.addPubkeys([hexPubkey]);
    MlsGroupService.instance.initIdentities([iden]);
    return iden;
  }

  Future<Identity> createIdentityByAmberPubkey(
      {required String name, required String pubkey}) async {
    Isar database = DBProvider.database;
    String hexPubkey = rust_nostr.getHexPubkeyByBech32(bech32: pubkey);
    String npub = rust_nostr.getBech32PubkeyByHex(hex: hexPubkey);
    Identity iden = Identity(name: name, secp256k1PKHex: hexPubkey, npub: npub)
      ..index = -1
      ..isFromSigner = true;
    await database.writeTxn(() async {
      await database.identitys.put(iden);
    });

    await Get.find<HomeController>().loadRoomList(init: true);
    Get.find<WebsocketService>().listenPubkey([hexPubkey]);
    Get.find<WebsocketService>().listenPubkeyNip17([hexPubkey]);
    NotifyService.addPubkeys([hexPubkey]);
    MlsGroupService.instance.initIdentities([iden]);
    return iden;
  }

  Future delete(Identity identity) async {
    Isar database = DBProvider.database;

    int id = identity.id;
    String secp256k1PKHex = identity.secp256k1PKHex;
    String? curve25519PkHex = identity.curve25519PkHex;
    await database.writeTxn(() async {
      await database.identitys.delete(id);
      await database.mykeys.filter().identityIdEqualTo(id).deleteAll();
      await database.contactReceiveKeys
          .filter()
          .identityIdEqualTo(id)
          .deleteAll();

      List<Room> rooms =
          await database.rooms.filter().identityIdEqualTo(id).findAll();

      for (var element in rooms) {
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
        String? signalIdPubkey = element.signalIdPubkey;
        KeychatIdentityKeyPair keyPair;
        var chatxService = Get.find<ChatxService>();

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
      await deleteAllByIdentity(id);
      await SecureStorage.instance.deletePrikey(secp256k1PKHex);
      if (curve25519PkHex != null) {
        await SecureStorage.instance.deletePrikey(curve25519PkHex);
      }
    });
    Get.find<HomeController>().loadRoomList(init: true);
    NotifyService.syncPubkeysToServer();
  }

  Future deleteMykey(List<int> ids) async {
    Isar database = DBProvider.database;

    return await database.writeTxn(() async {
      await database.mykeys.deleteAll(ids);
    });
  }

  Future<Identity?> getIdentityById(int id) async {
    Isar database = DBProvider.database;

    Identity? identity =
        await database.identitys.filter().idEqualTo(id).findFirst();
    if (identity == null) throw Exception('identity is null');
    return identity;
  }

  Future<Mykey?> getMykeyByPubkey(String pubkey) async {
    return await DBProvider.database.mykeys
        .filter()
        .pubkeyEqualTo(pubkey)
        .findFirst();
  }

  Future<List<String>> getListenPubkeys({bool skipMute = false}) async {
    Set<String> pubkeys = {};

    List<Identity> list =
        Get.find<HomeController>().allIdentities.values.toList();
    List<int> skipedIdentityIDs = [];
    for (var identity in list) {
      if (!identity.enableChat) {
        skipedIdentityIDs.add(identity.id);
        continue;
      }
      pubkeys.add(identity.secp256k1PKHex);
    }
    if (pubkeys.isEmpty) return [];

    // sharing group 's mykey
    List<Room> rooms = await RoomService.instance.getGroupsSharedKey();
    for (var room in rooms) {
      if (skipedIdentityIDs.contains(room.identityId)) {
        continue;
      }
      if (skipMute && room.isMute) {
        continue;
      }
      String? pubkey = room.mykey.value?.pubkey;
      if (pubkey != null) {
        pubkeys.add(pubkey);
      }
    }
    // my receive onetime key
    List<Mykey> oneTimeKeys = await getOneTimeKeys();
    pubkeys.addAll(oneTimeKeys.map((e) => e.pubkey));

    return pubkeys.toList();
  }

  Future<List<Mykey>> getMykeyList() async {
    Isar database = DBProvider.database;
    return await database.mykeys.where().findAll();
  }

  Future<List<Mykey>> list() async {
    Isar database = DBProvider.database;

    return database.mykeys.where().sortByCreatedAt().findAll();
  }

  Future<List<Identity>> listIdentity() async {
    return await DBProvider.database.identitys.where().findAll();
  }

  Future updateMykey(Mykey my) async {
    Isar database = DBProvider.database;

    await database.writeTxn(() async {
      return await database.mykeys.put(my);
    });
  }

  Future updateIdentity(Identity identity) async {
    Isar database = DBProvider.database;

    await database.writeTxn(() async {
      return await database.identitys.put(identity);
    });
  }

  Future<Mykey?> isFromOnetimeKey(String toAddress) async {
    var res = await DBProvider.database.mykeys
        .filter()
        .isOneTimeEqualTo(true)
        .pubkeyEqualTo(toAddress)
        .findAll();
    return res.isNotEmpty ? res[0] : null;
  }

  Future<List<Mykey>> getOneTimeKeys() async {
    return await DBProvider.database.mykeys
        .filter()
        .isOneTimeEqualTo(true)
        .sortByCreatedAt()
        .findAll();
  }

  Future<List<Mykey>> getOneTimeKeyByIdentity(int identityId) async {
    return await DBProvider.database.mykeys
        .filter()
        .identityIdEqualTo(identityId)
        .isOneTimeEqualTo(true)
        .oneTimeUsedEqualTo(false)
        .sortByCreatedAt()
        .findAll();
  }

  Future deleteExpiredOneTimeKeys() async {
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
    return await DBProvider.database.identitys.where().findAll();
  }

  Future<List<Identity>> getEnableChatIdentityList() async {
    return await DBProvider.database.identitys
        .filter()
        .enableChatEqualTo(true)
        .findAll();
  }

  Future<List<int>> getDisableChatIdentityIDList() async {
    var list = await DBProvider.database.identitys
        .filter()
        .enableChatEqualTo(false)
        .findAll();
    return list.map((e) => e.id).toList();
  }

  Future<List<Identity>> getEnableBrowserIdentityList() async {
    return await DBProvider.database.identitys
        .filter()
        .enableBrowserEqualTo(true)
        .findAll();
  }

  Future<Identity?> getIdentityByNostrPubkey(String pubkey) async {
    return await DBProvider.database.identitys
        .filter()
        .secp256k1PKHexEqualTo(pubkey)
        .findFirst();
  }

  Future<Identity?> getIdentityBySignalPubkey(String pubkey) async {
    return await DBProvider.database.identitys
        .filter()
        .curve25519SkHexEqualTo(pubkey)
        .findFirst();
  }

  Map prikeys = {};
  Future<String?> getPrikeyByPubkey(String pubkey) async {
    if (prikeys[pubkey] != null) return prikeys[pubkey];

    List<Identity> identities = Get.find<HomeController>()
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
      Mykey? mykey = await IdentityService.instance.getMykeyByPubkey(pubkey);
      if (mykey == null) return null;
      prikey = mykey.prikey;
    }
    prikeys[pubkey] = prikey;
    return prikey;
  }

  Future<List<String>> getRoomPubkeys() async {
    List<int> skipedIdentityIds = await getDisableChatIdentityIDList();
    // only listen nip04
    List<String> signal = await ContactService.instance
        .getAllReceiveKeys(skipIDs: skipedIdentityIds);
    Set<String> mlsPubkeys = {};
    // mls room's receive key
    List<Room> mlsRooms = await RoomService.instance.getMlsRooms();
    for (Room room in mlsRooms) {
      if (skipedIdentityIds.contains(room.identityId)) {
        continue;
      }
      mlsPubkeys.add(room.onetimekey!);
    }
    return <String>{...signal, ...mlsPubkeys}.toList();
  }

  Future<List<String>> getRoomPubkeysSkipMute() async {
    List<int> skipedIdentityIds = await getDisableChatIdentityIDList();
    // only listen nip04
    List<String> signal = await ContactService.instance
        .getAllReceiveKeysSkipMute(skipIDs: skipedIdentityIds);
    Set<String> mlsPubkeys = {};
    // mls room's receive key
    List<Room> mlsRooms = await RoomService.instance.getMlsRoomsSkipMute();
    for (Room room in mlsRooms) {
      if (skipedIdentityIds.contains(room.identityId)) {
        continue;
      }
      mlsPubkeys.add(room.onetimekey!);
    }
    return <String>{...signal, ...mlsPubkeys}.toList();
  }
}
