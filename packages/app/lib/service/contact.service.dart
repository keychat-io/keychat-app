import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/models.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:mutex/mutex.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import '../models/db_provider.dart';
import '../nostr-core/nostr.dart';

class ContactService {
  static final ContactService _singleton = ContactService._internal();
  final Mutex myReceiveKeyMutex = Mutex();

  factory ContactService() {
    return _singleton;
  }

  ContactService._internal();

  Future<List<String>> addReceiveKey(
      int identityId, String toMainPubkey, String address) async {
    await myReceiveKeyMutex.acquire(); // lock
    try {
      ContactReceiveKey crk =
          await getOrCreateContactReceiveKey(identityId, toMainPubkey);
      List<String> keys = crk.receiveKeys;

      if (keys.isNotEmpty && keys.lastOrNull == address) return [];
      List<String> newReceiveKeys = [...keys, address];
      crk.receiveKeys = newReceiveKeys;
      await _saveReceiveKey(crk);
    } finally {
      myReceiveKeyMutex.release();
    }
    return [address];
  }

  Future<Contact> createContact(
      {required String pubkey,
      required int identityId,
      String? petname,
      String? name,
      String? curve25519PkHex}) async {
    String pubKeyHex = rust_nostr.getHexPubkeyByBech32(bech32: pubkey);
    Contact contact =
        Contact(pubkey: pubKeyHex, npubkey: '', identityId: identityId)
          ..curve25519PkHex = curve25519PkHex;
    if (name != null) {
      contact.name = name.trim();
    }
    if (petname != null) {
      contact.petname = petname;
    }
    contact.createdAt = DateTime.now();
    int id = await saveContact(contact, sync: true);
    NostrAPI().fetchMetadata([pubKeyHex]);
    contact = (await getContactById(id))!;
    return contact;
  }

  Future deleteContact(Contact contact) async {
    Isar database = DBProvider.database;
    await database.writeTxn(() async {
      await database.contacts.filter().idEqualTo(contact.id).deleteFirst();
    });
  }

  Future deleteContactByPubkey(String pubkey, int identity) async {
    Isar database = DBProvider.database;
    Contact? contact = await getContact(identity, pubkey);
    if (contact == null) return;
    await database.writeTxn(() async {
      await database.contacts.filter().idEqualTo(contact.id).deleteFirst();
    });
  }

  Future deleteContactReceiveKeys(Contact contact) async {
    Isar database = DBProvider.database;
    ContactReceiveKey? model = await database.contactReceiveKeys
        .filter()
        .pubkeyEqualTo(contact.pubkey)
        .identityIdEqualTo(contact.identityId)
        .findFirst();
    if (model == null) return;

    await database.writeTxn(() async {
      await database.contactReceiveKeys
          .filter()
          .pubkeyEqualTo(contact.pubkey)
          .identityIdEqualTo(contact.identityId)
          .deleteAll();
    });
    List<String> pubkeys = [...model.receiveKeys, ...model.removeReceiveKeys];
    if (model.receiveKeys.isNotEmpty || model.removeReceiveKeys.isNotEmpty) {
      Get.find<WebsocketService>().removePubkeysFromSubscription(pubkeys);
      NotifyService.removePubkeys(pubkeys);
    }
  }

  Future deleteReceiveKey(
      int identityId, String toMainPubkey, String pubkey) async {
    await myReceiveKeyMutex.acquire();
    try {
      ContactReceiveKey crk =
          await getOrCreateContactReceiveKey(identityId, toMainPubkey);

      if (crk.receiveKeys.isEmpty ||
          crk.receiveKeys.length <= KeychatGlobal.remainReceiveKeyPerRoom) {
        return;
      }
      int index = crk.receiveKeys.indexOf(pubkey);
      if (index + 1 < KeychatGlobal.remainReceiveKeyPerRoom) return;

      List<String> removeReceiveKeys = crk.receiveKeys.sublist(0, index - 1);
      List<String> remain = crk.receiveKeys.sublist(index - 1);
      crk.receiveKeys = remain;
      Get.find<WebsocketService>().removePubkeyFromSubscription(pubkey);

      if (Get.find<HomeController>().debugModel.value == false) {
        crk.removeReceiveKeys = [
          ...crk.removeReceiveKeys,
          ...removeReceiveKeys
        ];
      }

      await _saveReceiveKey(crk);
    } finally {
      myReceiveKeyMutex.release();
    }
  }

