import 'package:keychat/models/message.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bot_client_message_model.g.dart';

@JsonSerializable()
class BotClientMessageModel {
  const BotClientMessageModel({
    required this.type,
    required this.message,
    this.id,
    this.priceModel,
    this.payToken,
  });

  factory BotClientMessageModel.fromJson(Map<String, dynamic> json) =>
      _$BotClientMessageModelFromJson(json);
  final MessageMediaType type;
  final String message;
  @JsonKey(includeIfNull: false)
  final String? id;
  @JsonKey(includeIfNull: false)
  final String? priceModel;
  @JsonKey(includeIfNull: false)
  final String? payToken;

  Map<String, dynamic> toJson() => _$BotClientMessageModelToJson(this);

  BotClientMessageModel copyWith({
    MessageMediaType? type,
    String? message,
    String? id,
    String? priceModel,
    String? payToken,
  }) {
    return BotClientMessageModel(
      type: type ?? this.type,
      message: message ?? this.message,
      id: id ?? this.id,
      priceModel: priceModel ?? this.priceModel,
      payToken: payToken ?? this.payToken,
    );
  }
}
