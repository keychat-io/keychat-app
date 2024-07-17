import 'dart:convert' show jsonEncode;

import 'package:json_annotation/json_annotation.dart';

part 'group_message.g.dart';

@JsonSerializable(includeIfNull: false)
class GroupMessage {
  String message; // message
  String pubkey; // pubkey
  String? sig; //signature
  int? subtype; // subtype
  String? ext;

  GroupMessage({required this.message, required this.pubkey, this.sig});
  factory GroupMessage.fromJson(Map<String, dynamic> json) =>
      _$GroupMessageFromJson(json);

  @override
  toString() {
    return jsonEncode(toJson());
  }

  Map<String, dynamic> toJson() => _$GroupMessageToJson(this);
}
