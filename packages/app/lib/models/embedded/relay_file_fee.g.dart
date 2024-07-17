// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relay_file_fee.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RelayFileFee _$RelayFileFeeFromJson(Map<String, dynamic> json) => RelayFileFee()
  ..maxSize = (json['maxSize'] as num).toInt()
  ..prices = json['prices'] as List<dynamic>
  ..mints = json['mints'] as List<dynamic>
  ..unit = json['unit'] as String
  ..expired = json['expired'] as String;

Map<String, dynamic> _$RelayFileFeeToJson(RelayFileFee instance) =>
    <String, dynamic>{
      'maxSize': instance.maxSize,
      'prices': instance.prices,
      'mints': instance.mints,
      'unit': instance.unit,
      'expired': instance.expired,
    };
