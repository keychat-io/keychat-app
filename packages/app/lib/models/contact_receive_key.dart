import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'contact_receive_key.g.dart';

@Collection(ignore: {
  'props',
})
// ignore: must_be_immutable
class ContactReceiveKey extends Equatable {
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('identityId')])
  late String pubkey;
  late int identityId;
  bool isMute = false;
  List<String> receiveKeys = [];
  List<String> removeReceiveKeys = [];
  int roomId = -1;

  ContactReceiveKey({
    required this.identityId,
    required this.pubkey,
  });

  @override
  List<Object?> get props => [id, receiveKeys, false, removeReceiveKeys];
}
