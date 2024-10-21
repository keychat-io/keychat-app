import 'dart:convert' show jsonDecode;
import 'dart:typed_data' show Uint8List;

import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/mykey.dart';
import 'package:app/models/room.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:convert/convert.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;
import 'package:keychat_rust_ffi_plugin/index.dart';

import '../utils.dart';

class ChatxService extends GetxService {
  Map<String, KeychatProtocolAddress> roomKPA = {};
  final Map<String, KeychatIdentityKeyPair> _keypairs = {};
  Map<String, KeychatIdentityKeyPair> initedKeypairs = {};

  Future<List<Mykey>> getOneTimePubkey(int identityId) async {
    // delete expired one time keys
    await IdentityService().deleteExpiredOneTimeKeys();
    List<Mykey> newKeys =
        await IdentityService().getOneTimeKeyByIdentity(identityId);

    List<String> needListen = [];
    for (var key in newKeys) {
      needListen.add(key.pubkey);
    }

    if (needListen.length < KeychatGlobal.oneTimePubkeysPoolLength) {
      List<Mykey> newKeys2 = await _generateOneTimePubkeys(identityId,
          KeychatGlobal.oneTimePubkeysPoolLength - needListen.length);
      for (var key in newKeys2) {
        needListen.add(key.pubkey);
      }
      newKeys.addAll(newKeys2);
    }
    if (needListen.isNotEmpty) {
      Get.find<WebsocketService>().listenPubkey(needListen);
      NotifyService.addPubkeys(needListen);
    }
    return newKeys;
  }

  Future<List<SignalId>> getSignalIds(int identityId) async {
    // delete expired signal ids
    // await deleteExpiredSignalIds();
    Identity? identity = await IdentityService().getIdentityById(identityId);
    if (identity == null) throw Exception('Identity not found');
    List<SignalId> signalIds =
        await SignalIdService.instance.getSignalIdByIdentity(identityId);
    if (signalIds.length < KeychatGlobal.signalIdsPoolLength) {
      List<SignalId> signalIds2 = await _generateSignalIds(
          identity.id, KeychatGlobal.signalIdsPoolLength - signalIds.length);
      signalIds.addAll(signalIds2);
    }
    return signalIds;
  }

  Future<bool> addRoomKPA({
    required Room room,
    required int bobSignedId,
    required Uint8List bobSignedPublic,
    required Uint8List bobSignedSignature,
    required int bobPrekeyId,
    required Uint8List bobPrekeyPublic,
  }) async {
    if (room.curve25519PkHex == null) {
      return false;
    }
    KeychatProtocolAddress? exist = await getRoomKPA(room);
    if (exist != null) {
      return true;
    }
    final remoteAddress = KeychatProtocolAddress(
        name: room.curve25519PkHex!, deviceId: room.identityId);
    // Alice Signal id keypair
    KeychatIdentityKeyPair keyPair;
    if (room.signalIdPubkey != null) {
      keyPair = await getKeyPairBySignalIdPubkey(room.signalIdPubkey!);
    } else {
      keyPair = await getKeyPairByIdentity(room.getIdentity());
    }
    await rust_signal.processPrekeyBundleApi(
        keyPair: keyPair,
        regId: getRegistrationId(room.curve25519PkHex!),
        deviceId: room.identityId,
        identityKey: KeychatIdentityKey(
            publicKey: U8Array33(
                Uint8List.fromList(hex.decode(room.curve25519PkHex!)))),
        remoteAddress: remoteAddress,
        bobSignedId: bobSignedId,
        bobSignedPublic: bobSignedPublic,
        bobSigedSig: bobSignedSignature,
        bobPrekeyId: bobPrekeyId,
        bobPrekeyPublic: bobPrekeyPublic);
    return true;
  }

  Future<bool> addKPAForSharedSignalId(Identity identity, String sharedPubkey,
      String sginalKeys, int sharedSignalIdentityId) async {
    KeychatIdentityKeyPair keyPair = await getKeyPairByIdentity(identity);
    final remoteAddress = KeychatProtocolAddress(
        name: sharedPubkey, deviceId: sharedSignalIdentityId);

    Map<String, dynamic> keys = jsonDecode(sginalKeys);
    await rust_signal.processPrekeyBundleApi(
        keyPair: keyPair,
        regId: getRegistrationId(sharedPubkey),
        deviceId: sharedSignalIdentityId,
        identityKey: KeychatIdentityKey(
            publicKey: U8Array33(Uint8List.fromList(hex.decode(sharedPubkey)))),
        remoteAddress: remoteAddress,
        bobSignedId: keys['signedId'],
        bobSignedPublic: Uint8List.fromList(hex.decode(keys['signedPublic'])),
        bobSigedSig: Uint8List.fromList(hex.decode(keys['signedSignature'])),
        bobPrekeyId: keys['prekeyId'],
        bobPrekeyPublic: Uint8List.fromList(hex.decode(keys['prekeyPubkey'])));
    return true;
  }

