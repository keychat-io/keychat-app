import 'dart:convert' show jsonEncode;

import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cashu_info.g.dart';

@embedded
@JsonSerializable(includeIfNull: false)
class CashuInfoModel {
  late String mint;
  late String token;
  late int amount;

  @Enumerated(EnumType.ordinal32)
  @JsonKey(includeToJson: false, includeFromJson: false)
  TransactionStatus status = TransactionStatus.pending;

  @JsonKey(includeToJson: false, includeFromJson: false)
  String? id;
  String? unit;
  String? memo;

  CashuInfoModel();

  @override
  toString() => jsonEncode(toJson());

  factory CashuInfoModel.fromJson(Map<String, dynamic> json) =>
      _$CashuInfoModelFromJson(json);

  Map<String, dynamic> toJson() => _$CashuInfoModelToJson(this);

  static CashuInfoModel fromRustModel(CashuTransaction ct) {
    return CashuInfoModel()
      ..id = ct.id
      ..status = ct.status
      ..amount = ct.amount.toInt()
      ..token = ct.token
      ..mint = ct.mint;
  }

  CashuTransaction toCashuTransaction() {
    CashuTransaction ct = CashuTransaction(
        id: id ?? '',
        status: status,
        amount: BigInt.from(amount),
        token: token,
        mint: mint,
        io: TransactionDirection.out,
        time: BigInt.from(DateTime.now().millisecondsSinceEpoch));
    return ct;
  }
}
