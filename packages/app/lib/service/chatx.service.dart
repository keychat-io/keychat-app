import 'dart:async';
import 'dart:convert' show jsonDecode;
import 'dart:typed_data' show Uint8List;

import 'package:keychat/constants.dart';
import 'package:keychat/controller/home.controller.dart';
import 'package:keychat/global.dart';
import 'package:keychat/models/identity.dart';
import 'package:keychat/models/mykey.dart';
import 'package:keychat/models/room.dart';
import 'package:keychat/models/signal_id.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/mls_group.service.dart';
import 'package:keychat/service/notify.service.dart';
import 'package:keychat/service/relay.service.dart';
import 'package:keychat/service/secure_storage.dart';
import 'package:keychat/service/signalId.service.dart';
import 'package:keychat/service/websocket.service.dart';
import 'package:keychat/utils.dart';
import 'package:convert/convert.dart';
import 'package:get/get.dart';
import 'package:keychat_ecash/unified_wallet/unified_wallet_controller.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;
import 'package:keychat_rust_ffi_plugin/api_signal.dart';
import 'package:keychat_rust_ffi_plugin/index.dart';

/// Cross-protocol helper service for Signal session state management.
///
/// Owns the in-memory KPA (KeychatProtocolAddress) cache and all keypair
/// resolution logic.  Both Signal private-chat and Signal group-chat
/// services depend on this service to initialise and retrieve sessions.
class ChatxService extends GetxService {
  // In-memory cache: "identityId:peerSignalIdentityKey" → KPA for active sessions.
  Map<String, KeychatProtocolAddress> roomKPA = {};
  // Cache of pubkey → KeychatIdentityKeyPair to avoid repeated secure-storage reads.
  final Map<String, KeychatIdentityKeyPair> _keypairs = {};

  /// Ensures the one-time-key pool for [identityId] is at least
  /// [KeychatGlobal.oneTimePubkeysPoolLength] keys deep, generating new keys
  /// if necessary, and subscribes all keys to the WebSocket and notification server.
  Future<List<Mykey>> getOneTimePubkey(int identityId) async {
    // delete expired one time keys
    await IdentityService.instance.deleteExpiredOneTimeKeys();
    final newKeys = await IdentityService.instance.getOneTimeKeyByIdentity(
      identityId,
    );

    final needListen = <String>[];
    for (final key in newKeys) {
      needListen.add(key.pubkey);
    }

    if (needListen.length < KeychatGlobal.oneTimePubkeysPoolLength) {
      final newKeys2 = await _generateOneTimePubkeys(
        identityId,
        KeychatGlobal.oneTimePubkeysPoolLength - needListen.length,
      );
      for (final key in newKeys2) {
        needListen.add(key.pubkey);
      }
      newKeys.addAll(newKeys2);
    }
    if (needListen.isNotEmpty) {
      Get.find<WebsocketService>().listenPubkey(
        needListen,
        kinds: [EventKinds.nip04],
      );
      NotifyService.instance.addPubkeys(needListen);
    }
    return newKeys;
  }

  /// Ensures the SignalId pool for [identityId] is at least
  /// [KeychatGlobal.signalIdsPoolLength] entries deep, generating new IDs if needed.
  Future<List<SignalId>> getSignalIds(int identityId) async {
    // delete expired signal ids
    // await deleteExpiredSignalIds();
    final identity = await IdentityService.instance.getIdentityById(identityId);
    if (identity == null) throw Exception('Identity not found');
    final signalIds = await SignalIdService.instance.getSignalIdByIdentity(
      identityId,
    );
    if (signalIds.length < KeychatGlobal.signalIdsPoolLength) {
      final signalIds2 = await _generateSignalIds(
        identity.id,
        KeychatGlobal.signalIdsPoolLength - signalIds.length,
      );
      signalIds.addAll(signalIds2);
    }
    return signalIds;
  }

