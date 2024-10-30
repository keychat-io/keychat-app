import 'package:keychat_rust_ffi_plugin/api_nostr.dart' as rust_nostr;

import 'package:app/service/contact.service.dart';
import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';

part 'contact.g.dart';

@Collection(ignore: {
  'props',
  'displayName',
  'indexLetter',
  'isCheck',
  'admin',
  'imageAssets'
})
// ignore: must_be_immutable
class Contact extends Equatable {
  Id id = Isar.autoIncrement;

  @Index(unique: true, composite: [CompositeIndex('identityId')])
  late String pubkey;
  String? curve25519PkHex;
  late String npubkey;
  late int identityId;
  String? metadata;

  String? petname; // My note
  String? name; // fetch from friend

  String? about;
  String? picture;
  DateTime? createdAt;
  DateTime? updatedAt;

  String get displayName {
    String? nickname = petname ?? name;
    if (nickname == null || nickname.trim().isEmpty) {
      int max = npubkey.length;
      if (max > 8) {
        max = 8;
      }
      return npubkey.substring(0, max);
    } else {
      return nickname;
    }
  }

  bool isCheck = false;
  bool admin = false;
  String get indexLetter => displayName[0];
  String? imageAssets;

  Contact({
    required this.identityId,
    required this.npubkey,
    required this.pubkey,
  }) {
    if (npubkey.isEmpty && pubkey.length == 64) {
      npubkey = rust_nostr.getBech32PubkeyByHex(hex: pubkey);
    }
    createdAt ??= DateTime.now();
    updatedAt ??= DateTime.now();
  }

  Future saveNameIfNull(String newName) async {
    if (petname == null || name == null) {
      name = newName;
      await ContactService().saveContact(this);
    }
  }

  @override
  List<Object?> get props => [
        id,
        pubkey,
        npubkey,
        name,
        petname,
        about,
        createdAt,
        picture,
        updatedAt
      ];
}
