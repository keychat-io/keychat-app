import 'package:equatable/equatable.dart';
import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'message_bill.g.dart';

@JsonSerializable(includeIfNull: false)
@Collection(ignore: {
  'props',
})
// ignore: must_be_immutable
class MessageBill extends Equatable {
  Id id = Isar.autoIncrement;

  late int roomId;
  late String eventId;
  late double amount;
  late String relay;

  @Index(unique: true)
  late String cashuA;
  late DateTime createdAt;

  MessageBill(
      {required this.roomId,
      required this.eventId,
      required this.amount,
      required this.relay,
      required this.cashuA,
      required this.createdAt});

  @override
  List<Object> get props => [id, roomId, eventId, amount, relay, cashuA];

  factory MessageBill.fromJson(Map<String, dynamic> json) =>
      _$MessageBillFromJson(json);

  Map<String, dynamic> toJson() => _$MessageBillToJson(this);
}
