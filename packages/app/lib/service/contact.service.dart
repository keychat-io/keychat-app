import 'package:keychat/app.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:mutex/mutex.dart';

class ContactService {
  // Avoid self instance
  ContactService._();
  static ContactService? _instance;
  static ContactService get instance => _instance ??= ContactService._();
  static Map<String, int> receiveKeyRooms = {};
  final Mutex myReceiveKeyMutex = Mutex();

  Future<List<String>> addReceiveKey(Room room, String address) async {
    await myReceiveKeyMutex.acquire(); // lock
    try {
      final crk = await getOrCreateContactReceiveKey(
        room.identityId,
        room.toMainPubkey,
        room.id,
      );
      final keys = crk.receiveKeys;
      receiveKeyRooms[address] = room.id;
      if (keys.isNotEmpty && keys.lastOrNull == address) return [];
      final newReceiveKeys = <String>[...keys, address];
      crk
        ..receiveKeys = newReceiveKeys
        ..roomId = room.id;
      await _saveReceiveKey(crk);
    } finally {
      myReceiveKeyMutex.release();
    }
    return [address];
  }

  Future<Contact> createContact({
    required String pubkey,
    required int identityId,
    String? petname,
    String? name,
    String? curve25519PkHex,
    bool autoCreateFromGroup = false,
  }) async {
    final pubKeyHex = rust_nostr.getHexPubkeyByBech32(bech32: pubkey);
    final contact = Contact(pubkey: pubKeyHex, identityId: identityId)
      ..curve25519PkHex = curve25519PkHex
      ..autoCreateFromGroup = autoCreateFromGroup;
    if (name != null) {
      contact.name = name.trim();
    }
    if (petname != null) {
      contact.petname = petname.trim();
    }
    final id = await saveContact(contact);
    contact.id = id;
    return contact;
  }

  Future<void> deleteContact(Contact contact) async {
    final database = DBProvider.database;
    await database.writeTxn(() async {
      await database.contacts.filter().idEqualTo(contact.id).deleteFirst();
    });
  }

  Future<void> deleteContactByPubkey(String pubkey, int identity) async {
    final database = DBProvider.database;
    final contact = await getContact(identity, pubkey);
    if (contact == null) return;
    await database.writeTxn(() async {
      await database.contacts.filter().idEqualTo(contact.id).deleteFirst();
    });
  }

  Future<void> deleteContactReceiveKeys(Contact contact) async {
    final database = DBProvider.database;
    final model = await database.contactReceiveKeys
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
    final pubkeys = <String>[...model.receiveKeys, ...model.removeReceiveKeys];
    if (model.receiveKeys.isNotEmpty || model.removeReceiveKeys.isNotEmpty) {
      Get.find<WebsocketService>().removePubkeysFromSubscription(pubkeys);
      NotifyService.instance.removePubkeys(pubkeys);
    }
  }

  Future<void> deleteReceiveKey(
    int identityId,
    String toMainPubkey,
    String pubkey,
  ) async {
    await myReceiveKeyMutex.acquire();
    try {
      final crk = await getOrCreateContactReceiveKey(identityId, toMainPubkey);

      if (crk.receiveKeys.isEmpty ||
          crk.receiveKeys.length <= KeychatGlobal.remainReceiveKeyPerRoom) {
        return;
      }
      final index = crk.receiveKeys.indexOf(pubkey);
      if (index + 1 < KeychatGlobal.remainReceiveKeyPerRoom) return;

      final removeReceiveKeys = crk.receiveKeys.sublist(0, index - 1);
      final remain = crk.receiveKeys.sublist(index - 1);
      crk.receiveKeys = remain;
      Get.find<WebsocketService>().removePubkeyFromSubscription(pubkey);
      crk.removeReceiveKeys = [...crk.removeReceiveKeys, ...removeReceiveKeys];

      await _saveReceiveKey(crk);
    } finally {
      myReceiveKeyMutex.release();
    }
  }

  Future<List<String>> getAllReceiveKeys({List<int> skipIDs = const []}) async {
    final set = <String>{};
    final list = await DBProvider.database.contactReceiveKeys
        .filter()
        .receiveKeysIsNotEmpty()
        .findAll();
    for (final crk in list) {
      if (skipIDs.contains(crk.identityId)) continue;
      for (final address in crk.receiveKeys) {
        if (crk.roomId > -1) {
          receiveKeyRooms[address] = crk.roomId;
        }
      }
      set.addAll(crk.receiveKeys);
    }
    return set.toList();
  }

