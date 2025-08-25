import 'package:equatable/equatable.dart';
import 'package:isar_community/isar.dart';

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
  bool isGroupSharedKey = false;
  int? signalKeyId;
  String? keys; // Map<String,any>

  late DateTime createdAt;
  late DateTime updatedAt;

  SignalId(
      {required this.pubkey, required this.prikey, required this.identityId}) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  @override
  List get props => [
        id,
        pubkey,
        prikey,
        identityId,
        isUsed,
        needDelete,
        signalKeyId,
      ];
}
