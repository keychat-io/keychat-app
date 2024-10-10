// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bot_server_message_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

BotServerMessageModel _$BotServerMessageModelFromJson(
    Map<String, dynamic> json) {
  return _BotServerMessageModel.fromJson(json);
}

/// @nodoc
mixin _$BotServerMessageModel {
// botText,botSelectionRequest,botPricePerMessageRequest,botOneTimePaymentRequest,
  MessageMediaType get type => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  List<BotMessageData> get priceModels => throw _privateConstructorUsedError;
  String? get id => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BotServerMessageModelCopyWith<BotServerMessageModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BotServerMessageModelCopyWith<$Res> {
  factory $BotServerMessageModelCopyWith(BotServerMessageModel value,
          $Res Function(BotServerMessageModel) then) =
      _$BotServerMessageModelCopyWithImpl<$Res, BotServerMessageModel>;
  @useResult
  $Res call(
      {MessageMediaType type,
      String message,
      List<BotMessageData> priceModels,
      String? id});
}

/// @nodoc
class _$BotServerMessageModelCopyWithImpl<$Res,
        $Val extends BotServerMessageModel>
    implements $BotServerMessageModelCopyWith<$Res> {
  _$BotServerMessageModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? message = null,
    Object? priceModels = null,
    Object? id = freezed,
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
      priceModels: null == priceModels
          ? _value.priceModels
          : priceModels // ignore: cast_nullable_to_non_nullable
              as List<BotMessageData>,
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BotServerMessageModelImplCopyWith<$Res>
    implements $BotServerMessageModelCopyWith<$Res> {
  factory _$$BotServerMessageModelImplCopyWith(
          _$BotServerMessageModelImpl value,
          $Res Function(_$BotServerMessageModelImpl) then) =
      __$$BotServerMessageModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {MessageMediaType type,
      String message,
      List<BotMessageData> priceModels,
      String? id});
}

/// @nodoc
class __$$BotServerMessageModelImplCopyWithImpl<$Res>
    extends _$BotServerMessageModelCopyWithImpl<$Res,
        _$BotServerMessageModelImpl>
    implements _$$BotServerMessageModelImplCopyWith<$Res> {
  __$$BotServerMessageModelImplCopyWithImpl(_$BotServerMessageModelImpl _value,
      $Res Function(_$BotServerMessageModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? message = null,
    Object? priceModels = null,
    Object? id = freezed,
  }) {
    return _then(_$BotServerMessageModelImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MessageMediaType,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      priceModels: null == priceModels
          ? _value._priceModels
          : priceModels // ignore: cast_nullable_to_non_nullable
              as List<BotMessageData>,
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BotServerMessageModelImpl extends _BotServerMessageModel {
  const _$BotServerMessageModelImpl(
      {required this.type,
      required this.message,
      required final List<BotMessageData> priceModels,
      this.id})
      : _priceModels = priceModels,
        super._();

  factory _$BotServerMessageModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BotServerMessageModelImplFromJson(json);

// botText,botSelectionRequest,botPricePerMessageRequest,botOneTimePaymentRequest,
  @override
  final MessageMediaType type;
  @override
  final String message;
  final List<BotMessageData> _priceModels;
  @override
  List<BotMessageData> get priceModels {
    if (_priceModels is EqualUnmodifiableListView) return _priceModels;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_priceModels);
  }

  @override
  final String? id;

  @override
  String toString() {
    return 'BotServerMessageModel(type: $type, message: $message, priceModels: $priceModels, id: $id)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BotServerMessageModelImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality()
                .equals(other._priceModels, _priceModels) &&
            (identical(other.id, id) || other.id == id));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, type, message,
      const DeepCollectionEquality().hash(_priceModels), id);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BotServerMessageModelImplCopyWith<_$BotServerMessageModelImpl>
      get copyWith => __$$BotServerMessageModelImplCopyWithImpl<
          _$BotServerMessageModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BotServerMessageModelImplToJson(
      this,
    );
  }
}

abstract class _BotServerMessageModel extends BotServerMessageModel {
  const factory _BotServerMessageModel(
      {required final MessageMediaType type,
      required final String message,
      required final List<BotMessageData> priceModels,
      final String? id}) = _$BotServerMessageModelImpl;
  const _BotServerMessageModel._() : super._();

  factory _BotServerMessageModel.fromJson(Map<String, dynamic> json) =
      _$BotServerMessageModelImpl.fromJson;

  @override // botText,botSelectionRequest,botPricePerMessageRequest,botOneTimePaymentRequest,
  MessageMediaType get type;
  @override
  String get message;
  @override
  List<BotMessageData> get priceModels;
  @override
  String? get id;
  @override
  @JsonKey(ignore: true)
  _$$BotServerMessageModelImplCopyWith<_$BotServerMessageModelImpl>
      get copyWith => throw _privateConstructorUsedError;
}

BotMessageData _$BotMessageDataFromJson(Map<String, dynamic> json) {
  return _BotMessageData.fromJson(json);
}

/// @nodoc
mixin _$BotMessageData {
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  int get price => throw _privateConstructorUsedError;
  String get unit => throw _privateConstructorUsedError;
  List<String> get mints => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BotMessageDataCopyWith<BotMessageData> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BotMessageDataCopyWith<$Res> {
  factory $BotMessageDataCopyWith(
          BotMessageData value, $Res Function(BotMessageData) then) =
      _$BotMessageDataCopyWithImpl<$Res, BotMessageData>;
  @useResult
  $Res call(
      {String name,
      String description,
      int price,
      String unit,
      List<String> mints});
}

/// @nodoc
class _$BotMessageDataCopyWithImpl<$Res, $Val extends BotMessageData>
    implements $BotMessageDataCopyWith<$Res> {
  _$BotMessageDataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = null,
    Object? price = null,
    Object? unit = null,
    Object? mints = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as int,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      mints: null == mints
          ? _value.mints
          : mints // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BotMessageDataImplCopyWith<$Res>
    implements $BotMessageDataCopyWith<$Res> {
  factory _$$BotMessageDataImplCopyWith(_$BotMessageDataImpl value,
          $Res Function(_$BotMessageDataImpl) then) =
      __$$BotMessageDataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      String description,
      int price,
      String unit,
      List<String> mints});
}

/// @nodoc
class __$$BotMessageDataImplCopyWithImpl<$Res>
    extends _$BotMessageDataCopyWithImpl<$Res, _$BotMessageDataImpl>
    implements _$$BotMessageDataImplCopyWith<$Res> {
  __$$BotMessageDataImplCopyWithImpl(
      _$BotMessageDataImpl _value, $Res Function(_$BotMessageDataImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = null,
    Object? price = null,
    Object? unit = null,
    Object? mints = null,
  }) {
    return _then(_$BotMessageDataImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as int,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      mints: null == mints
          ? _value._mints
          : mints // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BotMessageDataImpl implements _BotMessageData {
  const _$BotMessageDataImpl(
      {required this.name,
      required this.description,
      required this.price,
      required this.unit,
      final List<String> mints = const []})
      : _mints = mints;

  factory _$BotMessageDataImpl.fromJson(Map<String, dynamic> json) =>
      _$$BotMessageDataImplFromJson(json);

  @override
  final String name;
  @override
  final String description;
  @override
  final int price;
  @override
  final String unit;
  final List<String> _mints;
  @override
  @JsonKey()
  List<String> get mints {
    if (_mints is EqualUnmodifiableListView) return _mints;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_mints);
  }

  @override
  String toString() {
    return 'BotMessageData(name: $name, description: $description, price: $price, unit: $unit, mints: $mints)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BotMessageDataImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            const DeepCollectionEquality().equals(other._mints, _mints));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, name, description, price, unit,
      const DeepCollectionEquality().hash(_mints));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BotMessageDataImplCopyWith<_$BotMessageDataImpl> get copyWith =>
      __$$BotMessageDataImplCopyWithImpl<_$BotMessageDataImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BotMessageDataImplToJson(
      this,
    );
  }
}

abstract class _BotMessageData implements BotMessageData {
  const factory _BotMessageData(
      {required final String name,
      required final String description,
      required final int price,
      required final String unit,
      final List<String> mints}) = _$BotMessageDataImpl;

  factory _BotMessageData.fromJson(Map<String, dynamic> json) =
      _$BotMessageDataImpl.fromJson;

  @override
  String get name;
  @override
  String get description;
  @override
  int get price;
  @override
  String get unit;
  @override
  List<String> get mints;
  @override
  @JsonKey(ignore: true)
  _$$BotMessageDataImplCopyWith<_$BotMessageDataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
