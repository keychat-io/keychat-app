// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bot_message_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

BotMessageModel _$BotMessageModelFromJson(Map<String, dynamic> json) {
  return _BotMessageModel.fromJson(json);
}

/// @nodoc
mixin _$BotMessageModel {
  ServerMessageType get type => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  List<BotMessageData> get priceModels => throw _privateConstructorUsedError;
  String? get id => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BotMessageModelCopyWith<BotMessageModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BotMessageModelCopyWith<$Res> {
  factory $BotMessageModelCopyWith(
          BotMessageModel value, $Res Function(BotMessageModel) then) =
      _$BotMessageModelCopyWithImpl<$Res, BotMessageModel>;
  @useResult
  $Res call(
      {ServerMessageType type,
      String message,
      List<BotMessageData> priceModels,
      String? id});
}

/// @nodoc
class _$BotMessageModelCopyWithImpl<$Res, $Val extends BotMessageModel>
    implements $BotMessageModelCopyWith<$Res> {
  _$BotMessageModelCopyWithImpl(this._value, this._then);

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
              as ServerMessageType,
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
abstract class _$$BotMessageModelImplCopyWith<$Res>
    implements $BotMessageModelCopyWith<$Res> {
  factory _$$BotMessageModelImplCopyWith(_$BotMessageModelImpl value,
          $Res Function(_$BotMessageModelImpl) then) =
      __$$BotMessageModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ServerMessageType type,
      String message,
      List<BotMessageData> priceModels,
      String? id});
}

/// @nodoc
class __$$BotMessageModelImplCopyWithImpl<$Res>
    extends _$BotMessageModelCopyWithImpl<$Res, _$BotMessageModelImpl>
    implements _$$BotMessageModelImplCopyWith<$Res> {
  __$$BotMessageModelImplCopyWithImpl(
      _$BotMessageModelImpl _value, $Res Function(_$BotMessageModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? message = null,
    Object? priceModels = null,
    Object? id = freezed,
  }) {
    return _then(_$BotMessageModelImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ServerMessageType,
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
class _$BotMessageModelImpl extends _BotMessageModel {
  const _$BotMessageModelImpl(
      {required this.type,
      required this.message,
      required final List<BotMessageData> priceModels,
      this.id})
      : _priceModels = priceModels,
        super._();

  factory _$BotMessageModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$BotMessageModelImplFromJson(json);

  @override
  final ServerMessageType type;
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
    return 'BotMessageModel(type: $type, message: $message, priceModels: $priceModels, id: $id)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BotMessageModelImpl &&
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
  _$$BotMessageModelImplCopyWith<_$BotMessageModelImpl> get copyWith =>
      __$$BotMessageModelImplCopyWithImpl<_$BotMessageModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BotMessageModelImplToJson(
      this,
    );
  }
}

abstract class _BotMessageModel extends BotMessageModel {
  const factory _BotMessageModel(
      {required final ServerMessageType type,
      required final String message,
      required final List<BotMessageData> priceModels,
      final String? id}) = _$BotMessageModelImpl;
  const _BotMessageModel._() : super._();

  factory _BotMessageModel.fromJson(Map<String, dynamic> json) =
      _$BotMessageModelImpl.fromJson;

  @override
  ServerMessageType get type;
  @override
  String get message;
  @override
  List<BotMessageData> get priceModels;
  @override
  String? get id;
  @override
  @JsonKey(ignore: true)
  _$$BotMessageModelImplCopyWith<_$BotMessageModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
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
      required final List<String> mints})
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
      required final List<String> mints}) = _$BotMessageDataImpl;

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
