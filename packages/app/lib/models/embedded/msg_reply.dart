import 'dart:convert' show jsonEncode;

import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'msg_reply.g.dart';

@JsonSerializable(includeIfNull: false)
@embedded
class MsgReply {
  String? id;
  late String user;
  late String content; // for pairwise group
  MsgReply();

  @override
  toString() => jsonEncode(toJson());

  factory MsgReply.fromJson(Map<String, dynamic> json) =>
      _$MsgReplyFromJson(json);

  Map<String, dynamic> toJson() => _$MsgReplyToJson(this);
}
