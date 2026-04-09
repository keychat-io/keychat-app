import 'dart:io' show File;
import 'package:keychat/service/file.service.dart';
import 'package:keychat/service/identity.service.dart';
import 'package:keychat/service/secure_storage.dart';
import 'package:keychat/utils.dart';
import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:isar_community/isar.dart';

part 'identity.g.dart';

@Collection(
  ignore: {
    'props',
    'displayName',
    'mainMykey',
    'displayAbout',
    'signalIdentityKey',
    'nostrIdentityKey',
  },
)
// ignore: must_be_immutable
class Identity extends Equatable {
  // fetch from relay

  Identity({
    required this.name,
    required this.npub,
    required this.secp256k1PKHex, // Isar schema compat
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
  @Deprecated('Use nostrIdentityKey instead')
  late String secp256k1PKHex;

  @Deprecated('calculate by mnemonic and offset')
  String? secp256k1SKHex;
  late String npub;

  String name;
  String? about;
  String get displayName => name.trim();
  String? get displayAbout => about ?? aboutFromRelay;

  @Deprecated('Use signalIdentityKey instead')
  String? curve25519PkHex;

  // Semantic aliases (Isar fields kept for schema compat)

  /// The Nostr identity public key (secp256k1 hex).
  // ignore: deprecated_member_use_from_same_package
  String get nostrIdentityKey => secp256k1PKHex;
  // ignore: deprecated_member_use_from_same_package
  set nostrIdentityKey(String v) => secp256k1PKHex = v;

  /// The Signal protocol identity key (curve25519 hex, 33-byte with 0x05 prefix).
  // ignore: deprecated_member_use_from_same_package
  String? get signalIdentityKey => curve25519PkHex;
  // ignore: deprecated_member_use_from_same_package
  set signalIdentityKey(String? v) => curve25519PkHex = v;

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
  String? avatarFromRelayLocalPath;

  @override
  List<Object?> get props => [
    id,
    weight,
    isDefault,
    note,
    createdAt,
  ];

  Future<String> getNostrPrivateKey() async {
    return SecureStorage.instance.readPrikeyOrFail(nostrIdentityKey);
  }

  Future<String?> getSignalPrivateKey() async {
    if (signalIdentityKey == null) return null;
    return SecureStorage.instance.readCurve25519PrikeyOrFail(
      signalIdentityKey!,
    );
  }

  Future<String?> getMnemonic() async {
    if (index == -1) return null;
    return SecureStorage.instance.getPhraseWords();
  }

  Future<String?> getRemoteAvatarUrl() async {
    if (avatarLocalPath == null) return null;
    if (avatarUpdatedAt != null || avatarRemoteUrl != null) {
      if (DateTime.now().difference(avatarUpdatedAt!).inMinutes <= 10) {
        return avatarRemoteUrl;
      }
    }
    try {
      // expired but local file exists, re-upload
      final filePath = Utils.appFolder.path;
      final file = File(filePath + avatarLocalPath!);
      final exists = file.existsSync();
      if (!exists) return null;
      final mfi = await FileService.instance.encryptAndUploadImage(
        XFile(file.path),
        writeToLocal: false,
      );
      if (mfi == null) return null;
      mfi.sourceName = '';
      mfi.fileInfo?.sourceName = '';
      logger.d('Avatar uploaded: $mfi');
      avatarRemoteUrl = mfi.getUriString('image');
      avatarUpdatedAt = DateTime.now();
      await IdentityService.instance.updateIdentity(this);
      return avatarRemoteUrl;
    } catch (e, st) {
      logger.e('Failed $e', stackTrace: st);
    }
    return null;
  }

  Future<bool> updateLightningAddress(String? address) async {
    try {
      lightning = address?.trim();
      await IdentityService.instance.updateIdentity(this);
      return true;
    } catch (e, st) {
      logger.e('Failed to update lightning address: $e', stackTrace: st);
      return false;
    }
  }
}
