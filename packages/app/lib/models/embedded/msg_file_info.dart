import 'dart:convert' show jsonEncode;

import 'package:keychat/service/file.service.dart';
import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'msg_file_info.g.dart';

enum FileStatus { init, downloading, downloaded, decryptSuccess, failed }

@JsonSerializable(includeIfNull: false)
@embedded
class MsgFileInfo {
  MsgFileInfo();

  factory MsgFileInfo.fromJson(Map<String, dynamic> json) =>
      _$MsgFileInfoFromJson(json);
  String? localPath; // relative path in app folder
  String? url;

  @Enumerated(EnumType.ordinal32)
  FileStatus status = FileStatus.init;
  String? type;
  String? suffix;
  int size = 0;
  DateTime? updateAt;
  String? iv;
  String? key;
  String? ecashToken;
  String? hash; // sha256
  String? sourceName;

  @JsonKey(includeFromJson: false, includeToJson: false)
  @ignore
  FileEncryptInfo? fileInfo;

  @override
  String toString() => jsonEncode(toJson());

  String get fileName =>
      (localPath ?? sourceName ?? url)?.split('/').last ?? '';

  Map<String, dynamic> toJson() => _$MsgFileInfoToJson(this);

  String getUriString(String type) {
    final queryParams = <String, dynamic>{
      'kctype': type,
      'suffix': fileInfo?.suffix,
      'key': fileInfo?.key,
      'iv': fileInfo?.iv,
      'size': fileInfo?.size,
      'hash': fileInfo?.hash,
      'sourceName': fileInfo?.sourceName,
    };
    final base = Uri.parse(fileInfo?.url ?? '');
    final uri = Uri.https(
      base.host,
      base.path,
      queryParams.map((key, value) => MapEntry(key, value.toString())),
    );
    return uri.toString();
  }
}
