// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bot_server_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BotServerMessageModelImpl _$$BotServerMessageModelImplFromJson(
        Map<String, dynamic> json) =>
    _$BotServerMessageModelImpl(
      type: $enumDecode(_$MessageMediaTypeEnumMap, json['type']),
      message: json['message'] as String,
      priceModels: (json['priceModels'] as List<dynamic>)
          .map((e) => BotMessageData.fromJson(e as Map<String, dynamic>))
          .toList(),
      id: json['id'] as String?,
    );

Map<String, dynamic> _$$BotServerMessageModelImplToJson(
        _$BotServerMessageModelImpl instance) =>
    <String, dynamic>{
      'type': _$MessageMediaTypeEnumMap[instance.type]!,
      'message': instance.message,
      'priceModels': instance.priceModels,
      'id': instance.id,
    };

const _$MessageMediaTypeEnumMap = {
  MessageMediaType.text: 'text',
  MessageMediaType.cashuA: 'cashuA',
  MessageMediaType.image: 'image',
  MessageMediaType.video: 'video',
  MessageMediaType.contact: 'contact',
  MessageMediaType.pdf: 'pdf',
  MessageMediaType.setPostOffice: 'setPostOffice',
  MessageMediaType.groupInvite: 'groupInvite',
  MessageMediaType.file: 'file',
  MessageMediaType.groupInviteConfirm: 'groupInviteConfirm',
  MessageMediaType.botText: 'botText',
  MessageMediaType.botPricePerMessageRequest: 'botPricePerMessageRequest',
  MessageMediaType.botSelectionRequest: 'botSelectionRequest',
  MessageMediaType.botOneTimePaymentRequest: 'botOneTimePaymentRequest',
};

_$BotMessageDataImpl _$$BotMessageDataImplFromJson(Map<String, dynamic> json) =>
    _$BotMessageDataImpl(
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toInt(),
      unit: json['unit'] as String,
      mints:
          (json['mints'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
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
