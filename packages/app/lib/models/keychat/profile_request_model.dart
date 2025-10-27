import 'dart:convert' show jsonEncode;

import 'package:json_annotation/json_annotation.dart';

part 'profile_request_model.g.dart';

@JsonSerializable(includeIfNull: false)
class ProfileRequestModel {
  ProfileRequestModel({
    required this.pubkey,
    required this.name,
    this.avatar,
    this.lightningAddress,
    this.note,
    this.note2,
  });
  factory ProfileRequestModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileRequestModelFromJson(json);
  String name;
  String pubkey;
  String? avatar;
  String? lightningAddress;
  String? note;
  String? note2;

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  Map<String, dynamic> toJson() => _$ProfileRequestModelToJson(this);
}
