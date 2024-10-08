// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ClientMessageModelImpl _$$ClientMessageModelImplFromJson(
        Map<String, dynamic> json) =>
    _$ClientMessageModelImpl(
      type: $enumDecode(_$ClientMessageTypeEnumMap, json['type']),
      message: json['message'] as String,
      id: json['id'] as String?,
      priceModel: json['priceModel'] as String?,
      payToken: json['payToken'] as String?,
    );

Map<String, dynamic> _$$ClientMessageModelImplToJson(
    _$ClientMessageModelImpl instance) {
  final val = <String, dynamic>{
    'type': _$ClientMessageTypeEnumMap[instance.type]!,
    'message': instance.message,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('id', instance.id);
  writeNotNull('priceModel', instance.priceModel);
  writeNotNull('payToken', instance.payToken);
  return val;
}

const _$ClientMessageTypeEnumMap = {
  ClientMessageType.plain: 'plain',
  ClientMessageType.command: 'command',
  ClientMessageType.selectionResponse: 'selectionResponse',
  ClientMessageType.paymentResponse: 'paymentResponse',
};
