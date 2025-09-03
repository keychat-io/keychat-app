// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bot_server_message_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BotServerMessageModel {
// botText,botSelectionRequest,botPricePerMessageRequest,botOneTimePaymentRequest,
  MessageMediaType get type;
  String get message;
  List<BotMessageData> get priceModels;
  String? get id;

  /// Create a copy of BotServerMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BotServerMessageModelCopyWith<BotServerMessageModel> get copyWith =>
      _$BotServerMessageModelCopyWithImpl<BotServerMessageModel>(
          this as BotServerMessageModel, _$identity);

  /// Serializes this BotServerMessageModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BotServerMessageModel &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality()
                .equals(other.priceModels, priceModels) &&
            (identical(other.id, id) || other.id == id));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, message,
      const DeepCollectionEquality().hash(priceModels), id);

  @override
  String toString() {
    return 'BotServerMessageModel(type: $type, message: $message, priceModels: $priceModels, id: $id)';
  }
}

/// @nodoc
abstract mixin class $BotServerMessageModelCopyWith<$Res> {
  factory $BotServerMessageModelCopyWith(BotServerMessageModel value,
          $Res Function(BotServerMessageModel) _then) =
      _$BotServerMessageModelCopyWithImpl;
  @useResult
  $Res call(
      {MessageMediaType type,
      String message,
      List<BotMessageData> priceModels,
      String? id});
}

/// @nodoc
class _$BotServerMessageModelCopyWithImpl<$Res>
    implements $BotServerMessageModelCopyWith<$Res> {
  _$BotServerMessageModelCopyWithImpl(this._self, this._then);

  final BotServerMessageModel _self;
  final $Res Function(BotServerMessageModel) _then;

  /// Create a copy of BotServerMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? message = null,
    Object? priceModels = null,
    Object? id = freezed,
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
      priceModels: null == priceModels
          ? _self.priceModels
          : priceModels // ignore: cast_nullable_to_non_nullable
              as List<BotMessageData>,
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [BotServerMessageModel].
extension BotServerMessageModelPatterns on BotServerMessageModel {
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
    TResult Function(_BotServerMessageModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BotServerMessageModel() when $default != null:
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
    TResult Function(_BotServerMessageModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BotServerMessageModel():
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
    TResult? Function(_BotServerMessageModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BotServerMessageModel() when $default != null:
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
    TResult Function(MessageMediaType type, String message,
            List<BotMessageData> priceModels, String? id)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BotServerMessageModel() when $default != null:
        return $default(_that.type, _that.message, _that.priceModels, _that.id);
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
    TResult Function(MessageMediaType type, String message,
            List<BotMessageData> priceModels, String? id)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BotServerMessageModel():
        return $default(_that.type, _that.message, _that.priceModels, _that.id);
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
    TResult? Function(MessageMediaType type, String message,
            List<BotMessageData> priceModels, String? id)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BotServerMessageModel() when $default != null:
        return $default(_that.type, _that.message, _that.priceModels, _that.id);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _BotServerMessageModel extends BotServerMessageModel {
  const _BotServerMessageModel(
      {required this.type,
      required this.message,
      required final List<BotMessageData> priceModels,
      this.id})
      : _priceModels = priceModels,
        super._();
  factory _BotServerMessageModel.fromJson(Map<String, dynamic> json) =>
      _$BotServerMessageModelFromJson(json);

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

  /// Create a copy of BotServerMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BotServerMessageModelCopyWith<_BotServerMessageModel> get copyWith =>
      __$BotServerMessageModelCopyWithImpl<_BotServerMessageModel>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BotServerMessageModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BotServerMessageModel &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.message, message) || other.message == message) &&
            const DeepCollectionEquality()
                .equals(other._priceModels, _priceModels) &&
            (identical(other.id, id) || other.id == id));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, message,
      const DeepCollectionEquality().hash(_priceModels), id);

  @override
  String toString() {
    return 'BotServerMessageModel(type: $type, message: $message, priceModels: $priceModels, id: $id)';
  }
}

/// @nodoc
abstract mixin class _$BotServerMessageModelCopyWith<$Res>
    implements $BotServerMessageModelCopyWith<$Res> {
  factory _$BotServerMessageModelCopyWith(_BotServerMessageModel value,
          $Res Function(_BotServerMessageModel) _then) =
      __$BotServerMessageModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {MessageMediaType type,
      String message,
      List<BotMessageData> priceModels,
      String? id});
}

