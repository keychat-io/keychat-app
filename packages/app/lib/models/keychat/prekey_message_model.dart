import 'dart:convert' show jsonEncode;

import 'package:json_annotation/json_annotation.dart';

part 'prekey_message_model.g.dart';

@JsonSerializable(includeIfNull: false)
class PrekeyMessageModel {
  late String nostrId;
  late String signalId;
  late int time;
  late String sig;
  late String name;
  late String message;
  @override
  String toString() => jsonEncode(toJson());

  PrekeyMessageModel(
      {required this.nostrId,
      required this.signalId,
      required this.time,
      required this.name,
      required this.sig,
      required this.message});
  factory PrekeyMessageModel.fromJson(Map<String, dynamic> json) =>
      _$PrekeyMessageModelFromJson(json);

  Map<String, dynamic> toJson() => _$PrekeyMessageModelToJson(this);
}