  /// Processes Bob's prekey bundle and creates a Signal session for [room] (Alice side).
  ///
  /// Calls [rust_signal.processPrekeyBundleApi] to perform the X3DH key agreement.
  /// Returns true if the session was created (or already exists); false if
  /// [room.peerSignalIdentityKey] is null (no Signal key exchange possible).
  Future<bool> addRoomKPA({
    required Room room,
    required int bobSignedId,
    required Uint8List bobSignedPublic,
    required Uint8List bobSignedSignature,
    required int bobPrekeyId,
    required Uint8List bobPrekeyPublic,
  }) async {
    if (room.peerSignalIdentityKey == null) {
      return false;
    }
    final exist = await getRoomKPA(room);
    if (exist != null) {
      return true;
    }
    final remoteAddress = KeychatProtocolAddress(
      name: room.peerSignalIdentityKey!,
      deviceId: room.identityId,
    );
    // Alice Signal id keypair
    KeychatIdentityKeyPair keyPair;
    if (room.mySignalIdentityKey != null) {
      keyPair = await getKeyPairBySignalIdPubkey(room.mySignalIdentityKey!);
    } else {
      keyPair = await getKeyPairByIdentity(room.getIdentity());
    }
    await rust_signal.processPrekeyBundleApi(
      keyPair: keyPair,
      regId: getRegistrationId(room.peerSignalIdentityKey!),
      deviceId: room.identityId,
      identityKey: KeychatIdentityKey(
        publicKey: U8Array33(
          Uint8List.fromList(hex.decode(room.peerSignalIdentityKey!)),
        ),
      ),
      remoteAddress: remoteAddress,
      bobSignedId: bobSignedId,
      bobSignedPublic: bobSignedPublic,
      bobSigedSig: bobSignedSignature,
      bobPrekeyId: bobPrekeyId,
      bobPrekeyPublic: bobPrekeyPublic,
    );
    return true;
  }

  /// Creates a Signal session using a shared SignalId (KDF group invite flow).
  ///
  /// [sginalKeys] is a JSON string containing signedId, signedPublic,
  /// signedSignature, prekeyId, and prekeyPubkey fields.
  Future<bool> addKPAForSharedSignalId(
    Identity identity,
    String sharedPubkey,
    String sginalKeys,
    int sharedSignalIdentityId,
  ) async {
    final keyPair = await getKeyPairByIdentity(identity);
    final remoteAddress = KeychatProtocolAddress(
      name: sharedPubkey,
      deviceId: sharedSignalIdentityId,
    );

    final keys = jsonDecode(sginalKeys) as Map<String, dynamic>;
    await rust_signal.processPrekeyBundleApi(
      keyPair: keyPair,
      regId: getRegistrationId(sharedPubkey),
      deviceId: sharedSignalIdentityId,
      identityKey: KeychatIdentityKey(
        publicKey: U8Array33(Uint8List.fromList(hex.decode(sharedPubkey))),
      ),
      remoteAddress: remoteAddress,
      bobSignedId: keys['signedId'] as int,
      bobSignedPublic: Uint8List.fromList(
        hex.decode(keys['signedPublic'] as String),
      ),
      bobSigedSig: Uint8List.fromList(
        hex.decode(keys['signedSignature'] as String),
      ),
      bobPrekeyId: keys['prekeyId'] as int,
      bobPrekeyPublic: Uint8List.fromList(
        hex.decode(keys['prekeyPubkey'] as String),
      ),
    );
    return true;
  }

  /// Creates a Signal session using a per-room [SignalId] (KDF group member-add flow).
  Future<bool> addKPAByRoomSignalId(
    SignalId myRoomSignalId,
    String sharedPubkey,
    String sginalKeys,
    int sharedSignalIdentityId,
  ) async {
    final keyPair = getKeyPairBySignalId(myRoomSignalId);
    final remoteAddress = KeychatProtocolAddress(
      name: sharedPubkey,
      deviceId: sharedSignalIdentityId,
    );

    final keys = jsonDecode(sginalKeys) as Map<String, dynamic>;
    await rust_signal.processPrekeyBundleApi(
      keyPair: keyPair,
      regId: getRegistrationId(sharedPubkey),
      deviceId: sharedSignalIdentityId,
      identityKey: KeychatIdentityKey(
        publicKey: U8Array33(Uint8List.fromList(hex.decode(sharedPubkey))),
      ),
      remoteAddress: remoteAddress,
      bobSignedId: keys['signedId'] as int,
      bobSignedPublic: Uint8List.fromList(
        hex.decode(keys['signedPublic'] as String),
      ),
      bobSigedSig: Uint8List.fromList(
        hex.decode(keys['signedSignature'] as String),
      ),
      bobPrekeyId: keys['prekeyId'] as int,
      bobPrekeyPublic: Uint8List.fromList(
        hex.decode(keys['prekeyPubkey'] as String),
      ),
    );
    return true;
  }

