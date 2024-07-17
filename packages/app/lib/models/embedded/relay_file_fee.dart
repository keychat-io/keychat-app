import 'package:json_annotation/json_annotation.dart';

part 'relay_file_fee.g.dart';

@JsonSerializable(includeIfNull: false)
class RelayFileFee {
  int maxSize = 0;
  List prices = [];
  List mints = [];
  String unit = 'sat';
  String expired = '-';

  RelayFileFee();

  factory RelayFileFee.fromJson(Map<String, dynamic> json) =>
      _$RelayFileFeeFromJson(json);

  Map<String, dynamic> toJson() => _$RelayFileFeeToJson(this);
}
