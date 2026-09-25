// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Home {

/// Hex.
 String get netKey;/// Hex.
 String get appKey; int get iv;/// Luminar's own unicast address.
 int get src;/// Sequence numbers below this may already have been used. Never lower it.
 int get seq; int get nextAddr; List<Light> get lights;/// Saved scene names by scene number. The web app's backups omit them.
 Map<int, String> get scenes;
/// Create a copy of Home
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$HomeCopyWith<Home> get copyWith => _$HomeCopyWithImpl<Home>(this as Home, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Home;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Home&&(identical(other.netKey, _this.netKey) || other.netKey == _this.netKey)&&(identical(other.appKey, _this.appKey) || other.appKey == _this.appKey)&&(identical(other.iv, _this.iv) || other.iv == _this.iv)&&(identical(other.src, _this.src) || other.src == _this.src)&&(identical(other.seq, _this.seq) || other.seq == _this.seq)&&(identical(other.nextAddr, _this.nextAddr) || other.nextAddr == _this.nextAddr)&&const DeepCollectionEquality().equals(other.lights, _this.lights)&&const DeepCollectionEquality().equals(other.scenes, _this.scenes));
}


@override
int get hashCode {
  final _this = this as Home;
  return Object.hash(runtimeType,_this.netKey,_this.appKey,_this.iv,_this.src,_this.seq,_this.nextAddr,const DeepCollectionEquality().hash(_this.lights),const DeepCollectionEquality().hash(_this.scenes));
}

@override
String toString() {
  final _this = this as Home;
  return 'Home(netKey: ${_this.netKey}, appKey: ${_this.appKey}, iv: ${_this.iv}, src: ${_this.src}, seq: ${_this.seq}, nextAddr: ${_this.nextAddr}, lights: ${_this.lights}, scenes: ${_this.scenes})';
}


}

/// @nodoc
abstract mixin class $HomeCopyWith<$Res>  {
  factory $HomeCopyWith(Home value, $Res Function(Home) _then) = _$HomeCopyWithImpl;
@useResult
$Res call({
 String netKey, String appKey, int iv, int src, int seq, int nextAddr, List<Light> lights, Map<int, String> scenes
});




}
/// @nodoc
class _$HomeCopyWithImpl<$Res>
    implements $HomeCopyWith<$Res> {
  _$HomeCopyWithImpl(this._self, this._then);

  final Home _self;
  final $Res Function(Home) _then;

/// Create a copy of Home
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? netKey = null,Object? appKey = null,Object? iv = null,Object? src = null,Object? seq = null,Object? nextAddr = null,Object? lights = null,Object? scenes = null,}) {
  return _then(Home(
netKey: null == netKey ? _self.netKey : netKey // ignore: cast_nullable_to_non_nullable
as String,appKey: null == appKey ? _self.appKey : appKey // ignore: cast_nullable_to_non_nullable
as String,iv: null == iv ? _self.iv : iv // ignore: cast_nullable_to_non_nullable
as int,src: null == src ? _self.src : src // ignore: cast_nullable_to_non_nullable
as int,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,nextAddr: null == nextAddr ? _self.nextAddr : nextAddr // ignore: cast_nullable_to_non_nullable
as int,lights: null == lights ? _self.lights : lights // ignore: cast_nullable_to_non_nullable
as List<Light>,scenes: null == scenes ? _self.scenes : scenes // ignore: cast_nullable_to_non_nullable
as Map<int, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Home].
extension HomePatterns on Home {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Home value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Home() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Home value)  $default,){
final _that = this;
switch (_that) {
case _Home():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Home value)?  $default,){
final _that = this;
switch (_that) {
case _Home() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String netKey,  String appKey,  int iv,  int src,  int seq,  int nextAddr,  List<Light> lights,  Map<int, String> scenes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Home() when $default != null:
return $default(_that.netKey,_that.appKey,_that.iv,_that.src,_that.seq,_that.nextAddr,_that.lights,_that.scenes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String netKey,  String appKey,  int iv,  int src,  int seq,  int nextAddr,  List<Light> lights,  Map<int, String> scenes)  $default,) {final _that = this;
switch (_that) {
case _Home():
return $default(_that.netKey,_that.appKey,_that.iv,_that.src,_that.seq,_that.nextAddr,_that.lights,_that.scenes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String netKey,  String appKey,  int iv,  int src,  int seq,  int nextAddr,  List<Light> lights,  Map<int, String> scenes)?  $default,) {final _that = this;
switch (_that) {
case _Home() when $default != null:
return $default(_that.netKey,_that.appKey,_that.iv,_that.src,_that.seq,_that.nextAddr,_that.lights,_that.scenes);case _:
  return null;

}
}

}

/// @nodoc


class _Home extends Home {
  const _Home({required this.netKey, required this.appKey, this.iv = 0, this.src = 0x0001, this.seq = 1, this.nextAddr = 0x0010,  List<Light> lights = const [],  Map<int, String> scenes = const {}}): _lights = lights,_scenes = scenes,super._();
  

/// Hex.
@override final  String netKey;
/// Hex.
@override final  String appKey;
@override@JsonKey() final  int iv;
/// Luminar's own unicast address.
@override@JsonKey() final  int src;
/// Sequence numbers below this may already have been used. Never lower it.
@override@JsonKey() final  int seq;
@override@JsonKey() final  int nextAddr;
 final  List<Light> _lights;
@override@JsonKey() List<Light> get lights {
  if (_lights is EqualUnmodifiableListView) return _lights;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lights);
}

/// Saved scene names by scene number. The web app's backups omit them.
 final  Map<int, String> _scenes;
/// Saved scene names by scene number. The web app's backups omit them.
@override@JsonKey() Map<int, String> get scenes {
  if (_scenes is EqualUnmodifiableMapView) return _scenes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_scenes);
}


/// Create a copy of Home
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$HomeCopyWith<_Home> get copyWith => __$HomeCopyWithImpl<_Home>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Home&&(identical(other.netKey, netKey) || other.netKey == netKey)&&(identical(other.appKey, appKey) || other.appKey == appKey)&&(identical(other.iv, iv) || other.iv == iv)&&(identical(other.src, src) || other.src == src)&&(identical(other.seq, seq) || other.seq == seq)&&(identical(other.nextAddr, nextAddr) || other.nextAddr == nextAddr)&&const DeepCollectionEquality().equals(other.lights, _lights)&&const DeepCollectionEquality().equals(other.scenes, _scenes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,netKey,appKey,iv,src,seq,nextAddr,const DeepCollectionEquality().hash(_lights),const DeepCollectionEquality().hash(_scenes));
}

