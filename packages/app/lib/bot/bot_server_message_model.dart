import 'package:app/models/message.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bot_server_message_model.g.dart';

@JsonSerializable()
class BotServerMessageModel {
  const BotServerMessageModel({
    required this.type,
    required this.message,
    required this.priceModels,
    this.id,
  });

  factory BotServerMessageModel.fromJson(Map<String, dynamic> json) =>
      _$BotServerMessageModelFromJson(json);
  // botText,botSelectionRequest,botPricePerMessageRequest,botOneTimePaymentRequest,
  final MessageMediaType type;
  final String message;
  final List<BotMessageData> priceModels;
  final String? id;

  Map<String, dynamic> toJson() => _$BotServerMessageModelToJson(this);
}

@JsonSerializable()
class BotMessageData {
  const BotMessageData({
    required this.name,
    required this.description,
    required this.price,
    required this.unit,
    this.mints = const [],
  });

  factory BotMessageData.fromJson(Map<String, dynamic> json) =>
      _$BotMessageDataFromJson(json);
  final String name;
  final String description;
  final int price;
  final String unit;
  @JsonKey(defaultValue: <String>[])
  final List<String> mints;

  Map<String, dynamic> toJson() => _$BotMessageDataToJson(this);
}
