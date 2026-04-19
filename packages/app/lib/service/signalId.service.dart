import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:typed_data' show Uint8List;

import 'package:keychat/global.dart';
import 'package:keychat/models/db_provider.dart';
import 'package:keychat/models/keychat/room_profile.dart';
import 'package:keychat/models/signal_id.dart';
import 'package:keychat/service/chatx.service.dart';
import 'package:convert/convert.dart' show hex;
import 'package:get/get.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rust_signal;

class SignalIdService {
  // Avoid self instance
  SignalIdService._();
  static SignalIdService? _instance;
  static SignalIdService get instance => _instance ??= SignalIdService._();

  /// Creates a new [SignalId] for [identityId] and persists it to the database.
  ///
  /// Generates a fresh Curve25519 identity key pair via [rust_signal.generateSignalIds],
  /// initialises the Signal protocol store, and derives a signed prekey plus one-time prekey.
  ///
  /// When [isGroupSharedKey] is `true`, the full signed-key and prekey records are
  /// serialised into [SignalId.keys] so they can be exported to group members via
  /// [RoomProfile] for shared-key group messaging.
  ///
  /// Returns the persisted [SignalId].
  Future<SignalId> createSignalId(
    int identityId, [
    bool isGroupSharedKey = false,
  ]) async {
    final database = DBProvider.database;
    final keychain = await rust_signal.generateSignalIds();
    final signalId =
        SignalId(
            prikey: hex.encode(keychain.privateKey),
            identityId: identityId,
            pubkey: hex.encode(keychain.publicKey),
          )
          ..isGroupSharedKey = isGroupSharedKey
          ..isUsed = false;
    final chatxService = Get.find<ChatxService>();
    final keypair = await chatxService.setupSignalStoreBySignalId(
      signalId.pubkey,
      signalId,
    );
    final signalPrivateKey = Uint8List.fromList(hex.decode(signalId.prikey));
    final signKeyResult = await rust_signal.generateSignedPreKeyApi(
      keyPair: keypair,
      signalIdentityPrivateKey: signalPrivateKey,
    );

    signalId.signalKeyId = signKeyResult.signedPreKeyId;
    final data = <String, dynamic>{};
    data['signedId'] = signKeyResult.signedPreKeyId;
    data['signedPublic'] = hex.encode(signKeyResult.signedPreKeyPublic);
    data['signedSignature'] = hex.encode(signKeyResult.signedPreKeySignature);

    final prekeyResult = await rust_signal.generatePrekeyApi(keyPair: keypair);
    data['prekeyId'] = prekeyResult.preKeyId;
    data['prekeyPubkey'] = hex.encode(prekeyResult.preKeyPublic);
    if (isGroupSharedKey) {
      data['signedRecord'] = hex.encode(signKeyResult.signedPreKeyRecord);
      data['prekeyRecord'] = hex.encode(prekeyResult.preKeyRecord);
    }
    signalId.keys = jsonEncode(data);

    await database.writeTxn(() async {
      await database.signalIds.put(signalId);
    });

    await Get.find<ChatxService>().setupSignalStoreBySignalId(
      signalId.pubkey,
      signalId,
    );
    return signalId;
  }

  /// Returns the [SignalId] whose pubkey matches [toAddress], or `null` if not found.
  ///
  /// Used to determine whether an incoming Nostr event was addressed to one of our
  /// own Signal identity keys (as opposed to a ratchet receive address).
  Future<SignalId?> isFromSignalId(String toAddress) async {
    final res = await DBProvider.database.signalIds
        .filter()
        .pubkeyEqualTo(toAddress)
        .findAll();
    return res.isNotEmpty ? res[0] : null;
  }

  /// Returns all unused [SignalId]s across all identities, ordered by creation date.
  Future<List<SignalId>> getSignalAllIds() async {
    return DBProvider.database.signalIds
        .filter()
        .isUsedEqualTo(false)
        .sortByCreatedAt()
        .findAll();
  }

  /// Returns all unused [SignalId]s belonging to [identityId], ordered by creation date.
  Future<List<SignalId>> getSignalIdByIdentity(int identityId) async {
    return DBProvider.database.signalIds
        .filter()
        .identityIdEqualTo(identityId)
        .isUsedEqualTo(false)
        .sortByCreatedAt()
        .findAll();
  }

  /// Returns the [SignalId] matching both [identityId] and [pubkey], or `null`.
  Future<SignalId?> getSignalId(int identityId, String pubkey) async {
    return DBProvider.database.signalIds
        .filter()
        .identityIdEqualTo(identityId)
        .pubkeyEqualTo(pubkey)
        .findFirst();
  }

  /// Returns the first [SignalId] with the given [pubkey], or `null` if not found.
  ///
  /// Returns `null` immediately when [pubkey] is `null`.
  Future<SignalId?> getSignalIdByPubkey(String? pubkey) async {
    if (pubkey == null) return null;
    return DBProvider.database.signalIds
        .filter()
        .pubkeyEqualTo(pubkey)
        .findFirst();
  }

