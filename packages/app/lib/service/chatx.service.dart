import 'dart:typed_data' show Uint8List;

import 'package:app/controller/home.controller.dart';
import 'package:app/global.dart';
import 'package:app/models/identity.dart';
import 'package:app/models/mykey.dart';
import 'package:app/models/room.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/notify.service.dart';
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
        await IdentityService().getSignalIdByIdentity(identityId);
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
    final keyPair = await getKeyPair(room.signalIdPubkey!);
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

  Future<KeychatProtocolAddress?> getRoomKPA(
    Room room,
  ) async {
    if (room.curve25519PkHex == null) {
      return null;
    }
    String key = '${room.identityId}:${room.curve25519PkHex}';
    if (roomKPA[key] != null) {
      return roomKPA[key]!;
    }

    final remoteAddress = KeychatProtocolAddress(
        name: room.curve25519PkHex!, deviceId: room.identityId);
    final keyPair = await getKeyPair(room.signalIdPubkey!);
    final contains = await rustSignal.containsSession(
        keyPair: keyPair, address: remoteAddress);

    if (contains) {
      roomKPA[key] = remoteAddress;
      return remoteAddress;
    }
    return null;
  }

  Future<ChatxService> init(String dbpath) async {
    try {
      String signalPath = '$dbpath${KeychatGlobal.signalProcotolDBFile}';
      await rustSignal.initSignalDb(dbPath: signalPath);
      var signalIds = await IdentityService().getSignalAllIds();
      for (var signalId in signalIds) {
        await setupIdentitySignalStore(signalId);
      }
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }

    return this;
  }

  Future<KeychatIdentityKeyPair> getKeyPair(String pubkey) async {
    if (keypairs[pubkey] != null) {
      return keypairs[pubkey]!;
    }
    String? prikey;
    SignalId? signalId = await IdentityService().getSignalIdByPubkey(pubkey);
    if (signalId != null) {
      prikey = signalId.prikey;
    } else {
      Identity? identity =
          await IdentityService().getIdentityByNostrPubkey(pubkey);
      if (identity != null) {
        prikey = identity.curve25519SkHex;
      }
    }
    if (prikey == null) throw Exception("not found keypair");

    KeychatIdentityKeyPair identityKeyPair = KeychatIdentityKeyPair(
        identityKey: U8Array33(Uint8List.fromList(hex.decode(pubkey))),
        privateKey: U8Array32(Uint8List.fromList(hex.decode(prikey))));
    keypairs[pubkey] = identityKeyPair;
    return identityKeyPair;
  }

  setupIdentitySignalStore(SignalId signalId, [int deviceId = 1]) async {
    await rustSignal.initKeypair(
        keyPair: await getKeyPair(signalId.pubkey), regId: 0);
  }

  Future<KeychatProtocolAddress> resetRoomKPA(
      Identity identity, String bobAddress, int identityId) async {
    String key = '$identityId:$bobAddress';
    // roomKPA[key] =
    //     await _checkSignalSessionKPA(identity, bobAddress, identityId);
    //     await _checkSignalSessionKPA(
    //     identity: identity,
    //     bobAddress: bobAddress,
    //     identityId: identityId,
    //     bobSignedId: bobSignedId,
    //     bobSignedPublic: bobSignedPublic,
    //     bobSignedSignature: bobSignedSignature)
    return roomKPA[key]!;
  }

  Future deleteSignalSessionKPA(Room room) async {
    if (room.curve25519PkHex == null) {
      throw Exception("curve25519PkHex_is_null");
    }
    Identity? identity = Get.find<HomeController>().identities[room.identityId];
    if (identity == null) return;
    final remoteAddress = KeychatProtocolAddress(
        name: room.curve25519PkHex!, deviceId: room.identityId);
    final keyPair = await getKeyPair(room.signalIdPubkey!);
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
      SignalId signalId = await IdentityService().createSignalId(identityId);

      signalIds.add(signalId);
    }
    return signalIds;
  }

  Future getQRCodeData(SignalId signalId) async {
    var keypair = await getKeyPair(signalId.pubkey);

    var signalPrivateKey = Uint8List.fromList(hex.decode(signalId.prikey));
    var res = await rustSignal.generateSignedKeyApi(
        keyPair: keypair, signalIdentityPrivateKey: signalPrivateKey);

    signalId.signalKeyId = res.$1;
    await IdentityService().updateSignalId(signalId);
    Map<String, dynamic> data = {};
    data['signedId'] = res.$1;
    data['signedPublic'] = hex.encode(res.$2);
    data['signedSignature'] = hex.encode(res.$3);

    var res2 = await rustSignal.generatePrekeyApi(keyPair: keypair);
    data['prekeyId'] = res2.$1;
    data['prekeyPubkey'] = hex.encode(res2.$2);
    return data;
  }
}
