import 'package:convert/convert.dart';
import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';
import '../models/db_provider.dart';
import 'package:app/global.dart';
import 'package:keychat_rust_ffi_plugin/api_signal.dart' as rustSignal;

part 'signal_id.g.dart';

@Collection(ignore: {
  'props',
})
// ignore: must_be_immutable
class SignalId extends Equatable {
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('identityId')])
  late String pubkey;
  late String prikey;
  late int identityId;

  bool isUsed = false;
  bool needDelete = false;
  int? signalKeyId;

  late DateTime createdAt;
  late DateTime updatedAt;

  SignalId(
      {required this.prikey, required this.identityId, required this.pubkey}) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  @override
  List get props => [id, pubkey, prikey];
}

Future createSignalId(int identityId) async {
  Isar database = DBProvider.database;
  var keychain = await rustSignal.generateSignalIds();
  var signalId = SignalId(
      prikey: hex.encode(keychain.$1),
      identityId: identityId,
      pubkey: hex.encode(keychain.$2))
    ..isUsed = false;
  await database.writeTxn(() async {
    await database.signalIds.put(signalId);
  });
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

SignalId? getSignalIdByPubkey(String pubkey) {
  return DBProvider.database.signalIds
      .filter()
      .pubkeyEqualTo(pubkey)
      .findFirstSync();
}

SignalId? getSignalIdByKeyId(int signalKeyId) {
  return DBProvider.database.signalIds
      .filter()
      .signalKeyIdEqualTo(signalKeyId)
      .findFirstSync();
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
