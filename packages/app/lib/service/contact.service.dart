import 'package:keychat/app.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/service/file.service.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;
import 'package:mutex/mutex.dart';

/// Service for managing contacts and their Signal receive-key chains.
///
/// Contacts are Nostr public keys that have been added as friends.
/// Each contact may have a chain of one-time receive keys used for
/// Signal ratchet sessions (stored in [ContactReceiveKey]).
class ContactService {
  // Avoid self instance
  ContactService._();
  static ContactService? _instance;
  static ContactService get instance => _instance ??= ContactService._();

  // Maps receive-key pubkey → room ID for fast reverse lookup.
  static Map<String, int> receiveKeyRooms = {};
  final Mutex myReceiveKeyMutex = Mutex();

  /// Adds [address] as the next receive key for [room]'s contact.
  ///
  /// Uses a mutex to prevent concurrent modifications to the key chain.
  /// Returns an empty list if the key is already the latest; otherwise returns
  /// a single-element list with the newly registered [address].
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

  /// Creates and persists a new [Contact] record.
  ///
  /// [pubkey] may be bech32 (npub) or hex; it is normalised to hex before storage.
  /// [autoCreateFromGroup] marks contacts implicitly created when joining a group,
  /// which are not shown as "friends" until explicitly confirmed.
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

  /// Deletes a contact record from the database.
  Future<void> deleteContact(Contact contact) async {
    final database = DBProvider.database;
    await database.writeTxn(() async {
      await database.contacts.filter().idEqualTo(contact.id).deleteFirst();
    });
  }

  /// Deletes the contact record for [pubkey] under [identity].
  /// No-op if no matching contact exists.
  Future<void> deleteContactByPubkey(String pubkey, int identity) async {
    final database = DBProvider.database;
    final contact = await getContact(identity, pubkey);
    if (contact == null) return;
    await database.writeTxn(() async {
      await database.contacts.filter().idEqualTo(contact.id).deleteFirst();
    });
  }

  /// Deletes the receive-key chain for [contact] and unsubscribes those pubkeys
  /// from the WebSocket service and notification server.
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

  /// Removes [pubkey] from the receive-key chain for the contact identified by
  /// [identityId] + [toMainPubkey], pruning old keys while retaining the most recent
  /// [KeychatGlobal.remainReceiveKeyPerRoom] entries.
  ///
  /// Keys that drop off the active list are moved to the `removeReceiveKeys` staging
  /// area so they can be unsubscribed from the relay in a subsequent batch call.
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

  /// Returns all active receive keys across all contacts.
  ///
  /// Identities in [skipIDs] are excluded.  Also populates [receiveKeyRooms]
  /// cache for fast room lookups by receive key.
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

  /// Returns active receive keys for non-muted contacts, excluding [skipIDs].
  ///
  /// Used when building the notification server's subscription list so that
  /// muted rooms do not wake the device.
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

  /// Returns all keys that are staged for removal (previously rotated out).
  ///
  /// These should be passed to the notification server's remove endpoint so it
  /// stops delivering wake-up pushes for those addresses.
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

  /// Returns the contact for [pubkey] under [identityId], or null if not found.
  Future<Contact?> getContact(int identityId, String pubkey) async {
    return DBProvider.database.contacts
        .filter()
        .pubkeyEqualTo(pubkey)
        .identityIdEqualTo(identityId)
        .findFirst();
  }

  /// Returns the contact with the given Isar [id], or null if not found.
  Future<Contact?> getContactById(int id) async {
    return DBProvider.database.contacts.filter().idEqualTo(id).findFirst();
  }

  /// Returns contacts for [identityId] that were explicitly added as friends
  /// (i.e. not auto-created from a group invitation).
  Future<List<Contact>> getFriendContacts(int identityId) async {
    return DBProvider.database.contacts
        .filter()
        .identityIdEqualTo(identityId)
        .autoCreateFromGroupEqualTo(false)
        .findAll();
  }

  /// Returns all contacts for [identityId], including auto-created group contacts.
  Future<List<Contact>> getContactList(int identityId) async {
    return DBProvider.database.contacts
        .filter()
        .identityIdEqualTo(identityId)
        .findAll();
  }

  /// Synchronously searches contacts by [query] substring in the name field.
  ///
  /// Returns results sorted by most-recently created first.
  List<Contact> getContactListSearch(String query, int identityId) {
    final database = DBProvider.database;

    return database.contacts
        .filter()
        .identityIdEqualTo(identityId)
        .nameContains(query)
        .sortByCreatedAtDesc()
        .findAllSync();
  }

  /// Returns all contact records across all identities that match [pubkey].
  Future<List<Contact>> getContacts(String pubkey) async {
    return DBProvider.database.contacts
        .filter()
        .pubkeyEqualTo(pubkey)
        .findAll();
  }

  /// Synchronously returns the active receive-key list for [room]'s contact,
  /// or null if no receive-key record exists.
  List<String>? getMyReceiveKeys(Room room) {
    final crk = DBProvider.database.contactReceiveKeys
        .filter()
        .identityIdEqualTo(room.identityId)
        .pubkeyEqualTo(room.toMainPubkey)
        .findFirstSync();

    return crk?.receiveKeys;
  }

  /// Returns the existing contact for [pubkey], or creates and returns a new one.
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

  /// Returns the receive-key record for [identityId] + [toMainPubkey],
  /// creating an empty one if it does not yet exist.
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

  /// Synchronous variant of [getOrCreateContact] for use in hot paths where
  /// awaiting is not possible. Creates the record with a synchronous write transaction.
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

  /// Clears the `removeReceiveKeys` staging list for all contacts after the keys
  /// have been successfully removed from the notification server.
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

  /// Persists [contact] to the database and returns its Isar ID.
  Future<int> saveContact(Contact contact) async {
    final database = DBProvider.database;
    var id = 0;
    await database.writeTxn(() async {
      id = await database.contacts.put(contact);
    });
    logger.d('Saving contact: $contact');
    return id;
  }

  /// Updates an existing contact's mutable fields, creating the record if absent.
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

  /// Updates the contact name for [room]'s peer, creating the contact if absent.
  ///
  /// No-op if [contactName] is null or already matches the stored name.
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

  /// Sets the mute flag on the receive-key record for [room]'s contact.
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

  /// Synchronously returns the first contact matching [pubkey], or null.
  Contact? getContactSync(String pubkey) {
    return DBProvider.database.contacts
        .filter()
        .pubkeyEqualTo(pubkey)
        .findFirstSync();
  }

  /// Creates or updates a contact from a Keychat QR-code payload.
  ///
  /// [version] guards against replaying an older profile — the update is skipped
  /// if the stored version is already newer.
  /// If [download] is true and [avatarRemoteUrl] is provided, the avatar is
  /// downloaded and decrypted to local storage.
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

  /// Promotes an auto-created (group-origin) contact to an explicit friend,
  /// and optionally downloads the avatar if not yet cached locally.
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

  /// Synchronously returns the first contact matching [pubkey] across all identities.
  Contact? getContactByPubkeySync(String pubkey) {
    return DBProvider.database.contacts
        .filter()
        .pubkeyEqualTo(pubkey)
        .findFirstSync();
  }
}
