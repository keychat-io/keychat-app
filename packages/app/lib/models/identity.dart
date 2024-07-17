import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'identity.g.dart';

@Collection(ignore: {'props', 'displayName', 'mainMykey'})
// ignore: must_be_immutable
class Identity extends Equatable {
  Id id = Isar.autoIncrement;
  int weight = 0;
  bool isDefault = false;
  late String mnemonic;
  late List<byte> curve25519Sk;
  late List<byte> curve25519Pk;
  late String curve25519SkHex;
  late String secp256k1PKHex;
  late String secp256k1SKHex;
  late String npub;
  late String nsec;
  String name;
  String? about;
  String get displayName => name;

  @Index(unique: true)
  late String curve25519PkHex;

  String? note;
  late DateTime createdAt;

  Identity({
    required this.name,
    required this.mnemonic,
    required this.secp256k1PKHex,
    required this.secp256k1SKHex,
    required this.npub,
    required this.nsec,
    required this.curve25519Sk,
    required this.curve25519Pk,
    required this.curve25519SkHex,
    required this.curve25519PkHex,
    this.note,
  }) {
    createdAt = DateTime.now();
  }

  @override
  List get props => [
        id,
        curve25519Pk,
        weight,
        isDefault,
        note,
        createdAt,
      ];
}
