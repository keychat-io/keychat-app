// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relay_message_fee.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RelayMessageFee _$RelayMessageFeeFromJson(Map<String, dynamic> json) =>
    RelayMessageFee()
      ..mints = (json['mints'] as List<dynamic>)
          .map((e) => e as String)
          .toList()
      ..amount = (json['amount'] as num).toInt()
      ..unit = $enumDecode(_$EcashTokenSymbolEnumMap, json['unit'])
      ..updatedAt = DateTime.parse(json['updatedAt'] as String);

Map<String, dynamic> _$RelayMessageFeeToJson(RelayMessageFee instance) =>
    <String, dynamic>{
      'mints': instance.mints,
      'amount': instance.amount,
      'unit': _$EcashTokenSymbolEnumMap[instance.unit]!,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$EcashTokenSymbolEnumMap = {
  EcashTokenSymbol.sat: 'sat',
  EcashTokenSymbol.usdt: 'usdt',
};