  Future<List<String>> getAllReceiveKeys() async {
    Set<String> set = {};
    var list = await DBProvider.database.contactReceiveKeys
        .filter()
        .receiveKeysIsNotEmpty()
        .findAll();
    for (ContactReceiveKey crk in list) {
      set.addAll(crk.receiveKeys);
    }
    return set.toList();
  }

  Future<List<String>> getAllReceiveKeysSkipMute() async {
    Set<String> set = {};
    var list = await DBProvider.database.contactReceiveKeys
        .filter()
        .receiveKeysIsNotEmpty()
        .isMuteEqualTo(false)
        .findAll();
    for (ContactReceiveKey crk in list) {
      set.addAll(crk.receiveKeys);
    }
    return set.toList();
  }

  Future<List<String>> getAllToRemoveKeys() async {
    Set<String> set = {};
    var list = await DBProvider.database.contactReceiveKeys
        .filter()
        .removeReceiveKeysElementIsNotEmpty()
        .findAll();
    for (ContactReceiveKey crk in list) {
      set.addAll(crk.removeReceiveKeys);
    }
    return set.toList();
  }

  Future<Contact?> getContact(int identityId, String pubkey) async {
    return await DBProvider.database.contacts
        .filter()
        .pubkeyEqualTo(pubkey)
        .identityIdEqualTo(identityId)
        .findFirst();
  }

  Future<Contact?> getContactById(int id) async {
    return await DBProvider.database.contacts
        .filter()
        .idEqualTo(id)
        .findFirst();
  }

  Future<List<Contact>> getContactList(int identityId) async {
    Isar database = DBProvider.database;

    return await database.contacts
        .filter()
        .identityIdEqualTo(identityId)
        .findAll();
  }

  Future<List<Contact>> getListExcludeSelf(int identityId) async {
    Isar database = DBProvider.database;

    return await database.contacts
        .filter()
        .identityIdEqualTo(identityId)
        .not()
        .nameEqualTo(KeychatGlobal.selfName)
        .findAll();
  }

  List<Contact> getContactListSearch(String query, int identityId) {
    Isar database = DBProvider.database;

    return database.contacts
        .filter()
        .identityIdEqualTo(identityId)
        .nameContains(query)
        .sortByCreatedAtDesc()
        .findAllSync();
  }

  Future<List<Contact>> getContacts(String pubkey) async {
    return await DBProvider.database.contacts
        .filter()
        .pubkeyEqualTo(pubkey)
        .findAll();
  }

  List<String>? getMyReceiveKeys(Room room) {
    ContactReceiveKey? crk = DBProvider.database.contactReceiveKeys
        .filter()
        .identityIdEqualTo(room.identityId)
        .pubkeyEqualTo(room.toMainPubkey)
        .findFirstSync();

    return crk?.receiveKeys;
  }

  Future<Contact> getOrCreateContact(int identityId, String npubkey,
      {String? name, String? curve25519PkHex}) async {
    String pubkey = rust_nostr.getHexPubkeyByBech32(bech32: npubkey);
    Contact? c = await getContact(identityId, pubkey);

    if (c != null) {
      return c;
    }

    return await createContact(
        identityId: identityId,
        pubkey: pubkey,
        name: name,
        curve25519PkHex: curve25519PkHex);
  }

