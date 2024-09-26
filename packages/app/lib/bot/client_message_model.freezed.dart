// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client_message_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ClientMessageModel _$ClientMessageModelFromJson(Map<String, dynamic> json) {
  return _ClientMessageModel.fromJson(json);
}

/// @nodoc
mixin _$ClientMessageModel {
  ClientMessageType get type => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;
  @JsonKey(includeIfNull: false)
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(includeIfNull: false)
  String? get payToken => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $ClientMessageModelCopyWith<ClientMessageModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ClientMessageModelCopyWith<$Res> {
  factory $ClientMessageModelCopyWith(
          ClientMessageModel value, $Res Function(ClientMessageModel) then) =
      _$ClientMessageModelCopyWithImpl<$Res, ClientMessageModel>;
  @useResult
  $Res call(
      {ClientMessageType type,
      String message,
      @JsonKey(includeIfNull: false) String? id,
      @JsonKey(includeIfNull: false) String? payToken});
}

/// @nodoc
class _$ClientMessageModelCopyWithImpl<$Res, $Val extends ClientMessageModel>
    implements $ClientMessageModelCopyWith<$Res> {
  _$ClientMessageModelCopyWithImpl(this._value, this._then);

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
    Object? payToken = freezed,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ClientMessageType,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      payToken: freezed == payToken
          ? _value.payToken
          : payToken // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ClientMessageModelImplCopyWith<$Res>
    implements $ClientMessageModelCopyWith<$Res> {
  factory _$$ClientMessageModelImplCopyWith(_$ClientMessageModelImpl value,
          $Res Function(_$ClientMessageModelImpl) then) =
      __$$ClientMessageModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ClientMessageType type,
      String message,
      @JsonKey(includeIfNull: false) String? id,
      @JsonKey(includeIfNull: false) String? payToken});
}

/// @nodoc
class __$$ClientMessageModelImplCopyWithImpl<$Res>
    extends _$ClientMessageModelCopyWithImpl<$Res, _$ClientMessageModelImpl>
    implements _$$ClientMessageModelImplCopyWith<$Res> {
  __$$ClientMessageModelImplCopyWithImpl(_$ClientMessageModelImpl _value,
      $Res Function(_$ClientMessageModelImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? message = null,
    Object? id = freezed,
    Object? payToken = freezed,
  }) {
    return _then(_$ClientMessageModelImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ClientMessageType,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      id: freezed == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
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
class _$ClientMessageModelImpl implements _ClientMessageModel {
  const _$ClientMessageModelImpl(
      {required this.type,
      required this.message,
      @JsonKey(includeIfNull: false) this.id,
      @JsonKey(includeIfNull: false) this.payToken});

  factory _$ClientMessageModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ClientMessageModelImplFromJson(json);

  @override
  final ClientMessageType type;
  @override
  final String message;
  @override
  @JsonKey(includeIfNull: false)
  final String? id;
  @override
  @JsonKey(includeIfNull: false)
  final String? payToken;

  @override
  String toString() {
    return 'ClientMessageModel(type: $type, message: $message, id: $id, payToken: $payToken)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClientMessageModelImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.payToken, payToken) ||
                other.payToken == payToken));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, type, message, id, payToken);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ClientMessageModelImplCopyWith<_$ClientMessageModelImpl> get copyWith =>
      __$$ClientMessageModelImplCopyWithImpl<_$ClientMessageModelImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ClientMessageModelImplToJson(
      this,
    );
  }
}

abstract class _ClientMessageModel implements ClientMessageModel {
  const factory _ClientMessageModel(
          {required final ClientMessageType type,
          required final String message,
          @JsonKey(includeIfNull: false) final String? id,
          @JsonKey(includeIfNull: false) final String? payToken}) =
      _$ClientMessageModelImpl;

  factory _ClientMessageModel.fromJson(Map<String, dynamic> json) =
      _$ClientMessageModelImpl.fromJson;

  @override
  ClientMessageType get type;
  @override
  String get message;
  @override
  @JsonKey(includeIfNull: false)
  String? get id;
  @override
  @JsonKey(includeIfNull: false)
  String? get payToken;
  @override
  @JsonKey(ignore: true)
  _$$ClientMessageModelImplCopyWith<_$ClientMessageModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
