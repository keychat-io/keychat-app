import 'dart:convert' show jsonEncode;

import 'package:json_annotation/json_annotation.dart';

part 'group_invitation_request_model.g.dart';

@JsonSerializable(includeIfNull: false)
class GroupInvitationRequestModel {
  String roomPubkey;
  String name;
  String myPubkey;
  String myName;
  int time;
  String mlsPK;
  String sig;
  GroupInvitationRequestModel(
      {required this.name,
      required this.roomPubkey,
      required this.myPubkey,
      required this.myName,
      required this.mlsPK,
      required this.time,
      required this.sig});
  factory GroupInvitationRequestModel.fromJson(Map<String, dynamic> json) =>
      _$GroupInvitationRequestModelFromJson(json);

  @override
  toString() {
    return jsonEncode(toJson());
  }

  Map<String, dynamic> toJson() => _$GroupInvitationRequestModelToJson(this);
}