  Future<bool> addKPAByRoomSignalId(
      SignalId myRoomSignalId,
      String sharedPubkey,
      String sginalKeys,
      int sharedSignalIdentityId) async {
    KeychatIdentityKeyPair keyPair = getKeyPairBySignalId(myRoomSignalId);
    final remoteAddress = KeychatProtocolAddress(
        name: sharedPubkey, deviceId: sharedSignalIdentityId);

    Map<String, dynamic> keys = jsonDecode(sginalKeys);
    await rust_signal.processPrekeyBundleApi(
        keyPair: keyPair,
        regId: getRegistrationId(sharedPubkey),
        deviceId: sharedSignalIdentityId,
        identityKey: KeychatIdentityKey(
            publicKey: U8Array33(Uint8List.fromList(hex.decode(sharedPubkey)))),
        remoteAddress: remoteAddress,
        bobSignedId: keys['signedId'],
        bobSignedPublic: Uint8List.fromList(hex.decode(keys['signedPublic'])),
        bobSigedSig: Uint8List.fromList(hex.decode(keys['signedSignature'])),
        bobPrekeyId: keys['prekeyId'],
        bobPrekeyPublic: Uint8List.fromList(hex.decode(keys['prekeyPubkey'])));
    return true;
  }

  Future<KeychatProtocolAddress?> getRoomKPA(Room room) async {
    if (room.curve25519PkHex == null) return null;
    String key = '${room.identityId}:${room.curve25519PkHex}';
    if (roomKPA[key] != null) {
      return roomKPA[key]!;
    }

    final remoteAddress = KeychatProtocolAddress(
        name: room.curve25519PkHex!, deviceId: room.identityId);
    KeychatIdentityKeyPair? keyPair = await _initRoomSignalStore(room);
    if (keyPair == null) return null;
    final contains = await rust_signal.containsSession(
        keyPair: keyPair, address: remoteAddress);

    if (contains) {
      roomKPA[key] = remoteAddress;
      return remoteAddress;
    }
    return null;
  }

  Future<KeychatProtocolAddress> getRoomKPAOrFailed(Room room) async {
    if (room.curve25519PkHex == null) {
      throw Exception('curve25519PkHex_is_null');
    }
    String key = '${room.identityId}:${room.curve25519PkHex}';
    if (roomKPA[key] != null) {
      return roomKPA[key]!;
    }

    final remoteAddress = KeychatProtocolAddress(
        name: room.curve25519PkHex!, deviceId: room.identityId);
    KeychatIdentityKeyPair? keyPair = await _initRoomSignalStore(room);
    if (keyPair == null) {
      throw Exception('keyPair_is_null');
    }
    final contains = await rust_signal.containsSession(
        keyPair: keyPair, address: remoteAddress);

    if (contains) {
      roomKPA[key] = remoteAddress;
      return remoteAddress;
    }
    throw Exception('signal_session_not_found');
  }

  Future<KeychatProtocolAddress?> getSignalSession(
      {required int sharedSignalRoomId,
      required String toCurve25519PkHex,
      required KeychatIdentityKeyPair keyPair}) async {
    String key = '$sharedSignalRoomId:$toCurve25519PkHex';
    if (roomKPA[key] != null) return roomKPA[key]!;

    final remoteAddress = KeychatProtocolAddress(
        name: toCurve25519PkHex, deviceId: sharedSignalRoomId);

    final contains = await rust_signal.containsSession(
        keyPair: keyPair, address: remoteAddress);

    if (!contains) return null;

    roomKPA[key] = remoteAddress;
    return remoteAddress;
  }

  Future<ChatxService> init(String dbpath) async {
    _initSignalDB(dbpath);
    return this;
  }