/// @nodoc
class __$BotServerMessageModelCopyWithImpl<$Res>
    implements _$BotServerMessageModelCopyWith<$Res> {
  __$BotServerMessageModelCopyWithImpl(this._self, this._then);

  final _BotServerMessageModel _self;
  final $Res Function(_BotServerMessageModel) _then;

  /// Create a copy of BotServerMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? type = null,
    Object? message = null,
    Object? priceModels = null,
    Object? id = freezed,
  }) {
    return _then(_BotServerMessageModel(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as MessageMediaType,
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      priceModels: null == priceModels
          ? _self._priceModels
          : priceModels // ignore: cast_nullable_to_non_nullable
              as List<BotMessageData>,
      id: freezed == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$BotMessageData {
  String get name;
  String get description;
  int get price;
  String get unit;
  List<String> get mints;

  /// Create a copy of BotMessageData
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BotMessageDataCopyWith<BotMessageData> get copyWith =>
      _$BotMessageDataCopyWithImpl<BotMessageData>(
          this as BotMessageData, _$identity);

  /// Serializes this BotMessageData to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BotMessageData &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            const DeepCollectionEquality().equals(other.mints, mints));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, description, price, unit,
      const DeepCollectionEquality().hash(mints));

  @override
  String toString() {
    return 'BotMessageData(name: $name, description: $description, price: $price, unit: $unit, mints: $mints)';
  }
}

/// @nodoc
abstract mixin class $BotMessageDataCopyWith<$Res> {
  factory $BotMessageDataCopyWith(
          BotMessageData value, $Res Function(BotMessageData) _then) =
      _$BotMessageDataCopyWithImpl;
  @useResult
  $Res call(
      {String name,
      String description,
      int price,
      String unit,
      List<String> mints});
}

/// @nodoc
class _$BotMessageDataCopyWithImpl<$Res>
    implements $BotMessageDataCopyWith<$Res> {
  _$BotMessageDataCopyWithImpl(this._self, this._then);

  final BotMessageData _self;
  final $Res Function(BotMessageData) _then;

  /// Create a copy of BotMessageData
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = null,
    Object? price = null,
    Object? unit = null,
    Object? mints = null,
  }) {
    return _then(_self.copyWith(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as int,
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      mints: null == mints
          ? _self.mints
          : mints // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// Adds pattern-matching-related methods to [BotMessageData].
extension BotMessageDataPatterns on BotMessageData {
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
    TResult Function(_BotMessageData value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BotMessageData() when $default != null:
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
    TResult Function(_BotMessageData value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BotMessageData():
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
    TResult? Function(_BotMessageData value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BotMessageData() when $default != null:
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
    TResult Function(String name, String description, int price, String unit,
            List<String> mints)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BotMessageData() when $default != null:
        return $default(_that.name, _that.description, _that.price, _that.unit,
            _that.mints);
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
    TResult Function(String name, String description, int price, String unit,
            List<String> mints)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BotMessageData():
        return $default(_that.name, _that.description, _that.price, _that.unit,
            _that.mints);
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
    TResult? Function(String name, String description, int price, String unit,
            List<String> mints)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BotMessageData() when $default != null:
        return $default(_that.name, _that.description, _that.price, _that.unit,
            _that.mints);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _BotMessageData implements BotMessageData {
  const _BotMessageData(
      {required this.name,
      required this.description,
      required this.price,
      required this.unit,
      final List<String> mints = const []})
      : _mints = mints;
  factory _BotMessageData.fromJson(Map<String, dynamic> json) =>
      _$BotMessageDataFromJson(json);

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

  /// Create a copy of BotMessageData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BotMessageDataCopyWith<_BotMessageData> get copyWith =>
      __$BotMessageDataCopyWithImpl<_BotMessageData>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BotMessageDataToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BotMessageData &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            const DeepCollectionEquality().equals(other._mints, _mints));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, description, price, unit,
      const DeepCollectionEquality().hash(_mints));

  @override
  String toString() {
    return 'BotMessageData(name: $name, description: $description, price: $price, unit: $unit, mints: $mints)';
  }
}

/// @nodoc
abstract mixin class _$BotMessageDataCopyWith<$Res>
    implements $BotMessageDataCopyWith<$Res> {
  factory _$BotMessageDataCopyWith(
          _BotMessageData value, $Res Function(_BotMessageData) _then) =
      __$BotMessageDataCopyWithImpl;
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
class __$BotMessageDataCopyWithImpl<$Res>
    implements _$BotMessageDataCopyWith<$Res> {
  __$BotMessageDataCopyWithImpl(this._self, this._then);

  final _BotMessageData _self;
  final $Res Function(_BotMessageData) _then;

  /// Create a copy of BotMessageData
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? name = null,
    Object? description = null,
    Object? price = null,
    Object? unit = null,
    Object? mints = null,
  }) {
    return _then(_BotMessageData(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as int,
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      mints: null == mints
          ? _self._mints
          : mints // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

// dart format on