  /// Returns the [SignalId] whose [SignalId.signalKeyId] matches [signalKeyId], or `null`.
  ///
  /// Used during prekey message decryption to locate the correct identity key pair
  /// from the key ID embedded in the prekey message header.
  Future<SignalId?> getSignalIdByKeyId(int signalKeyId) async {
    return DBProvider.database.signalIds
        .filter()
        .signalKeyIdEqualTo(signalKeyId)
        .findFirst();
  }

  /// Persists changes to [si] in the database (upsert).
  Future<void> updateSignalId(SignalId si) async {
    final database = DBProvider.database;
    await database.writeTxn(() async {
      await database.signalIds.put(si);
    });
  }

  /// Deletes all used [SignalId]s that were last updated more than
  /// [KeychatGlobal.signalIdLifetime] hours ago.
  ///
  /// Called periodically to prune consumed one-time key material from the database
  /// and prevent unbounded growth of the signal_ids table.
  Future<void> deleteExpiredSignalIds() async {
    await DBProvider.database.writeTxn(() async {
      await DBProvider.database.signalIds
          .filter()
          .isUsedEqualTo(true)
          .updatedAtLessThan(
            DateTime.now().subtract(
              const Duration(hours: KeychatGlobal.signalIdLifetime),
            ),
          )
          .deleteAll();
    });
  }

  /// Generates fresh signed-prekey and one-time prekey data for embedding in a QR code.
  ///
  /// Regenerates the signed key for [signalId], updates [SignalId.signalKeyId], and
  /// returns a map with the fields required by the QR code scanner:
  /// `signedId`, `signedPublic`, `signedSignature`, `prekeyId`, `prekeyPubkey`, `time`.
  ///
  /// [time] is included verbatim in the returned map for replay-protection on the
  /// receiving side.
  Future<Map<String, dynamic>> getQRCodeData(
    SignalId signalId,
    int time,
  ) async {
    final keypair = Get.find<ChatxService>().getKeyPairBySignalId(signalId);

    final signalPrivateKey = Uint8List.fromList(hex.decode(signalId.prikey));
    final res = await rust_signal.generateSignedPreKeyApi(
      keyPair: keypair,
      signalIdentityPrivateKey: signalPrivateKey,
    );

    signalId.signalKeyId = res.signedPreKeyId;
    await SignalIdService.instance.updateSignalId(signalId);
    final data = <String, dynamic>{};
    data['signedId'] = res.signedPreKeyId;
    data['signedPublic'] = hex.encode(res.signedPreKeyPublic);
    data['signedSignature'] = hex.encode(res.signedPreKeySignature);

    final res2 = await rust_signal.generatePrekeyApi(keyPair: keypair);
    data['prekeyId'] = res2.preKeyId;
    data['prekeyPubkey'] = hex.encode(res2.preKeyPublic);
    data['time'] = time;
    return data;
  }

  /// Imports a shared [SignalId] from [roomProfile], or returns the existing one.
  ///
  /// Used when joining a Signal-based group to import the group's shared identity key.
  /// Stores the prekey and signed key records in the local Signal protocol store so
  /// the key can be used for group message encryption and decryption.
  ///
  /// Throws an [Exception] if [roomProfile.signalKeys] is `null`, indicating the
  /// profile does not carry the key material needed for import.
  Future<SignalId> importOrGetSignalId(
    int identityId,
    RoomProfile roomProfile,
  ) async {
    if (roomProfile.signalKeys == null) {
      throw Exception('Signal keys is null, failed to join group.');
    }
    final exist = await getSignalId(identityId, roomProfile.signalPubkey!);
    if (exist != null) return exist;

    final signalId =
        SignalId(
            prikey: roomProfile.signaliPrikey!,
            pubkey: roomProfile.signalPubkey!,
            identityId: identityId,
          )
          ..signalKeyId = roomProfile.signalKeyId
          ..keys = roomProfile.signalKeys
          ..isGroupSharedKey = true
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now();
    await DBProvider.database.signalIds.put(signalId);

    final keys = jsonDecode(roomProfile.signalKeys!) as Map<String, dynamic>;
    final keyPair = await Get.find<ChatxService>().setupSignalStoreBySignalId(
      signalId.pubkey,
      signalId,
    );

    await rust_signal.storePreKeyApi(
      keyPair: keyPair,
      preKeyId: keys['prekeyId'] as int,
      preKeyRecord: hex.decode(keys['prekeyRecord'] as String),
    );
    await rust_signal.storeSignedPreKeyApi(
      keyPair: keyPair,
      signedPreKeyId: keys['signedId'] as int,
      signedPreKeyRecord: hex.decode(keys['signedRecord'] as String),
    );

    return signalId;
  }

  /// Deletes [model] from the database.
  ///
  /// Returns `true` if a record was deleted, `false` if [model] is `null` or not found.
  Future<bool> deleteSignalId(SignalId? model) async {
    if (model == null) return false;
    return DBProvider.database.signalIds
        .filter()
        .idEqualTo(model.id)
        .deleteFirst();
  }
}
