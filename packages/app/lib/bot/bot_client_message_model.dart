import 'package:app/models/message.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bot_client_message_model.freezed.dart';
part 'bot_client_message_model.g.dart';

@freezed
class BotClientMessageModel with _$BotClientMessageModel {
  const factory BotClientMessageModel({
    required MessageMediaType type,
    required String message,
    @JsonKey(includeIfNull: false) String? id,
    @JsonKey(includeIfNull: false) String? priceModel,
    @JsonKey(includeIfNull: false) String? payToken,
  }) = _BotClientMessageModel;

  factory BotClientMessageModel.fromJson(Map<String, dynamic> json) =>
      _$BotClientMessageModelFromJson(json);
}