  Future<List<String>> getAllReceiveKeysSkipMute({
    required List<int> skipIDs,
  }) async {
    final set = <String>{};
    final list = await DBProvider.database.contactReceiveKeys
        .filter()
        .receiveKeysIsNotEmpty()
        .isMuteEqualTo(false)
        .findAll();
    for (final crk in list) {
      if (skipIDs.contains(crk.identityId)) continue;
      set.addAll(crk.receiveKeys);
    }
    return set.toList();
  }

  Future<List<String>> getAllToRemoveKeys() async {
    final set = <String>{};
    final list = await DBProvider.database.contactReceiveKeys
        .filter()
        .removeReceiveKeysElementIsNotEmpty()
        .findAll();
    for (final crk in list) {
      set.addAll(crk.removeReceiveKeys);
    }
    return set.toList();
  }

  Future<Contact?> getContact(int identityId, String pubkey) async {
    return DBProvider.database.contacts
        .filter()
        .pubkeyEqualTo(pubkey)
        .identityIdEqualTo(identityId)
        .findFirst();
  }

  Future<Contact?> getContactById(int id) async {
    return DBProvider.database.contacts.filter().idEqualTo(id).findFirst();
  }

  Future<List<Contact>> getFriendContacts(int identityId) async {
    return DBProvider.database.contacts
        .filter()
        .identityIdEqualTo(identityId)
        .autoCreateFromGroupEqualTo(false)
        .findAll();
  }

  Future<List<Contact>> getContactList(int identityId) async {
    return DBProvider.database.contacts
        .filter()
        .identityIdEqualTo(identityId)
        .findAll();
  }

  List<Contact> getContactListSearch(String query, int identityId) {
    final database = DBProvider.database;

    return database.contacts
        .filter()
        .identityIdEqualTo(identityId)
        .nameContains(query)
        .sortByCreatedAtDesc()
        .findAllSync();
  }

  Future<List<Contact>> getContacts(String pubkey) async {
    return DBProvider.database.contacts
        .filter()
        .pubkeyEqualTo(pubkey)
        .findAll();
  }

  List<String>? getMyReceiveKeys(Room room) {
    final crk = DBProvider.database.contactReceiveKeys
        .filter()
        .identityIdEqualTo(room.identityId)
        .pubkeyEqualTo(room.toMainPubkey)
        .findFirstSync();

    return crk?.receiveKeys;
  }

  Future<Contact> getOrCreateContact({
    required int identityId,
    required String pubkey,
    String? name,
    String? curve25519PkHex,
    bool autoCreateFromGroup = false,
  }) async {
    final hex = rust_nostr.getHexPubkeyByBech32(bech32: pubkey);
    final c = await getContact(identityId, hex);

    if (c != null) {
      return c;
    }

    return createContact(
      identityId: identityId,
      pubkey: pubkey,
      name: name,
      curve25519PkHex: curve25519PkHex,
      autoCreateFromGroup: autoCreateFromGroup,
    );
  }

  Future<ContactReceiveKey> getOrCreateContactReceiveKey(
    int identityId,
    String toMainPubkey, [
    int? roomId,
  ]) async {
    final crk = DBProvider.database.contactReceiveKeys
        .filter()
        .identityIdEqualTo(identityId)
        .pubkeyEqualTo(toMainPubkey)
        .findFirstSync();
    if (crk != null) return crk;
    final model = ContactReceiveKey(
      identityId: identityId,
      pubkey: toMainPubkey,
    )..roomId = roomId ?? -1;
    await DBProvider.database.writeTxn(() async {
      final id = await DBProvider.database.contactReceiveKeys.put(model);
      model.id = id;
    });
    return model;
  }

  Contact? getOrCreateContactSync(int identityId, String toMainPubkey) {
    final pubkey = rust_nostr.getHexPubkeyByBech32(bech32: toMainPubkey);
    var c = DBProvider.database.contacts
        .filter()
        .pubkeyEqualTo(pubkey)
        .identityIdEqualTo(identityId)
        .findFirstSync();

    if (c != null) {
      return c;
    }
    c = Contact(identityId: identityId, pubkey: pubkey);
    DBProvider.database.writeTxnSync(() {
      final id = DBProvider.database.contacts.putSync(c!);
      c.id = id;
    });
    return c;
  }

  Future<void> removeAllToRemoveKeys() async {
    final list = await DBProvider.database.contactReceiveKeys
        .filter()
        .removeReceiveKeysElementIsNotEmpty()
        .findAll();
    final database = DBProvider.database;
    await database.writeTxn(() async {
      for (final c in list) {
        c.removeReceiveKeys = [];
        await database.contactReceiveKeys.put(c);
      }
    });
  }

