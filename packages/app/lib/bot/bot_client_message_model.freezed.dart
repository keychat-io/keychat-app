// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bot_client_message_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BotClientMessageModel {
  MessageMediaType get type;
  String get message;
  @JsonKey(includeIfNull: false)
  String? get id;
  @JsonKey(includeIfNull: false)
  String? get priceModel;
  @JsonKey(includeIfNull: false)
  String? get payToken;

  /// Create a copy of BotClientMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BotClientMessageModelCopyWith<BotClientMessageModel> get copyWith =>
      _$BotClientMessageModelCopyWithImpl<BotClientMessageModel>(
          this as BotClientMessageModel, _$identity);

  /// Serializes this BotClientMessageModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BotClientMessageModel &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.priceModel, priceModel) ||
                other.priceModel == priceModel) &&
            (identical(other.payToken, payToken) ||
                other.payToken == payToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, type, message, id, priceModel, payToken);

  @override
  String toString() {
    return 'BotClientMessageModel(type: $type, message: $message, id: $id, priceModel: $priceModel, payToken: $payToken)';
  }
}

/// @nodoc
abstract mixin class $BotClientMessageModelCopyWith<$Res> {
  factory $BotClientMessageModelCopyWith(BotClientMessageModel value,
          $Res Function(BotClientMessageModel) _then) =
      _$BotClientMessageModelCopyWithImpl;
  @useResult
  $Res call(
      {MessageMediaType type,
      String message,
      @JsonKey(includeIfNull: false) String? id,
      @JsonKey(includeIfNull: false) String? priceModel,
      @JsonKey(includeIfNull: false) String? payToken});
}

/// @nodoc
class _$BotClientMessageModelCopyWithImpl<$Res>
    implements $BotClientMessageModelCopyWith<$Res> {
  _$BotClientMessageModelCopyWithImpl(this._self, this._then);

  final BotClientMessageModel _self;
  final $Res Function(BotClientMessageModel) _then;

  /// Create a copy of BotClientMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? message = null,
    Object? id = freezed,
    Object? priceModel = freezed,
    Object? payToken = freezed,
  }) {
    return _then(_self.copyWith(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as MessageMediaType,
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      priceModel: freezed == priceModel
          ? _self.priceModel
          : priceModel // ignore: cast_nullable_to_non_nullable
              as String?,
      payToken: freezed == payToken
          ? _self.payToken
          : payToken // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [BotClientMessageModel].
extension BotClientMessageModelPatterns on BotClientMessageModel {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_BotClientMessageModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BotClientMessageModel() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_BotClientMessageModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BotClientMessageModel():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_BotClientMessageModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BotClientMessageModel() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            MessageMediaType type,
            String message,
            @JsonKey(includeIfNull: false) String? id,
            @JsonKey(includeIfNull: false) String? priceModel,
            @JsonKey(includeIfNull: false) String? payToken)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BotClientMessageModel() when $default != null:
        return $default(_that.type, _that.message, _that.id, _that.priceModel,
            _that.payToken);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            MessageMediaType type,
            String message,
            @JsonKey(includeIfNull: false) String? id,
            @JsonKey(includeIfNull: false) String? priceModel,
            @JsonKey(includeIfNull: false) String? payToken)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BotClientMessageModel():
        return $default(_that.type, _that.message, _that.id, _that.priceModel,
            _that.payToken);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            MessageMediaType type,
            String message,
            @JsonKey(includeIfNull: false) String? id,
            @JsonKey(includeIfNull: false) String? priceModel,
            @JsonKey(includeIfNull: false) String? payToken)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BotClientMessageModel() when $default != null:
        return $default(_that.type, _that.message, _that.id, _that.priceModel,
            _that.payToken);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _BotClientMessageModel implements BotClientMessageModel {
  const _BotClientMessageModel(
      {required this.type,
      required this.message,
      @JsonKey(includeIfNull: false) this.id,
      @JsonKey(includeIfNull: false) this.priceModel,
      @JsonKey(includeIfNull: false) this.payToken});
  factory _BotClientMessageModel.fromJson(Map<String, dynamic> json) =>
      _$BotClientMessageModelFromJson(json);

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

  /// Create a copy of BotClientMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BotClientMessageModelCopyWith<_BotClientMessageModel> get copyWith =>
      __$BotClientMessageModelCopyWithImpl<_BotClientMessageModel>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BotClientMessageModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BotClientMessageModel &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.priceModel, priceModel) ||
                other.priceModel == priceModel) &&
            (identical(other.payToken, payToken) ||
                other.payToken == payToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, type, message, id, priceModel, payToken);

  @override
  String toString() {
    return 'BotClientMessageModel(type: $type, message: $message, id: $id, priceModel: $priceModel, payToken: $payToken)';
  }
}

/// @nodoc
abstract mixin class _$BotClientMessageModelCopyWith<$Res>
    implements $BotClientMessageModelCopyWith<$Res> {
  factory _$BotClientMessageModelCopyWith(_BotClientMessageModel value,
          $Res Function(_BotClientMessageModel) _then) =
      __$BotClientMessageModelCopyWithImpl;
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
class __$BotClientMessageModelCopyWithImpl<$Res>
    implements _$BotClientMessageModelCopyWith<$Res> {
  __$BotClientMessageModelCopyWithImpl(this._self, this._then);

  final _BotClientMessageModel _self;
  final $Res Function(_BotClientMessageModel) _then;

  /// Create a copy of BotClientMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? type = null,
    Object? message = null,
    Object? id = freezed,
    Object? priceModel = freezed,
    Object? payToken = freezed,
  }) {
    return _then(_BotClientMessageModel(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as MessageMediaType,
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
      priceModel: freezed == priceModel
          ? _self.priceModel
          : priceModel // ignore: cast_nullable_to_non_nullable
              as String?,
      payToken: freezed == payToken
          ? _self.payToken
          : payToken // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
