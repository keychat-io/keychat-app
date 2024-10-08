import 'package:freezed_annotation/freezed_annotation.dart';

part 'client_message_model.freezed.dart';
part 'client_message_model.g.dart';

@freezed
class ClientMessageModel with _$ClientMessageModel {
  const factory ClientMessageModel({
    required ClientMessageType type,
    required String message,
    @JsonKey(includeIfNull: false) String? id,
    @JsonKey(includeIfNull: false) String? priceModel,
    @JsonKey(includeIfNull: false) String? payToken,
  }) = _ClientMessageModel;

  factory ClientMessageModel.fromJson(Map<String, dynamic> json) =>
      _$ClientMessageModelFromJson(json);
}

enum ClientMessageType {
  plain,
  command,
  selectionResponse,
  paymentResponse,
}