  /// Returns the [KeychatProtocolAddress] for an active Signal session in [room],
  /// or null if no session exists.
  ///
  /// Uses the in-memory [roomKPA] cache; falls back to the Rust FFI to check
  /// whether a session record is present in the Signal store.
  Future<KeychatProtocolAddress?> getRoomKPA(Room room) async {
    if (room.peerSignalIdentityKey == null) return null;
    final key = '${room.identityId}:${room.peerSignalIdentityKey}';
    if (roomKPA[key] != null) {
      return roomKPA[key]!;
    }

    final remoteAddress = KeychatProtocolAddress(
      name: room.peerSignalIdentityKey!,
      deviceId: room.identityId,
    );
    final keyPair = await _initRoomSignalStore(room);
    if (keyPair == null) return null;
    final contains = await rust_signal.containsSession(
      keyPair: keyPair,
      address: remoteAddress,
    );

    if (contains) {
      roomKPA[key] = remoteAddress;
      return remoteAddress;
    }
    return null;
  }

  /// Looks up a Signal session for a shared-SignalId room, using the in-memory cache
  /// and falling back to [rust_signal.containsSession] if needed.
  Future<KeychatProtocolAddress?> getSignalSession({
    required int sharedSignalRoomId,
    required String toCurve25519PkHex,
    required KeychatIdentityKeyPair keyPair,
  }) async {
    final key = '$sharedSignalRoomId:$toCurve25519PkHex';
    if (roomKPA[key] != null) return roomKPA[key]!;

    final remoteAddress = KeychatProtocolAddress(
      name: toCurve25519PkHex,
      deviceId: sharedSignalRoomId,
    );

    final contains = await rust_signal.containsSession(
      keyPair: keyPair,
      address: remoteAddress,
    );

    if (!contains) return null;

    roomKPA[key] = remoteAddress;
    return remoteAddress;
  }

  /// Initialises the Signal and MLS databases from the app's [dbPath].
  ///
  /// Must be called once during app startup before any Signal or MLS operations.
  Future<ChatxService> init(String dbPath) async {
    final startTime = DateTime.now();
    await _initSignalDB(dbPath);
    final endTimeSignal = DateTime.now();
    logger.i(
      'Init SignalDB: ${endTimeSignal.difference(startTime).inMilliseconds} ms',
    );

    await MlsGroupService.instance.initDB(dbPath);
    final endTimeMLS = DateTime.now();
    logger.i(
      'Init MLSGroupDB: ${endTimeMLS.difference(endTimeSignal).inMilliseconds} ms',
    );

    return this;
  }

