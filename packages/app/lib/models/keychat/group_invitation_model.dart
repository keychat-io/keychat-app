import 'dart:convert' show jsonEncode;

import 'package:json_annotation/json_annotation.dart';

part 'group_invitation_model.g.dart';

@JsonSerializable(includeIfNull: false)
class GroupInvitationModel {
  String name;
  String pubkey;
  String sender;
  int time;
  String sig;
  GroupInvitationModel(
      {required this.name,
      required this.pubkey,
      required this.sender,
      required this.time,
      required this.sig});
  factory GroupInvitationModel.fromJson(Map<String, dynamic> json) =>
      _$GroupInvitationModelFromJson(json);

  @override
  toString() {
    return jsonEncode(toJson());
  }

  Map<String, dynamic> toJson() => _$GroupInvitationModelToJson(this);
}
