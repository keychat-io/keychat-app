import 'package:app/models/message.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bot_message_model.freezed.dart';
part 'bot_message_model.g.dart';

enum ServerMessageType {
  botText,
  botSelectionRequest,
  botPricePerMessageRequest,
  botOneTimePaymentRequest,
}

@freezed
class BotMessageModel with _$BotMessageModel {
  const factory BotMessageModel(
      {required ServerMessageType type,
      required String message,
      required List<BotMessageData> priceModels,
      String? id}) = _BotMessageModel;

  const BotMessageModel._();

  factory BotMessageModel.fromJson(Map<String, dynamic> json) =>
      _$BotMessageModelFromJson(json);

  MessageMediaType getMessageType() {
    switch (type) {
      case ServerMessageType.botSelectionRequest:
        return MessageMediaType.botSelectionRequest;
      case ServerMessageType.botPricePerMessageRequest:
        return MessageMediaType.botPricePerMessageRequest;
      case ServerMessageType.botOneTimePaymentRequest:
        return MessageMediaType.botOneTimePaymentRequest;
      default:
        return MessageMediaType.botText;
    }
  }
}

@freezed
class BotMessageData with _$BotMessageData {
  const factory BotMessageData(
      {required String name,
      required String description,
      required int price,
      required String unit,
      required List<String> mints}) = _BotMessageData;

  factory BotMessageData.fromJson(Map<String, dynamic> json) =>
      _$BotMessageDataFromJson(json);
}
