import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'mykey.g.dart';

@Collection(ignore: {
  'props',
})
// ignore: must_be_immutable
class Mykey extends Equatable {
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('identityId')])
  late String pubkey;
  late int identityId;

  late String prikey;
  int? roomId; // this mykey is used in which room

  // this is used for oneTime Key
  bool isOneTime = false;
  bool oneTimeUsed = false;
  bool needDelete = false;

  late DateTime createdAt;
  late DateTime updatedAt;

  Mykey(
      {required this.prikey, required this.identityId, required this.pubkey}) {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }

  @override
  List get props => [id, pubkey, prikey];
}
