import 'dart:io' show File;

import 'package:app/controller/setting.controller.dart';
import 'package:app/models/embedded/msg_file_info.dart';
import 'package:app/service/file.service.dart';
import 'package:app/service/identity.service.dart';
import 'package:app/service/secure_storage.dart';
import 'package:app/utils.dart';
import 'package:equatable/equatable.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar_community/isar.dart';

part 'identity.g.dart';

@Collection(ignore: {'props', 'displayName', 'mainMykey', 'displayAbout'})
// ignore: must_be_immutable
class Identity extends Equatable {
  // fetch from relay

  Identity({
    required this.name,
    required this.npub,
    required this.secp256k1PKHex,
    this.note,
  }) {
    createdAt = DateTime.now();
  }
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
  String? lightning;
  String? avatarLocalPath; // local avatar path
  String? avatarRemoteUrl; // remote avatar url
  DateTime? avatarUpdatedAt; // avatar update time. expired 14 days

  int index = 0;

  bool enableChat = true;
  bool enableBrowser = true;
  bool isFromSigner = false;

  String? nameFromRelay; // fetch from relay
  String? avatarFromRelay; // fetch from relay
  DateTime? fetchFromRelayAt; // fetch time
  String? aboutFromRelay; // fetch from relay
  String? metadataFromRelay; // fetch from relay
  int versionFromRelay = 0;

  @override
  List get props => [
        id,
        weight,
        isDefault,
        note,
        createdAt,
      ];

  Future<String> getSecp256k1SKHex() async {
    return SecureStorage.instance.readPrikeyOrFail(secp256k1PKHex);
  }

  Future<String?> getCurve25519SkHex() async {
    if (curve25519PkHex == null) return null;
    return SecureStorage.instance.readCurve25519PrikeyOrFail(curve25519PkHex!);
  }

  Future<String?> getMnemonic() async {
    if (index == -1) return null;
    return SecureStorage.instance.getPhraseWords();
  }

  Future<String?> getRemoteAvatarUrl() async {
    if (avatarUpdatedAt == null || avatarRemoteUrl == null) return null;

    if (DateTime.now().difference(avatarUpdatedAt!).inDays <= 14) {
      return avatarRemoteUrl;
    }
    if (avatarLocalPath == null) return null;
    try {
      // expired but local file exists, re-upload
      final filePath = Utils.appFolder.path;
      final file = File(filePath + avatarLocalPath!);
      final exists = file.existsSync();
      if (!exists) return null;
      final mfi = await FileService.instance
          .encryptAndUploadImage(XFile(file.path), writeToLocal: false);
      if (mfi == null) return null;
      mfi.sourceName = '';
      logger.d('Avatar uploaded: $mfi');
      avatarRemoteUrl = mfi.getUriString('image');
      avatarUpdatedAt = DateTime.now();
      avatarLocalPath = mfi.localPath;
      await IdentityService.instance.updateIdentity(this);
      return avatarRemoteUrl;
    } catch (e, st) {
      logger.e('Failed $e', stackTrace: st);
    }
    return null;
  }
}
