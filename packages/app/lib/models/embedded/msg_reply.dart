import 'dart:convert' show jsonEncode;

import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'msg_reply.g.dart';

@JsonSerializable(includeIfNull: false)
@embedded
class MsgReply {
  MsgReply();

  factory MsgReply.fromJson(Map<String, dynamic> json) {
    // Clone so we don't mutate the caller's map with legacy-key fallbacks.
    final data = {...json};
    // Support legacy field names: id -> eventId, user -> userId
    if (data.containsKey('id') && !data.containsKey('eventId')) {
      data['eventId'] = data['id'];
    }
    if (data.containsKey('user') && !data.containsKey('userId')) {
      data['userId'] = data['user'];
    }
    return _$MsgReplyFromJson(data);
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
