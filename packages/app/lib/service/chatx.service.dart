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
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;
import 'package:keychat_rust_ffi_plugin/api_signal.dart';
import 'package:keychat_rust_ffi_plugin/index.dart';

class ChatxService extends GetxService {
  Map<String, KeychatProtocolAddress> roomKPA = {};
  final Map<String, KeychatIdentityKeyPair> _keypairs = {};

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
    final exist = await getRoomKPA(room);
    if (exist != null) {
      return true;
    }
    final remoteAddress = KeychatProtocolAddress(
      name: room.curve25519PkHex!,
      deviceId: room.identityId,
    );
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
          Uint8List.fromList(hex.decode(room.curve25519PkHex!)),
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
      bobSignedId: keys['signedId'],
      bobSignedPublic: Uint8List.fromList(hex.decode(keys['signedPublic'])),
      bobSigedSig: Uint8List.fromList(hex.decode(keys['signedSignature'])),
      bobPrekeyId: keys['prekeyId'],
      bobPrekeyPublic: Uint8List.fromList(hex.decode(keys['prekeyPubkey'])),
    );
    return true;
  }

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
      bobSignedId: keys['signedId'],
      bobSignedPublic: Uint8List.fromList(hex.decode(keys['signedPublic'])),
      bobSigedSig: Uint8List.fromList(hex.decode(keys['signedSignature'])),
      bobPrekeyId: keys['prekeyId'],
      bobPrekeyPublic: Uint8List.fromList(hex.decode(keys['prekeyPubkey'])),
    );
    return true;
  }

  Future<KeychatProtocolAddress?> getRoomKPA(Room room) async {
    if (room.curve25519PkHex == null) return null;
    final key = '${room.identityId}:${room.curve25519PkHex}';
    if (roomKPA[key] != null) {
      return roomKPA[key]!;
    }

    final remoteAddress = KeychatProtocolAddress(
      name: room.curve25519PkHex!,
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

  Future<KeychatProtocolAddress> getRoomKPAOrFailed(Room room) async {
    if (room.curve25519PkHex == null) {
      throw Exception('curve25519PkHex_is_null');
    }
    final key = '${room.identityId}:${room.curve25519PkHex}';
    if (roomKPA[key] != null) {
      return roomKPA[key]!;
    }

    final remoteAddress = KeychatProtocolAddress(
      name: room.curve25519PkHex!,
      deviceId: room.identityId,
    );
    final keyPair = await _initRoomSignalStore(room);
    if (keyPair == null) {
      throw Exception('keyPair_is_null');
    }
    final contains = await rust_signal.containsSession(
      keyPair: keyPair,
      address: remoteAddress,
    );

    if (contains) {
      roomKPA[key] = remoteAddress;
      return remoteAddress;
    }
    throw Exception('signal_session_is_null');
  }

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
    final relays = await RelayService.instance.initRelay();
    Get.put(WebsocketService(relays), permanent: true);
    return this;
  }

  Future<void> _initSignalDB(String dbpath) async {
    try {
      final signalPath = '$dbpath${KeychatGlobal.signalProcotolDBFile}';
      await rust_signal.initSignalDb(dbPath: signalPath);
      final identities = await IdentityService.instance.getIdentityList();
      for (final identity in identities) {
        if (identity.curve25519PkHex != null) {
          if (identity.curve25519PkHex!.isNotEmpty) {
            await getKeyPairByIdentity(identity);
          }
        }
      }
    } catch (e, s) {
      logger.e(e.toString(), error: e, stackTrace: s);
    }
  }

  Future<KeychatIdentityKeyPair?> _initRoomSignalStore(Room room) async {
    if (room.signalIdPubkey == null) {
      final identityPubkey = room.getIdentity().curve25519PkHex;
      if (identityPubkey == null) return null;
      return _keypairs[identityPubkey];
    }
    return setupSignalStoreBySignalId(room.signalIdPubkey!);
  }

  KeychatIdentityKeyPair getKeyPairBySignalId(SignalId signalId) {
    return _getKeyPair(signalId.pubkey, signalId.prikey);
  }

  // compatible with older version about identityId:signalId = 1:1
  Future<KeychatIdentityKeyPair> getKeyPairByIdentity(Identity identity) async {
    if (identity.curve25519PkHex == null) {
      throw Exception('curve25519PkHex_is_null');
    }
    final prikey = await SecureStorage.instance.readCurve25519PrikeyOrFail(
      identity.curve25519PkHex!,
    );
    return _getKeyPair(identity.curve25519PkHex!, prikey);
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

  Future<KeychatIdentityKeyPair> setupSignalStoreBySignalId(
    String pubkey, [
    SignalId? signalId,
  ]) async {
    final keyPair = await getKeyPairBySignalIdPubkey(pubkey, signalId);
    return keyPair;
  }

  Future<void> deleteSignalSessionKPA(Room room) async {
    if (room.curve25519PkHex == null) return;
    final identity = Get.find<HomeController>().allIdentities[room.identityId];
    if (identity == null) return;
    KeychatIdentityKeyPair keyPair;
    if (room.signalIdPubkey != null) {
      keyPair = await getKeyPairBySignalIdPubkey(room.signalIdPubkey!);
    } else {
      keyPair = await getKeyPairByIdentity(room.getIdentity());
    }

    final remoteAddress = KeychatProtocolAddress(
      name: room.curve25519PkHex!,
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
    final key = '${room.identityId}:${room.curve25519PkHex}';
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

  Future<KeychatIdentityKeyPair> getAndSetupKeyPairByRoom(Room room) async {
    KeychatIdentityKeyPair? keyPair;
    if (room.signalIdPubkey != null) {
      keyPair = await setupSignalStoreBySignalId(room.signalIdPubkey!);
      return keyPair;
    }
    return getKeyPairByIdentity(room.getIdentity());
  }
}
