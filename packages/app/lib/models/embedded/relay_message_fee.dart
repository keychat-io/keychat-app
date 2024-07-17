import 'package:json_annotation/json_annotation.dart';
import 'package:keychat_ecash/utils.dart';

part 'relay_message_fee.g.dart';

@JsonSerializable(includeIfNull: false)
class RelayMessageFee {
  List<String> mints = [];
  int amount = 0;

  EcashTokenSymbol unit = EcashTokenSymbol.sat;

  late DateTime updatedAt;

  RelayMessageFee() {
    updatedAt = DateTime.now();
  }
  static EcashTokenSymbol getSymbolByName(String name) {
    if (name == 'sat') return EcashTokenSymbol.sat;
    if (name == 'usdt') return EcashTokenSymbol.usdt;
    return EcashTokenSymbol.sat;
  }

  factory RelayMessageFee.fromJson(Map<String, dynamic> json) =>
      _$RelayMessageFeeFromJson(json);

  Map<String, dynamic> toJson() => _$RelayMessageFeeToJson(this);
}
