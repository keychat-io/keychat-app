import 'package:keychat/service/contact.service.dart';
import 'package:equatable/equatable.dart';
import 'package:isar_community/isar.dart';
import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

part 'contact.g.dart';

@Collection(
  ignore: {
    'props',
    'displayName',
    'indexLetter',
    'isCheck',
    'admin',
    'imageAssets',
    'mlsPK',
    'displayAbout',
  },
)
// ignore: must_be_immutable
class Contact extends Equatable {
  Contact({required this.identityId, required this.pubkey, this.npubkey = ''}) {
    if (npubkey.isEmpty && pubkey.length == 64) {
      npubkey = rust_nostr.getBech32PubkeyByHex(hex: pubkey);
    }
    createdAt ??= DateTime.now();
    updatedAt ??= DateTime.now();
  }
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('identityId')])
  late String pubkey;
  String? curve25519PkHex;
  late String npubkey;
  late int identityId;
  String? metadata;
  String? petname; // My note
  String? name; // fetch from friend
  String? nameFromRelay; // fetch from relay
  String? avatarFromRelay; // fetch from relay
  String? avatarFromRelayLocalPath;
  DateTime? fetchFromRelayAt; // fetch time
  String? aboutFromRelay;
  String? metadataFromRelay; // fetch from relay
  int versionFromRelay = 0; // fetch from relay
  String? avatarLocalPath;
  String? avatarRemoteUrl;
  String? lightning;
  int version = 0;

  bool autoCreateFromGroup =
      false; // auto create contact when create group, if equal true,is my friends

  String? about;
  DateTime? createdAt;
  DateTime? updatedAt;
  String? get displayAbout =>
      about != null && about!.isNotEmpty ? about : aboutFromRelay;
  String get displayName {
    final nickname = petname ?? name ?? nameFromRelay;
    if (nickname == null || nickname.trim().isEmpty) {
      var max = npubkey.length;
      if (max > 8) {
        max = 8;
      }
      return npubkey.substring(0, max);
    } else {
      return nickname.trim();
    }
  }

  bool isCheck = false;
  bool admin = false;
  String get indexLetter => displayName[0];
  String? imageAssets;
  String? mlsPK;

  Future<void> saveNameIfNull(String newName) async {
    if (petname == null || name == null) {
      name = newName;
      await ContactService.instance.saveContact(this);
    }
  }

  @override
  List<Object?> get props => [
    id,
    pubkey,
    name,
    petname,
    about,
    avatarFromRelay,
    avatarLocalPath,
  ];
}
