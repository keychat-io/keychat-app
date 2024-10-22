// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bot_client_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BotClientMessageModelImpl _$$BotClientMessageModelImplFromJson(
        Map<String, dynamic> json) =>
    _$BotClientMessageModelImpl(
      type: $enumDecode(_$MessageMediaTypeEnumMap, json['type']),
      message: json['message'] as String,
      id: json['id'] as String?,
      priceModel: json['priceModel'] as String?,
      payToken: json['payToken'] as String?,
    );

Map<String, dynamic> _$$BotClientMessageModelImplToJson(
    _$BotClientMessageModelImpl instance) {
  final val = <String, dynamic>{
    'type': _$MessageMediaTypeEnumMap[instance.type]!,
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
