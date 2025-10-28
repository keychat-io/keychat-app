import 'dart:convert' show jsonEncode;

import 'package:json_annotation/json_annotation.dart';

part 'profile_request_model.g.dart';

@JsonSerializable(includeIfNull: false)
class ProfileRequestModel {
  ProfileRequestModel({
    required this.pubkey,
    required this.name,
    this.avatar,
    this.lightning,
    this.bio,
    this.note,
  });
  factory ProfileRequestModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileRequestModelFromJson(json);
  String name;
  String pubkey;
  String? avatar;
  String? lightning;
  String? bio;
  String? note;

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  Map<String, dynamic> toJson() => _$ProfileRequestModelToJson(this);
}
