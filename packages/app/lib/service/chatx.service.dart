import 'dart:typed_data' show Uint8List;

import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/mykey.dart';
import 'package:app/models/room.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/notify.service.dart';
import 'package:app/service/signalId.service.dart';
import 'package:app/service/websocket.service.dart';
import 'package:convert/convert.dart';
import 'package:get/get.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rustSignal;
import 'package:keychat_rust_ffi_plugin/index.dart';

import '../utils.dart';

class ChatxService extends GetxService {
  Map<String, KeychatProtocolAddress> roomKPA = {};
  Set<String> oneTimeListenPubkeys = {};
  Map<String, KeychatIdentityKeyPair> keypairs = {};
  Set initedSignalStorePubkeySet = {};

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
    List<SignalId> signalIds =
        await SignalIdService.instance.getSignalIdByIdentity(identityId);
    if (signalIds.length < KeychatGlobal.signalIdsPoolLength) {
      List<SignalId> signalIds2 = await _generateSignalIds(
          identityId, KeychatGlobal.signalIdsPoolLength - signalIds.length);
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
      keyPair = getKeyPairByIdentity(room.getIdentity());
    }
    await rustSignal.processPrekeyBundleApi(
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
    final contains = await rustSignal.containsSession(
        keyPair: keyPair, address: remoteAddress);

    if (contains) {
      roomKPA[key] = remoteAddress;
      return remoteAddress;
    }
    return null;
  }

  Future<ChatxService> init(String dbpath) async {
    _initSignalDB(dbpath);
    return this;
  }

  Future<void> _initSignalDB(String dbpath) async {
    try {
      String signalPath = '$dbpath${KeychatGlobal.signalProcotolDBFile}';
      await rustSignal.initSignalDb(dbPath: signalPath);
      await Future.delayed(const Duration(milliseconds: 100));
      var identities = await IdentityService().getIdentityList();
      for (var element in identities) {
        await setupSignalStoreByIdentity(element);
      }
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  Future<KeychatIdentityKeyPair?> _initRoomSignalStore(Room room) async {
    if (room.signalIdPubkey == null) {
      String identityPubkey = room.getIdentity().curve25519PkHex;
      return keypairs[identityPubkey];
    }
    return await setupSignalStoreBySignalId(room.signalIdPubkey!);
  }

  KeychatIdentityKeyPair getKeyPairBySignalId(SignalId signalId) {
    return _getKeyPair(signalId.pubkey, signalId.prikey);
  }

  // compatible with older version about identityId:signalId = 1:1
  KeychatIdentityKeyPair getKeyPairByIdentity(Identity identity) {
    return _getKeyPair(identity.curve25519PkHex, identity.curve25519SkHex);
  }

  KeychatIdentityKeyPair _getKeyPair(String pubkey, String prikey) {
    if (keypairs[pubkey] != null) {
      return keypairs[pubkey]!;
    }
    KeychatIdentityKeyPair identityKeyPair = KeychatIdentityKeyPair(
        identityKey: U8Array33(Uint8List.fromList(hex.decode(pubkey))),
        privateKey: U8Array32(Uint8List.fromList(hex.decode(prikey))));
    keypairs[pubkey] = identityKeyPair;
    return identityKeyPair;
  }

  Future<KeychatIdentityKeyPair?> setupSignalStoreBySignalId(String pubkey,
      [SignalId? signalId]) async {
    if (initedSignalStorePubkeySet.contains(pubkey)) return keypairs[pubkey];
    var keyPair = await getKeyPairBySignalIdPubkey(pubkey, signalId);
    await rustSignal.initKeypair(keyPair: keyPair, regId: 0);
    initedSignalStorePubkeySet.add(pubkey);
    return keyPair;
  }

  Future<KeychatIdentityKeyPair> setupSignalStoreByIdentity(
      Identity identity) async {
    var keyPair = getKeyPairByIdentity(identity);
    await rustSignal.initKeypair(keyPair: keyPair, regId: 0);
    initedSignalStorePubkeySet.add(identity.curve25519PkHex);
    return keyPair;
  }

  Future deleteSignalSessionKPA(Room room) async {
    if (room.curve25519PkHex == null) {
      throw Exception("curve25519PkHex_is_null");
    }
    Identity? identity = Get.find<HomeController>().identities[room.identityId];
    if (identity == null) return;
    final remoteAddress = KeychatProtocolAddress(
        name: room.curve25519PkHex!, deviceId: room.identityId);
    KeychatIdentityKeyPair keyPair;
    if (room.signalIdPubkey != null) {
      keyPair = await getKeyPairBySignalIdPubkey(room.signalIdPubkey!);
    } else {
      keyPair = getKeyPairByIdentity(room.getIdentity());
    }
    await rustSignal.deleteSession(keyPair: keyPair, address: remoteAddress);
    await rustSignal.deleteIdentity(
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
    if (keypairs[pubkey] != null) {
      return keypairs[pubkey]!;
    }
    signalId ??= await SignalIdService.instance.getSignalIdByPubkey(pubkey);
    if (signalId == null) throw Exception('signalId is null');
    return getKeyPairBySignalId(signalId);
  }

  Future<KeychatIdentityKeyPair> getAndSetupKeyPairByRoom(Room room) async {
    KeychatIdentityKeyPair? keyPair;
    if (room.signalIdPubkey != null) {
      keyPair = await setupSignalStoreBySignalId(room.signalIdPubkey!);
      if (keyPair == null) throw Exception('signalIdPubkey\'s keypair is null');
      return keyPair;
    }
    return getKeyPairByIdentity(room.getIdentity());
  }
}
