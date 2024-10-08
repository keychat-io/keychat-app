// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bot_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BotMessageModelImpl _$$BotMessageModelImplFromJson(
        Map<String, dynamic> json) =>
    _$BotMessageModelImpl(
      type: $enumDecode(_$ServerMessageTypeEnumMap, json['type']),
      message: json['message'] as String,
      priceModels: (json['priceModels'] as List<dynamic>)
          .map((e) => BotMessageData.fromJson(e as Map<String, dynamic>))
          .toList(),
      id: json['id'] as String?,
    );

Map<String, dynamic> _$$BotMessageModelImplToJson(
        _$BotMessageModelImpl instance) =>
    <String, dynamic>{
      'type': _$ServerMessageTypeEnumMap[instance.type]!,
      'message': instance.message,
      'priceModels': instance.priceModels,
      'id': instance.id,
    };

const _$ServerMessageTypeEnumMap = {
  ServerMessageType.botText: 'botText',
  ServerMessageType.botSelectionRequest: 'botSelectionRequest',
  ServerMessageType.botPricePerMessageRequest: 'botPricePerMessageRequest',
  ServerMessageType.botOneTimePaymentRequest: 'botOneTimePaymentRequest',
};

_$BotMessageDataImpl _$$BotMessageDataImplFromJson(Map<String, dynamic> json) =>
    _$BotMessageDataImpl(
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toInt(),
      unit: json['unit'] as String,
      mints: (json['mints'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$$BotMessageDataImplToJson(
        _$BotMessageDataImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'price': instance.price,
      'unit': instance.unit,
      'mints': instance.mints,
    };