  Future<int> saveContact(Contact contact) async {
    final database = DBProvider.database;
    var id = 0;
    await database.writeTxn(() async {
      id = await database.contacts.put(contact);
    });
    logger.d('Saving contact: $contact');
    return id;
  }

  Future<void> updateContact({
    required int identityId,
    required String pubkey,
    String? petname,
    String? name,
    String? metadata,
  }) async {
    final pubKeyHex = rust_nostr.getHexPubkeyByBech32(bech32: pubkey);

    final contact = await getContact(identityId, pubKeyHex);
    if (contact == null) {
      await createContact(
        pubkey: pubkey,
        identityId: identityId,
        petname: petname,
        name: name,
      );
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
    await saveContact(contact);
  }

  Future<void> updateOrCreateByRoom(Room room, String? contactName) async {
    if (contactName == null) return;
    final contact = await getOrCreateContact(
      identityId: room.identityId,
      pubkey: room.toMainPubkey,
    );
    if (contact.name != contactName) {
      contact.name = contactName;
      await ContactService.instance.saveContact(contact);
    }
  }

  Future<void> _saveReceiveKey(ContactReceiveKey crk) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.contactReceiveKeys.put(crk);
    });
  }

  Future<void> updateReceiveKeyIsMute(Room room, bool value) async {
    final crk = await getOrCreateContactReceiveKey(
      room.identityId,
      room.toMainPubkey,
    );
    return DBProvider.database.writeTxn(() async {
      crk.isMute = value;
      await DBProvider.database.contactReceiveKeys.put(crk);
    });
  }

  Contact? getContactSync(String pubkey) {
    return DBProvider.database.contacts
        .filter()
        .pubkeyEqualTo(pubkey)
        .findFirstSync();
  }

  Future<Contact> saveContactFromQrCode({
    required int identityId,
    required String pubkey,
    required int version,
    bool download = true,
    String? name,
    String? avatarRemoteUrl,
    String? lightning,
    String? bio,
  }) async {
    final contact = await ContactService.instance.getOrCreateContact(
      identityId: identityId,
      pubkey: pubkey,
    );

    if (version < contact.version) {
      throw Exception('Older profile version');
    }
    contact.version = version;
    if (name != null && contact.name != name) {
      contact.name = name;
    }
    if (contact.lightning != lightning) {
      contact.lightning = lightning;
    }
    if (contact.about != bio) {
      contact.about = bio != null && bio.length > 200
          ? bio.substring(0, 200)
          : bio;
    }
    if (avatarRemoteUrl != contact.avatarRemoteUrl) {
      try {
        contact.avatarRemoteUrl = avatarRemoteUrl;
        if (avatarRemoteUrl != null && download) {
          final decryptedFile = await FileService.instance
              .downloadAndDecryptToPath(
                url: avatarRemoteUrl,
                outputFolder: Utils.avatarsFolder,
              );
          logger.i(
            'Avatar ${contact.pubkey} downloaded to ${decryptedFile.path}',
          );
          contact.avatarLocalPath = decryptedFile.path.replaceFirst(
            Utils.appFolder.path,
            '',
          );
        }
      } catch (e) {
        logger.e('Failed to download avatar: $e');
      }
    }
    await ContactService.instance.saveContact(contact);
    Utils.removeAvatarCacheByPubkey(contact.pubkey);
    return contact;
  }

  Future<Contact> addContactToFriend({
    required String pubkey,
    required int identityId,
    String? name,
    bool fetchAvatar = false,
  }) async {
    final contact = await ContactService.instance.getOrCreateContact(
      identityId: identityId,
      pubkey: pubkey,
      name: name,
    );
    if (contact.autoCreateFromGroup) {
      contact.autoCreateFromGroup = false;
      await ContactService.instance.saveContact(contact);
    }

    if (fetchAvatar &&
        contact.avatarRemoteUrl != null &&
        (contact.avatarLocalPath == null || contact.avatarLocalPath!.isEmpty)) {
      try {
        final decryptedFile = await FileService.instance
            .downloadAndDecryptToPath(
              url: contact.avatarRemoteUrl!,
              outputFolder: Utils.avatarsFolder,
            );
        logger.i(
          'Avatar ${contact.pubkey} downloaded to ${decryptedFile.path}',
        );
        contact.avatarLocalPath = decryptedFile.path.replaceFirst(
          Utils.appFolder.path,
          '',
        );
        await ContactService.instance.saveContact(contact);
      } catch (e) {
        logger.e('Failed to download avatar: $e');
      }
    }
    return contact;
  }

  Contact? getContactByPubkeySync(String pubkey) {
    return DBProvider.database.contacts
        .filter()
        .pubkeyEqualTo(pubkey)
        .findFirstSync();
  }
}
