import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/service/SecureStorage.dart';

import 'package:app/service/chatx.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/room.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rustNostr;
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rustSignal;

import '../models/db_provider.dart';
import '../nostr-core/nostr.dart';
import 'file_util.dart';

class IdentityService {
  static final IdentityService _singleton = IdentityService._internal();
  static final DBProvider dbProvider = DBProvider();
  static final NostrAPI nostrAPI = NostrAPI();
  factory IdentityService() {
    return _singleton;
  }

  IdentityService._internal();

  Future<bool> checkPrikeyExist(String prikey) async {
    var res = await DBProvider.database.mykeys
        .filter()
        .prikeyEqualTo(prikey)
        .findFirst();
    return res != null;
  }

  Future<bool> checkMnemonicsExist(String mnemonics) async {
    var res = await DBProvider.database.identitys
        .filter()
        .mnemonicEqualTo(mnemonics)
        .findFirst();
    return res != null;
  }

  Future<int> count() async {
    Isar database = DBProvider.database;
    return await database.identitys.where().count();
  }

  Future createOneTimeKey(int identityId) async {
    Isar database = DBProvider.database;
    var keychain = await rustNostr.generateSecp256K1();
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
      required rustNostr.Secp256k1Account account,
      bool isFirstAccount = false}) async {
    if (account.mnemonic == null) throw Exception('mnemonic is null');
    Isar database = DBProvider.database;
    Identity iden = Identity(
        name: name,
        mnemonic: '',
        secp256k1PKHex: account.pubkey,
        secp256k1SKHex: '',
        curve25519PkHex: account.curve25519PkHex!,
        curve25519SkHex: '',
        npub: account.pubkeyBech32);
    await database.writeTxn(() async {
      await database.identitys.put(iden);
      // store the prikey in secure storage
      if (isFirstAccount) {
        await SecureStorage.instance.writePhraseWords(account.mnemonic!);
      }
      await SecureStorage.instance
          .writePrikey(iden.secp256k1PKHex, account.prikey);
      await SecureStorage.instance
          .writePrikey(iden.curve25519PkHex, account.curve25519SkHex!);
    });

    await Get.find<HomeController>().loadRoomList(init: true);
    Get.find<WebsocketService>().listenPubkey([account.pubkey]);
    Get.find<WebsocketService>().listenPubkeyNip17([account.pubkey]);
    NotifyService.addPubkeys([account.pubkey]);
    return iden;
  }

  Future delete(Identity identity) async {
    Isar database = DBProvider.database;

    int id = identity.id;
    String secp256k1PKHex = identity.secp256k1PKHex;
    String curve25519PkHex = identity.curve25519PkHex;
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
        await database.messageBills
            .filter()
            .roomIdEqualTo(element.id)
            .deleteAll();
        // delete signal session by remote address
        final remoteAddress = rustSignal.KeychatProtocolAddress(
            name: element.toMainPubkey, deviceId: element.identityId);
        String? signalIdPubkey = element.signalIdPubkey;
        KeychatIdentityKeyPair keyPair;
        if (signalIdPubkey != null) {
          keyPair = await Get.find<ChatxService>()
              .getKeyPairBySignalIdPubkey(signalIdPubkey);
        } else {
          keyPair =
              await Get.find<ChatxService>().getKeyPairByIdentity(identity);
        }
        await rustSignal.deleteSession(
            keyPair: keyPair, address: remoteAddress);
        // delete signal session by identity id
        await rustSignal.deleteSessionByDeviceId(
            keyPair: keyPair, deviceId: id);
        // delete signal identity
        await rustSignal.deleteIdentity(
            keyPair: keyPair, address: identity.secp256k1PKHex);
      }
      await database.contacts.filter().identityIdEqualTo(id).deleteAll();
      await deleteAllByIdentity(id);
      await SecureStorage.instance.deletePrikey(secp256k1PKHex);
      await SecureStorage.instance.deletePrikey(curve25519PkHex);
    });
    Get.find<HomeController>().loadRoomList(init: true);
    NotifyService.initNofityConfig();
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

    List<Identity> list = Get.find<HomeController>().identities.values.toList();
    pubkeys.addAll(list.map((e) => e.secp256k1PKHex));
    if (pubkeys.isEmpty) return [];

    // sharing group 's mykey
    List<Room> rooms = await RoomService().getGroupsSharedKey();
    for (var room in rooms) {
      if (skipMute && room.isMute) {
        continue;
      }
      String? pubkey = room.mykey.value?.pubkey;
      if (pubkey != null) {
        pubkeys.add(pubkey);
      }
    }
    // onetime key
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

  Future<Identity?> getIdentityByPubkey(String to) async {
    return await DBProvider.database.identitys
        .filter()
        .secp256k1PKHexEqualTo(to)
        .findFirst();
  }

  Map prikeys = {};
  Future<String?> getPrikeyByPubkey(String pubkey) async {
    if (prikeys[pubkey] != null) return prikeys[pubkey];

    List<Identity> identities = Get.find<HomeController>()
        .identities
        .values
        .where((element) => element.secp256k1PKHex == pubkey)
        .toList();
    String? prikey;
    if (identities.isNotEmpty) {
      prikey = await identities[0].getSecp256k1SKHex();
    } else {
      Mykey? mykey = await IdentityService().getMykeyByPubkey(pubkey);
      if (mykey == null) return null;
      prikey = mykey.prikey;
    }
    prikeys[pubkey] = prikey;
    return prikey;
  }
}