@override
String toString() {
    return 'Home(netKey: $netKey, appKey: $appKey, iv: $iv, src: $src, seq: $seq, nextAddr: $nextAddr, lights: $lights, scenes: $scenes)';
}


}

/// @nodoc
abstract mixin class _$HomeCopyWith<$Res> implements $HomeCopyWith<$Res> {
  factory _$HomeCopyWith(_Home value, $Res Function(_Home) _then) = __$HomeCopyWithImpl;
@override @useResult
$Res call({
 String netKey, String appKey, int iv, int src, int seq, int nextAddr, List<Light> lights, Map<int, String> scenes
});




}
/// @nodoc
class __$HomeCopyWithImpl<$Res>
    implements _$HomeCopyWith<$Res> {
  __$HomeCopyWithImpl(this._self, this._then);

  final _Home _self;
  final $Res Function(_Home) _then;

/// Create a copy of Home
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? netKey = null,Object? appKey = null,Object? iv = null,Object? src = null,Object? seq = null,Object? nextAddr = null,Object? lights = null,Object? scenes = null,}) {
  return _then(_Home(
netKey: null == netKey ? _self.netKey : netKey // ignore: cast_nullable_to_non_nullable
as String,appKey: null == appKey ? _self.appKey : appKey // ignore: cast_nullable_to_non_nullable
as String,iv: null == iv ? _self.iv : iv // ignore: cast_nullable_to_non_nullable
as int,src: null == src ? _self.src : src // ignore: cast_nullable_to_non_nullable
as int,seq: null == seq ? _self.seq : seq // ignore: cast_nullable_to_non_nullable
as int,nextAddr: null == nextAddr ? _self.nextAddr : nextAddr // ignore: cast_nullable_to_non_nullable
as int,lights: null == lights ? _self._lights : lights // ignore: cast_nullable_to_non_nullable
as List<Light>,scenes: null == scenes ? _self._scenes : scenes // ignore: cast_nullable_to_non_nullable
as Map<int, String>,
  ));
}


}

// dart format on