  Future<void> _initSignalDB(String dbpath) async {
    try {
      final signalPath = '$dbpath${KeychatGlobal.signalProcotolDBFile}';
      await rust_signal.initSignalDb(dbPath: signalPath);
      final identities = await IdentityService.instance.getIdentityList();
      for (final identity in identities) {
        if (identity.signalIdentityKey != null) {
          if (identity.signalIdentityKey!.isNotEmpty) {
            await getKeyPairByIdentity(identity);
          }
        }
      }
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  Future<KeychatIdentityKeyPair?> _initRoomSignalStore(Room room) async {
    if (room.mySignalIdentityKey == null) {
      final identityPubkey = room.getIdentity().signalIdentityKey;
      if (identityPubkey == null) return null;
      return _keypairs[identityPubkey];
    }
    return setupSignalStoreBySignalId(room.mySignalIdentityKey!);
  }

  /// Returns (and caches) the keypair for a known [SignalId].
  KeychatIdentityKeyPair getKeyPairBySignalId(SignalId signalId) {
    return _getKeyPair(signalId.pubkey, signalId.prikey);
  }

  // DEPRECATED: backward-compat path for the old 1:1 identityId→signalId mapping.
  // New code should use getKeyPairBySignalIdPubkey instead. Retained until
  // all callers that pass an Identity directly have been migrated — candidate
  // for removal.
  // compatible with older version about identityId:signalId = 1:1
  /// Returns (and caches) the curve25519 keypair for [identity].
  ///
  /// Reads the private key from secure storage on first access.
  /// Throws if [identity.signalIdentityKey] is null.
  Future<KeychatIdentityKeyPair> getKeyPairByIdentity(Identity identity) async {
    if (identity.signalIdentityKey == null) {
      throw Exception('signalIdentityKey_is_null');
    }
    final prikey = await SecureStorage.instance.readCurve25519PrikeyOrFail(
      identity.signalIdentityKey!,
    );
    return _getKeyPair(identity.signalIdentityKey!, prikey);
  }

  KeychatIdentityKeyPair _getKeyPair(String pubkey, String prikey) {
    if (_keypairs[pubkey] != null) {
      return _keypairs[pubkey]!;
    }
    final identityKeyPair = KeychatIdentityKeyPair(
      identityKey: U8Array33(Uint8List.fromList(hex.decode(pubkey))),
      privateKey: U8Array32(Uint8List.fromList(hex.decode(prikey))),
    );
    _keypairs[pubkey] = identityKeyPair;
    return identityKeyPair;
  }

  /// Loads and caches the keypair identified by [pubkey] into the Signal store,
  /// optionally using a pre-fetched [signalId] to avoid an extra DB query.
  Future<KeychatIdentityKeyPair> setupSignalStoreBySignalId(
    String pubkey, [
    SignalId? signalId,
  ]) async {
    final keyPair = await getKeyPairBySignalIdPubkey(pubkey, signalId);
    return keyPair;
  }

  /// Deletes the Signal session and identity record for [room] from the Rust store,
  /// and removes the corresponding KPA from the in-memory cache.
  ///
  /// Called when a room is deleted or when the session needs to be reset.
  Future<void> deleteSignalSessionKPA(Room room) async {
    if (room.peerSignalIdentityKey == null) return;
    final identity = Get.find<HomeController>().allIdentities[room.identityId];
    if (identity == null) return;
    KeychatIdentityKeyPair keyPair;
    if (room.mySignalIdentityKey != null) {
      keyPair = await getKeyPairBySignalIdPubkey(room.mySignalIdentityKey!);
    } else {
      keyPair = await getKeyPairByIdentity(room.getIdentity());
    }

    final remoteAddress = KeychatProtocolAddress(
      name: room.peerSignalIdentityKey!,
      deviceId: room.identityId,
    );

    final isDel = await rust_signal.deleteSession(
      keyPair: keyPair,
      address: remoteAddress,
    );

    logger.i('The deleteSignalSessionKPA flag is $isDel');

    await rust_signal.deleteIdentity(
      keyPair: keyPair,
      address: remoteAddress.name,
    );
    room.signalDecodeError = false;
    final key = '${room.identityId}:${room.peerSignalIdentityKey}';
    roomKPA.remove(key);
  }

  // generate onetime pubkey to receive add new friends message
  Future<List<Mykey>> _generateOneTimePubkeys(int identityId, int num) async {
    final onetimekeys = <Mykey>[];
    // create three one time keys
    for (var i = 0; i < num; i++) {
      final onetimekey = await IdentityService.instance.createOneTimeKey(
        identityId,
      );
      onetimekeys.add(onetimekey);
    }
    return onetimekeys;
  }

  Future<List<SignalId>> _generateSignalIds(int identityId, int num) async {
    final signalIds = <SignalId>[];
    for (var i = 0; i < num; i++) {
      final signalId = await SignalIdService.instance.createSignalId(
        identityId,
      );

      signalIds.add(signalId);
    }
    return signalIds;
  }

  /// Returns the keypair for the SignalId identified by [pubkey], using the cache
  /// or loading it from the database.
  Future<KeychatIdentityKeyPair> getKeyPairBySignalIdPubkey(
    String pubkey, [
    SignalId? signalId,
  ]) async {
    if (_keypairs[pubkey] != null) {
      return _keypairs[pubkey]!;
    }
    signalId ??= await SignalIdService.instance.getSignalIdByPubkey(pubkey);
    if (signalId == null) throw Exception('signalId is null');
    return getKeyPairBySignalId(signalId);
  }

  /// Returns the keypair for [room], loading it from the appropriate source
  /// (per-room SignalId or identity-level keypair).
  Future<KeychatIdentityKeyPair> getAndSetupKeyPairByRoom(Room room) async {
    KeychatIdentityKeyPair? keyPair;
    if (room.mySignalIdentityKey != null) {
      keyPair = await setupSignalStoreBySignalId(room.mySignalIdentityKey!);
      return keyPair;
    }
    return getKeyPairByIdentity(room.getIdentity());
  }
}