  Future<ContactReceiveKey> getOrCreateContactReceiveKey(
      int identityId, String toMainPubkey) async {
    ContactReceiveKey? crk = DBProvider.database.contactReceiveKeys
        .filter()
        .identityIdEqualTo(identityId)
        .pubkeyEqualTo(toMainPubkey)
        .findFirstSync();
    if (crk != null) return crk;
    var model = ContactReceiveKey(identityId: identityId, pubkey: toMainPubkey);
    await DBProvider.database.writeTxn(() async {
      int id = await DBProvider.database.contactReceiveKeys.put(model);
      model.id = id;
    });
    return model;
  }

  Contact? getOrCreateContactSync(int identityId, String toMainPubkey) {
    String pubkey = rust_nostr.getHexPubkeyByBech32(bech32: toMainPubkey);
    Contact? c = DBProvider.database.contacts
        .filter()
        .pubkeyEqualTo(pubkey)
        .identityIdEqualTo(identityId)
        .findFirstSync();

    if (c != null) {
      return c;
    }
    String npub = rust_nostr.getBech32PubkeyByHex(hex: toMainPubkey);
    c = Contact(identityId: identityId, npubkey: npub, pubkey: pubkey);
    DBProvider.database.writeTxnSync(() {
      int id = DBProvider.database.contacts.putSync(c!);
      c.id = id;
    });
    return c;
  }

  Future removeAllToRemoveKeys() async {
    List<ContactReceiveKey> list = await DBProvider.database.contactReceiveKeys
        .filter()
        .removeReceiveKeysElementIsNotEmpty()
        .findAll();
    Isar database = DBProvider.database;
    await database.writeTxn(() async {
      for (ContactReceiveKey c in list) {
        c.removeReceiveKeys = [];
        await database.contactReceiveKeys.put(c);
      }
    });
  }

  Future<int> saveContact(Contact contact, {bool sync = true}) async {
    Isar database = DBProvider.database;
    int id = 0;
    await database.writeTxn(() async {
      id = await database.contacts.put(contact);
    });
    return id;
  }

  saveContactFromRelay(
      {required int identityId,
      required String pubkey,
      required Map<String, dynamic> content,
      bool justSave = true}) async {
    Contact contact = await getOrCreateContact(identityId, pubkey);
    contact.name = content['name'];
    contact.about = content['about'];
    contact.picture = content['picture'];
    // contact.isFriend = true;
    contact.updatedAt = DateTime.now();
    saveContact(contact, sync: false);
  }

  Future updateContact(
      {required int identityId,
      required String pubkey,
      String? petname,
      String? name,
      String? metadata}) async {
    String pubKeyHex = rust_nostr.getHexPubkeyByBech32(bech32: pubkey);

    var contact = await getContact(identityId, pubKeyHex);
    if (contact == null) {
      await createContact(
          pubkey: pubkey, identityId: identityId, petname: petname, name: name);
      return;
    }
    if (name != null) {
      contact.name = name;
    }
    if (petname != null) {
      contact.petname = petname;
    }

    if (metadata != null) {
      contact.metadata = metadata;
    }
    await saveContact(contact, sync: false);
  }

  Future updateOrCreateByRoom(Room room, String? contactName) async {
    if (contactName == null) return;
    Contact contact = await getOrCreateContact(
      room.identityId,
      room.toMainPubkey,
    );
    if (contact.name != contactName) {
      contact.name = contactName;
      await ContactService().saveContact(contact);
    }
  }

  Future _saveReceiveKey(ContactReceiveKey crk) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.contactReceiveKeys.put(crk);
    });
  }

  Future updateReceiveKeyIsMute(Room room, bool value) async {
    ContactReceiveKey crk =
        await getOrCreateContactReceiveKey(room.identityId, room.toMainPubkey);
    return DBProvider.database.writeTxn(() async {
      crk.isMute = value;
      await DBProvider.database.contactReceiveKeys.put(crk);
    });
  }
}
