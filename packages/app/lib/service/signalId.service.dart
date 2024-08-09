import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:app/global.dart';
import 'package:app/models/db_provider.dart';
import 'package:app/models/keychat/room_profile.dart';
import 'package:app/models/signal_id.dart';
import 'package:app/service/chatx.service.dart';
import 'package:convert/convert.dart' show hex;
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rustSignal;
import 'package:keychat_rust_ffi_plugin/api_signal.dart';

class SignalIdService {
  static SignalIdService? _instance;
  // Avoid self instance
  SignalIdService._();
  static SignalIdService get instance => _instance ??= SignalIdService._();

  Future createSignalId(int identityId, [bool isGroupSharedKey = false]) async {
    Isar database = DBProvider.database;
    var keychain = await rustSignal.generateSignalIds();
    var signalId = SignalId(
        prikey: hex.encode(keychain.$1),
        identityId: identityId,
        pubkey: hex.encode(keychain.$2))
      ..isGroupSharedKey = isGroupSharedKey
      ..isUsed = false;
    ChatxService chatxService = Get.find<ChatxService>();
    KeychatIdentityKeyPair keypair = await chatxService
        .setupSignalStoreBySignalId(signalId.pubkey, signalId);
    var signalPrivateKey = Uint8List.fromList(hex.decode(signalId.prikey));
    var signKeyResult = await rustSignal.generateSignedKeyApi(
        keyPair: keypair, signalIdentityPrivateKey: signalPrivateKey);

    signalId.signalKeyId = signKeyResult.$1;
    Map<String, dynamic> data = {};
    data['signedId'] = signKeyResult.$1;
    data['signedPublic'] = hex.encode(signKeyResult.$2);
    data['signedSignature'] = hex.encode(signKeyResult.$3);

    var prekeyResult = await rustSignal.generatePrekeyApi(keyPair: keypair);
    data['prekeyId'] = prekeyResult.$1;
    data['prekeyPubkey'] = hex.encode(prekeyResult.$2);
    if (isGroupSharedKey) {
      data['signedRecord'] = hex.encode(signKeyResult.$4);
      data['prekeyRecord'] = hex.encode(prekeyResult.$3);
    }
    signalId.keys = jsonEncode(data);

    await database.writeTxn(() async {
      await database.signalIds.put(signalId);
    });

    await Get.find<ChatxService>()
        .setupSignalStoreBySignalId(signalId.pubkey, signalId);
    return signalId;
  }

  Future<SignalId?> isFromSignalId(String toAddress) async {
    var res = await DBProvider.database.signalIds
        .filter()
        .pubkeyEqualTo(toAddress)
        .findAll();
    return res.isNotEmpty ? res[0] : null;
  }

  Future<List<SignalId>> getSignalAllIds() async {
    return await DBProvider.database.signalIds
        .filter()
        .isUsedEqualTo(false)
        .sortByCreatedAt()
        .findAll();
  }

  Future<List<SignalId>> getSignalIdByIdentity(int identityId) async {
    return await DBProvider.database.signalIds
        .filter()
        .identityIdEqualTo(identityId)
        .isUsedEqualTo(false)
        .sortByCreatedAt()
        .findAll();
  }

  Future<SignalId?> getSignalIdByPubkey(String pubkey) async {
    return await DBProvider.database.signalIds
        .filter()
        .pubkeyEqualTo(pubkey)
        .findFirst();
  }

  Future deleteSignalIdByPubkey(String pubkey) async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.signalIds
          .filter()
          .pubkeyEqualTo(pubkey)
          .deleteAll();
    });
  }

  Future<SignalId?> getSignalIdByKeyId(int signalKeyId) async {
    return await DBProvider.database.signalIds
        .filter()
        .signalKeyIdEqualTo(signalKeyId)
        .findFirst();
  }

  Future updateSignalId(SignalId si) async {
    Isar database = DBProvider.database;
    await database.writeTxn(() async {
      await database.signalIds.put(si);
    });
  }

  Future deleteExpiredSignalIds() async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.signalIds
          .filter()
          .isUsedEqualTo(true)
          .updatedAtLessThan(DateTime.now()
              .subtract(const Duration(hours: KeychatGlobal.signalIdLifetime)))
          .deleteAll();
    });
  }

  Future getQRCodeData(SignalId signalId) async {
    var keypair = Get.find<ChatxService>().getKeyPairBySignalId(signalId);

    var signalPrivateKey = Uint8List.fromList(hex.decode(signalId.prikey));
    var res = await rustSignal.generateSignedKeyApi(
        keyPair: keypair, signalIdentityPrivateKey: signalPrivateKey);

    signalId.signalKeyId = res.$1;
    await SignalIdService.instance.updateSignalId(signalId);
    Map<String, dynamic> data = {};
    data['signedId'] = res.$1;
    data['signedPublic'] = hex.encode(res.$2);
    data['signedSignature'] = hex.encode(res.$3);

    var res2 = await rustSignal.generatePrekeyApi(keyPair: keypair);
    data['prekeyId'] = res2.$1;
    data['prekeyPubkey'] = hex.encode(res2.$2);
    return data;
  }

  Future<SignalId> importSignalId(
      int identityId, RoomProfile roomProfile) async {
    if (roomProfile.signalKeys == null) {
      throw Exception('Signal keys is null, failed to join group.');
    }
    var signalId = SignalId(
        prikey: roomProfile.signaliPrikey!,
        pubkey: roomProfile.signalPubkey!,
        identityId: identityId)
      ..signalKeyId = roomProfile.signalKeyId
      ..keys = roomProfile.signalKeys
      ..isGroupSharedKey = true
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
    await DBProvider.database.signalIds.put(signalId);

    Map keys = jsonDecode(roomProfile.signalKeys!);
    var keyPair = Get.find<ChatxService>().getKeyPairBySignalId(signalId);
    await rustSignal.storePrekeyApi(
        keyPair: keyPair,
        prekeyId: keys['prekeyId'],
        record: hex.decode(keys['prekeyRecord']));
    await rustSignal.storeSignedKeyApi(
        keyPair: keyPair,
        signedKeyId: keys['signedId'],
        record: hex.decode(keys['signedRecord']));

    return signalId;
  }
}
