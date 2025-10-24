// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bot_client_message_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BotClientMessageModel _$BotClientMessageModelFromJson(
        Map<String, dynamic> json) =>
    BotClientMessageModel(
      type: $enumDecode(_$MessageMediaTypeEnumMap, json['type']),
      message: json['message'] as String,
      id: json['id'] as String?,
      priceModel: json['priceModel'] as String?,
      payToken: json['payToken'] as String?,
    );

Map<String, dynamic> _$BotClientMessageModelToJson(
        BotClientMessageModel instance) =>
    <String, dynamic>{
      'type': _$MessageMediaTypeEnumMap[instance.type]!,
      'message': instance.message,
      if (instance.id case final value?) 'id': value,
      if (instance.priceModel case final value?) 'priceModel': value,
      if (instance.payToken case final value?) 'payToken': value,
    };

const _$MessageMediaTypeEnumMap = {
  MessageMediaType.text: 'text',
  MessageMediaType.cashu: 'cashu',
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
  MessageMediaType.groupInvitationInfo: 'groupInvitationInfo',
  MessageMediaType.groupInvitationRequesting: 'groupInvitationRequesting',
  MessageMediaType.lightningInvoice: 'lightningInvoice',
};
