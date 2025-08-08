import 'package:app/service/secure_storage.dart';
import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'identity.g.dart';

@Collection(ignore: {'props', 'displayName', 'mainMykey', 'displayAbout'})
// ignore: must_be_immutable
class Identity extends Equatable {
  Id id = Isar.autoIncrement;
  int weight = 0;
  bool isDefault = false;

  @Deprecated('mnemonic is stored in the keychain')
  String? mnemonic;

  @Deprecated('calculate by mnemonic and offset')
  String? curve25519SkHex;

  @Index(unique: true)
  late String secp256k1PKHex;

  @Deprecated('calculate by mnemonic and offset')
  String? secp256k1SKHex;
  late String npub;

  String name;
  String? about;
  String get displayName => name.trim();
  String? get displayAbout => aboutFromRelay ?? about;

  String? curve25519PkHex;

  String? note;
  late DateTime createdAt;
  String? metadata;

  int index = 0;

  bool enableChat = true;
  bool enableBrowser = true;
  bool isFromSigner = false;

  String? nameFromRelay; // fetch from relay
  String? avatarFromRelay; // fetch from relay
  DateTime? fetchFromRelayAt; // fetch time
  String? aboutFromRelay; // fetch from relay
  String? metadataFromRelay; // fetch from relay
  int versionFromRelay = 0; // fetch from relay

  Identity({
    required this.name,
    required this.npub,
    required this.secp256k1PKHex,
    this.note,
  }) {
    createdAt = DateTime.now();
  }

  @override
  List get props => [
        id,
        weight,
        isDefault,
        note,
        createdAt,
      ];

  Future<String> getSecp256k1SKHex() async {
    return await SecureStorage.instance.readPrikeyOrFail(secp256k1PKHex);
  }

  Future<String?> getCurve25519SkHex() async {
    if (curve25519PkHex == null) return null;
    return await SecureStorage.instance
        .readCurve25519PrikeyOrFail(curve25519PkHex!);
  }

  Future<String?> getMnemonic() async {
    if (index == -1) return null;
    return await SecureStorage.instance.getPhraseWords();
  }
}
