import 'dart:convert' show jsonEncode;

import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:isar_community/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cashu_info.g.dart';

@embedded
@JsonSerializable(includeIfNull: false)
class CashuInfoModel {
  CashuInfoModel();

  factory CashuInfoModel.fromJson(Map<String, dynamic> json) =>
      _$CashuInfoModelFromJson(json);
  late String mint;
  late String token;
  late int amount;

  @Enumerated(EnumType.ordinal32)
  @JsonKey(includeToJson: false, includeFromJson: false)
  TransactionStatus status = TransactionStatus.pending;
  String? id;
  String? unit;
  String? memo;
  String? hash;
  DateTime? expiredAt;

  @override
  String toString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => _$CashuInfoModelToJson(this);

  static CashuInfoModel fromRustModel(Transaction ct) {
    return CashuInfoModel()
      ..id = ct.id
      ..status = ct.status
      ..amount = ct.amount.toInt()
      ..token = ct.token
      ..mint = ct.mintUrl;
  }
}
