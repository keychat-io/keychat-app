import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ecash_bill.g.dart';

@JsonSerializable(includeIfNull: false)
@Collection(ignore: {'props'})
// ignore: must_be_immutable
class EcashBill extends Equatable {
  Id id = Isar.autoIncrement;

  late int roomId;
  late String token;
  late int amount;
  late String unit;
  late DateTime createdAt;
  bool isSend = true;

  EcashBill(
      {required this.roomId,
      required this.token,
      required this.amount,
      required this.unit,
      required this.createdAt});

  @override
  List<Object> get props => [id, roomId, amount, token];

  factory EcashBill.fromJson(Map<String, dynamic> json) =>
      _$EcashBillFromJson(json);

  Map<String, dynamic> toJson() => _$EcashBillToJson(this);
}
