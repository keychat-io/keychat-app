import 'dart:convert' show jsonEncode;

import 'package:app/service/file.service.dart';
import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'msg_file_info.g.dart';

enum FileStatus { init, downloading, downloaded, decryptSuccess, failed }

@JsonSerializable(includeIfNull: false)
@embedded
class MsgFileInfo {
  String? localPath;
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

  MsgFileInfo();

  @override
  toString() => jsonEncode(toJson());

  String get fileName =>
      (localPath ?? sourceName ?? url)?.split('/').last ?? '';

  factory MsgFileInfo.fromJson(Map<String, dynamic> json) =>
      _$MsgFileInfoFromJson(json);

  Map<String, dynamic> toJson() => _$MsgFileInfoToJson(this);

  String getUriString(String type, FileEncryptInfo data) {
    final Map<String, dynamic> queryParams = {
      'kctype': type,
      'suffix': data.suffix,
      'key': data.key,
      'iv': data.iv,
      'size': data.size,
      'hash': data.hash,
      'sourceName': data.sourceName
    };
    Uri base = Uri.parse(data.url!);
    Uri uri = Uri.https(base.host, base.path,
        queryParams.map((key, value) => MapEntry(key, value.toString())));
    return uri.toString();
  }
}
