// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bot_client_message_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

BotClientMessageModel _$BotClientMessageModelFromJson(
    Map<String, dynamic> json) {
  return _BotClientMessageModel.fromJson(json);
}

/// @nodoc
mixin _$BotClientMessageModel {
  MessageMediaType get type => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  @JsonKey(includeIfNull: false)
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(includeIfNull: false)
  String? get priceModel => throw _privateConstructorUsedError;
  @JsonKey(includeIfNull: false)
  String? get payToken => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BotClientMessageModelCopyWith<BotClientMessageModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BotClientMessageModelCopyWith<$Res> {
  factory $BotClientMessageModelCopyWith(BotClientMessageModel value,
          $Res Function(BotClientMessageModel) then) =
      _$BotClientMessageModelCopyWithImpl<$Res, BotClientMessageModel>;
  @useResult
  $Res call(
      {MessageMediaType type,
      String message,
      @JsonKey(includeIfNull: false) String? id,
      @JsonKey(includeIfNull: false) String? priceModel,
      @JsonKey(includeIfNull: false) String? payToken});
}

/// @nodoc
class _$BotClientMessageModelCopyWithImpl<$Res,
        $Val extends BotClientMessageModel>
    implements $BotClientMessageModelCopyWith<$Res> {
  _$BotClientMessageModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? message = null,
    Object? id = freezed,
    Object? priceModel = freezed,
    Object? payToken = freezed,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MessageMediaType,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      priceModel: freezed == priceModel
          ? _value.priceModel
          : priceModel // ignore: cast_nullable_to_non_nullable
              as String?,
      payToken: freezed == payToken
          ? _value.payToken
          : payToken // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BotClientMessageModelImplCopyWith<$Res>
    implements $BotClientMessageModelCopyWith<$Res> {
  factory _$$BotClientMessageModelImplCopyWith(
          _$BotClientMessageModelImpl value,
          $Res Function(_$BotClientMessageModelImpl) then) =
      __$$BotClientMessageModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {MessageMediaType type,
      String message,
      @JsonKey(includeIfNull: false) String? id,
      @JsonKey(includeIfNull: false) String? priceModel,
      @JsonKey(includeIfNull: false) String? payToken});
}

/// @nodoc
class __$$BotClientMessageModelImplCopyWithImpl<$Res>
    extends _$BotClientMessageModelCopyWithImpl<$Res,
        _$BotClientMessageModelImpl>
    implements _$$BotClientMessageModelImplCopyWith<$Res> {
  __$$BotClientMessageModelImplCopyWithImpl(_$BotClientMessageModelImpl _value,
      $Res Function(_$BotClientMessageModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? message = null,
    Object? id = freezed,
    Object? priceModel = freezed,
    Object? payToken = freezed,
  }) {
    return _then(_$BotClientMessageModelImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MessageMediaType,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      priceModel: freezed == priceModel
          ? _value.priceModel
          : priceModel // ignore: cast_nullable_to_non_nullable
              as String?,
      payToken: freezed == payToken
          ? _value.payToken
          : payToken // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BotClientMessageModelImpl implements _BotClientMessageModel {
  const _$BotClientMessageModelImpl(
      {required this.type,
      required this.message,
      @JsonKey(includeIfNull: false) this.id,
      @JsonKey(includeIfNull: false) this.priceModel,
      @JsonKey(includeIfNull: false) this.payToken});

  factory _$BotClientMessageModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BotClientMessageModelImplFromJson(json);

  @override
  final MessageMediaType type;
  @override
  final String message;
  @override
  @JsonKey(includeIfNull: false)
  final String? id;
  @override
  @JsonKey(includeIfNull: false)
  final String? priceModel;
  @override
  @JsonKey(includeIfNull: false)
  final String? payToken;

  @override
  String toString() {
    return 'BotClientMessageModel(type: $type, message: $message, id: $id, priceModel: $priceModel, payToken: $payToken)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BotClientMessageModelImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.priceModel, priceModel) ||
                other.priceModel == priceModel) &&
            (identical(other.payToken, payToken) ||
                other.payToken == payToken));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, type, message, id, priceModel, payToken);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BotClientMessageModelImplCopyWith<_$BotClientMessageModelImpl>
      get copyWith => __$$BotClientMessageModelImplCopyWithImpl<
          _$BotClientMessageModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BotClientMessageModelImplToJson(
      this,
    );
  }
}

abstract class _BotClientMessageModel implements BotClientMessageModel {
  const factory _BotClientMessageModel(
          {required final MessageMediaType type,
          required final String message,
          @JsonKey(includeIfNull: false) final String? id,
          @JsonKey(includeIfNull: false) final String? priceModel,
          @JsonKey(includeIfNull: false) final String? payToken}) =
      _$BotClientMessageModelImpl;

  factory _BotClientMessageModel.fromJson(Map<String, dynamic> json) =
      _$BotClientMessageModelImpl.fromJson;

  @override
  MessageMediaType get type;
  @override
  String get message;
  @override
  @JsonKey(includeIfNull: false)
  String? get id;
  @override
  @JsonKey(includeIfNull: false)
  String? get priceModel;
  @override
  @JsonKey(includeIfNull: false)
  String? get payToken;
  @override
  @JsonKey(ignore: true)
  _$$BotClientMessageModelImplCopyWith<_$BotClientMessageModelImpl>
      get copyWith => throw _privateConstructorUsedError;
}
