// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'light_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LightState {

 bool get on;/// Whether the light has reported its state since Luminar started.
 bool get known;/// False when the light did not answer the last state query.
 bool get responding;
/// Create a copy of LightState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LightStateCopyWith<LightState> get copyWith => _$LightStateCopyWithImpl<LightState>(this as LightState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as LightState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LightState&&(identical(other.on, _this.on) || other.on == _this.on)&&(identical(other.known, _this.known) || other.known == _this.known)&&(identical(other.responding, _this.responding) || other.responding == _this.responding));
}


@override
int get hashCode {
  final _this = this as LightState;
  return Object.hash(runtimeType,_this.on,_this.known,_this.responding);
}

@override
String toString() {
  final _this = this as LightState;
  return 'LightState(on: ${_this.on}, known: ${_this.known}, responding: ${_this.responding})';
}


}

/// @nodoc
abstract mixin class $LightStateCopyWith<$Res>  {
  factory $LightStateCopyWith(LightState value, $Res Function(LightState) _then) = _$LightStateCopyWithImpl;
@useResult
$Res call({
 bool on, bool known, bool responding
});




}
/// @nodoc
class _$LightStateCopyWithImpl<$Res>
    implements $LightStateCopyWith<$Res> {
  _$LightStateCopyWithImpl(this._self, this._then);

  final LightState _self;
  final $Res Function(LightState) _then;

/// Create a copy of LightState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? on = null,Object? known = null,Object? responding = null,}) {
  return _then(LightState(
on: null == on ? _self.on : on // ignore: cast_nullable_to_non_nullable
as bool,known: null == known ? _self.known : known // ignore: cast_nullable_to_non_nullable
as bool,responding: null == responding ? _self.responding : responding // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LightState].
extension LightStatePatterns on LightState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LightState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LightState() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LightState value)  $default,){
final _that = this;
switch (_that) {
case _LightState():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LightState value)?  $default,){
final _that = this;
switch (_that) {
case _LightState() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool on,  bool known,  bool responding)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LightState() when $default != null:
return $default(_that.on,_that.known,_that.responding);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool on,  bool known,  bool responding)  $default,) {final _that = this;
switch (_that) {
case _LightState():
return $default(_that.on,_that.known,_that.responding);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool on,  bool known,  bool responding)?  $default,) {final _that = this;
switch (_that) {
case _LightState() when $default != null:
return $default(_that.on,_that.known,_that.responding);case _:
  return null;

}
}

}

/// @nodoc


class _LightState implements LightState {
  const _LightState({this.on = false, this.known = false, this.responding = true});
  

@override@JsonKey() final  bool on;
/// Whether the light has reported its state since Luminar started.
@override@JsonKey() final  bool known;
/// False when the light did not answer the last state query.
@override@JsonKey() final  bool responding;

/// Create a copy of LightState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LightStateCopyWith<_LightState> get copyWith => __$LightStateCopyWithImpl<_LightState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LightState&&(identical(other.on, on) || other.on == on)&&(identical(other.known, known) || other.known == known)&&(identical(other.responding, responding) || other.responding == responding));
}


@override
int get hashCode {
    return Object.hash(runtimeType,on,known,responding);
}

@override
String toString() {
    return 'LightState(on: $on, known: $known, responding: $responding)';
}


}

/// @nodoc
abstract mixin class _$LightStateCopyWith<$Res> implements $LightStateCopyWith<$Res> {
  factory _$LightStateCopyWith(_LightState value, $Res Function(_LightState) _then) = __$LightStateCopyWithImpl;
@override @useResult
$Res call({
 bool on, bool known, bool responding
});




}
/// @nodoc
class __$LightStateCopyWithImpl<$Res>
    implements _$LightStateCopyWith<$Res> {
  __$LightStateCopyWithImpl(this._self, this._then);

  final _LightState _self;
  final $Res Function(_LightState) _then;

/// Create a copy of LightState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? on = null,Object? known = null,Object? responding = null,}) {
  return _then(_LightState(
on: null == on ? _self.on : on // ignore: cast_nullable_to_non_nullable
as bool,known: null == known ? _self.known : known // ignore: cast_nullable_to_non_nullable
as bool,responding: null == responding ? _self.responding : responding // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
