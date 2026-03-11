import 'dart:convert' show jsonEncode;

import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'msg_reply.g.dart';

@JsonSerializable(includeIfNull: false)
@embedded
class MsgReply {
  MsgReply();

  factory MsgReply.fromJson(Map<String, dynamic> json) {
    // Support legacy field names: id -> eventId, user -> userId
    if (json.containsKey('id') && !json.containsKey('eventId')) {
      json['eventId'] = json['id'];
    }
    if (json.containsKey('user') && !json.containsKey('userId')) {
      json['userId'] = json['user'];
    }
    return _$MsgReplyFromJson(json);
  }

  String? eventId;
  late String content;
  String? userId;
  String? userName;

  @override
  String toString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() {
    final json = _$MsgReplyToJson(this);
    // Output legacy fields for backward compatibility
    json['id'] = eventId;
    json['user'] = userId ?? '';
    return json;
  }
}
