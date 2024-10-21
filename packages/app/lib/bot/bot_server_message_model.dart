import 'package:app/models/message.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bot_server_message_model.freezed.dart';
part 'bot_server_message_model.g.dart';

@freezed
class BotServerMessageModel with _$BotServerMessageModel {
  const factory BotServerMessageModel(
      {
      // botText,botSelectionRequest,botPricePerMessageRequest,botOneTimePaymentRequest,
      required MessageMediaType type,
      required String message,
      required List<BotMessageData> priceModels,
      String? id}) = _BotServerMessageModel;

  const BotServerMessageModel._();

  factory BotServerMessageModel.fromJson(Map<String, dynamic> json) =>
      _$BotServerMessageModelFromJson(json);
}

@freezed
class BotMessageData with _$BotMessageData {
  const factory BotMessageData(
      {required String name,
      required String description,
      required int price,
      required String unit,
      @Default([]) List<String> mints}) = _BotMessageData;

  factory BotMessageData.fromJson(Map<String, dynamic> json) =>
      _$BotMessageDataFromJson(json);
}