  Future<void> _initSignalDB(String dbpath) async {
    try {
      String signalPath = '$dbpath${KeychatGlobal.signalProcotolDBFile}';
      await rust_signal.initSignalDb(dbPath: signalPath);
      await Future.delayed(const Duration(milliseconds: 100));
      var identities = await IdentityService().getIdentityList();
      for (var identity in identities) {
        if (identity.curve25519PkHex != null) {
          if (identity.curve25519PkHex!.isNotEmpty) {
            await setupSignalStoreByIdentity(identity);
          }
        }
      }
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  Future<KeychatIdentityKeyPair?> _initRoomSignalStore(Room room) async {
    if (room.signalIdPubkey == null) {
      String? identityPubkey = room.getIdentity().curve25519PkHex;
      if (identityPubkey == null) return null;
      return _keypairs[identityPubkey];
    }
    return await setupSignalStoreBySignalId(room.signalIdPubkey!);
  }

  KeychatIdentityKeyPair getKeyPairBySignalId(SignalId signalId) {
    return _getKeyPair(signalId.pubkey, signalId.prikey);
  }

  // compatible with older version about identityId:signalId = 1:1
  Future<KeychatIdentityKeyPair> getKeyPairByIdentity(Identity identity) async {
    if (identity.curve25519PkHex == null) {
      throw Exception('curve25519PkHex_is_null');
    }
    var prikey = await SecureStorage.instance
        .readPrikeyOrFail(identity.curve25519PkHex!);
    return _getKeyPair(identity.curve25519PkHex!, prikey);
  }

  KeychatIdentityKeyPair _getKeyPair(String pubkey, String prikey) {
    if (_keypairs[pubkey] != null) {
      return _keypairs[pubkey]!;
    }
    KeychatIdentityKeyPair identityKeyPair = KeychatIdentityKeyPair(
        identityKey: U8Array33(Uint8List.fromList(hex.decode(pubkey))),
        privateKey: U8Array32(Uint8List.fromList(hex.decode(prikey))));
    _keypairs[pubkey] = identityKeyPair;
    return identityKeyPair;
  }

  Future<KeychatIdentityKeyPair> setupSignalStoreBySignalId(String pubkey,
      [SignalId? signalId]) async {
    if (initedKeypairs[pubkey] != null) return initedKeypairs[pubkey]!;
    var keyPair = await getKeyPairBySignalIdPubkey(pubkey, signalId);
    await rust_signal.initKeypair(keyPair: keyPair, regId: 0);
    initedKeypairs[pubkey] = keyPair;
    return keyPair;
  }

  Future<KeychatIdentityKeyPair> setupSignalStoreByIdentity(
      Identity identity) async {
    String pubkey = identity.curve25519PkHex!;
    if (initedKeypairs[pubkey] != null) return initedKeypairs[pubkey]!;
    KeychatIdentityKeyPair keyPair = await getKeyPairByIdentity(identity);
    await rust_signal.initKeypair(keyPair: keyPair, regId: 0);
    initedKeypairs[pubkey] = keyPair;
    return keyPair;
  }

  Future deleteSignalSessionKPA(Room room) async {
    if (room.curve25519PkHex == null) return;
    Identity? identity = Get.find<HomeController>().identities[room.identityId];
    if (identity == null) return;
    KeychatIdentityKeyPair keyPair;
    if (room.signalIdPubkey != null) {
      keyPair = await getKeyPairBySignalIdPubkey(room.signalIdPubkey!);
    } else {
      keyPair = await getKeyPairByIdentity(room.getIdentity());
    }

    KeychatProtocolAddress remoteAddress = KeychatProtocolAddress(
        name: room.curve25519PkHex!, deviceId: room.identityId);

    // compatible with older version about identityId:signalId = 1:1
    await rust_signal.initKeypair(keyPair: keyPair, regId: 0);

    bool isDel = await rust_signal.deleteSession(
        keyPair: keyPair, address: remoteAddress);

    logger.d("The deleteSignalSessionKPA flag is $isDel");

    await rust_signal.deleteIdentity(
        keyPair: keyPair, address: remoteAddress.name);
    room.signalDecodeError = false;
    String key = '${room.identityId}:${room.curve25519PkHex}';
    roomKPA.remove(key);
    // await RoomService().updateRoom(room);
    // RoomService.getController(room.id)?.setRoom(room);
  }

// generate onetime pubkey to receive add new friends message
  Future<List<Mykey>> _generateOneTimePubkeys(int identityId, int num) async {
    List<Mykey> onetimekeys = [];
// create three one time keys
    for (var i = 0; i < num; i++) {
      Mykey onetimekey = await IdentityService().createOneTimeKey(identityId);
      onetimekeys.add(onetimekey);
    }
    return onetimekeys;
  }

  Future<List<SignalId>> _generateSignalIds(int identityId, int num) async {
    List<SignalId> signalIds = [];
    for (var i = 0; i < num; i++) {
      SignalId signalId =
          await SignalIdService.instance.createSignalId(identityId);

      signalIds.add(signalId);
    }
    return signalIds;
  }

  Future<KeychatIdentityKeyPair> getKeyPairBySignalIdPubkey(String pubkey,
      [SignalId? signalId]) async {
    if (_keypairs[pubkey] != null) {
      return _keypairs[pubkey]!;
    }
    signalId ??= await SignalIdService.instance.getSignalIdByPubkey(pubkey);
    if (signalId == null) throw Exception('signalId is null');
    return getKeyPairBySignalId(signalId);
  }

  Future<KeychatIdentityKeyPair> getAndSetupKeyPairByRoom(Room room) async {
    KeychatIdentityKeyPair? keyPair;
    if (room.signalIdPubkey != null) {
      keyPair = await setupSignalStoreBySignalId(room.signalIdPubkey!);
      return keyPair;
    }
    return getKeyPairByIdentity(room.getIdentity());
  }
}
