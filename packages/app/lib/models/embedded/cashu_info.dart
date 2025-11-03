import 'dart:convert' show jsonEncode;

import 'package:keychat_rust_ffi_plugin/api_cashu/types.dart';
import 'package:isar_community/isar.dart';
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
  String? id;
  String? unit;
  String? memo;
  String? hash;
  DateTime? expiredAt;

  CashuInfoModel();

  @override
  toString() => jsonEncode(toJson());

  factory CashuInfoModel.fromJson(Map<String, dynamic> json) =>
      _$CashuInfoModelFromJson(json);

  Map<String, dynamic> toJson() => _$CashuInfoModelToJson(this);

  static CashuInfoModel fromRustModel(Transaction ct) {
    return CashuInfoModel()
      ..id = ct.id
      ..status = ct.status
      ..amount = ct.amount.toInt()
      ..token = ct.token
      ..mint = ct.mintUrl;
  }

  Transaction toCashuTransaction() {
    Transaction ct = Transaction(
        id: id ?? '',
        status: status,
        amount: BigInt.from(amount),
        token: token,
        mintUrl: mint,
        io: TransactionDirection.outgoing,
        timestamp: BigInt.from(DateTime.now().millisecondsSinceEpoch),
        kind: TransactionKind.cashu,
        fee: BigInt.from(0),
        metadata: {});
    return ct;
  }
}
