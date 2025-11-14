import 'dart:convert' show jsonEncode;

import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'msg_reply.g.dart';

@JsonSerializable(includeIfNull: false)
@embedded
class MsgReply {
  // for pairwise group
  MsgReply();

  factory MsgReply.fromJson(Map<String, dynamic> json) =>
      _$MsgReplyFromJson(json);
  String? id;
  late String user;
  late String content;

  @override
  String toString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => _$MsgReplyToJson(this);
}
