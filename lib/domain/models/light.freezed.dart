// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'light.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Light {

 int get addr; int get elements; String get name;/// Hex.
 String get devKey; bool get configured;/// Models the AppKey is bound to, by key of `Models.bindable`.
 Map<String, bool> get models;/// 1–100 %.
 int get level; int get kelvin;/// Models (keys of `Models.bindable`) subscribed to [allLightsGroup].
 Set<String> get groupModels;/// Platform Bluetooth id (MAC on Android), if known. Not in web backups.
 String? get bleId;/// The bulb was seen advertising as a new bulb: it was reset outside
/// Luminar and has forgotten the network.
 bool get wasReset;
/// Create a copy of Light
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LightCopyWith<Light> get copyWith => _$LightCopyWithImpl<Light>(this as Light, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Light;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Light&&(identical(other.addr, _this.addr) || other.addr == _this.addr)&&(identical(other.elements, _this.elements) || other.elements == _this.elements)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.devKey, _this.devKey) || other.devKey == _this.devKey)&&(identical(other.configured, _this.configured) || other.configured == _this.configured)&&const DeepCollectionEquality().equals(other.models, _this.models)&&(identical(other.level, _this.level) || other.level == _this.level)&&(identical(other.kelvin, _this.kelvin) || other.kelvin == _this.kelvin)&&const DeepCollectionEquality().equals(other.groupModels, _this.groupModels)&&(identical(other.bleId, _this.bleId) || other.bleId == _this.bleId)&&(identical(other.wasReset, _this.wasReset) || other.wasReset == _this.wasReset));
}


@override
int get hashCode {
  final _this = this as Light;
  return Object.hash(runtimeType,_this.addr,_this.elements,_this.name,_this.devKey,_this.configured,const DeepCollectionEquality().hash(_this.models),_this.level,_this.kelvin,const DeepCollectionEquality().hash(_this.groupModels),_this.bleId,_this.wasReset);
}

@override
String toString() {
  final _this = this as Light;
  return 'Light(addr: ${_this.addr}, elements: ${_this.elements}, name: ${_this.name}, devKey: ${_this.devKey}, configured: ${_this.configured}, models: ${_this.models}, level: ${_this.level}, kelvin: ${_this.kelvin}, groupModels: ${_this.groupModels}, bleId: ${_this.bleId}, wasReset: ${_this.wasReset})';
}


}

/// @nodoc
abstract mixin class $LightCopyWith<$Res>  {
  factory $LightCopyWith(Light value, $Res Function(Light) _then) = _$LightCopyWithImpl;
@useResult
$Res call({
 int addr, int elements, String name, String devKey, bool configured, Map<String, bool> models, int level, int kelvin, Set<String> groupModels, String? bleId, bool wasReset
});




}
/// @nodoc
class _$LightCopyWithImpl<$Res>
    implements $LightCopyWith<$Res> {
  _$LightCopyWithImpl(this._self, this._then);

  final Light _self;
  final $Res Function(Light) _then;

/// Create a copy of Light
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? addr = null,Object? elements = null,Object? name = null,Object? devKey = null,Object? configured = null,Object? models = null,Object? level = null,Object? kelvin = null,Object? groupModels = null,Object? bleId = freezed,Object? wasReset = null,}) {
  return _then(Light(
addr: null == addr ? _self.addr : addr // ignore: cast_nullable_to_non_nullable
as int,elements: null == elements ? _self.elements : elements // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,devKey: null == devKey ? _self.devKey : devKey // ignore: cast_nullable_to_non_nullable
as String,configured: null == configured ? _self.configured : configured // ignore: cast_nullable_to_non_nullable
as bool,models: null == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,kelvin: null == kelvin ? _self.kelvin : kelvin // ignore: cast_nullable_to_non_nullable
as int,groupModels: null == groupModels ? _self.groupModels : groupModels // ignore: cast_nullable_to_non_nullable
as Set<String>,bleId: freezed == bleId ? _self.bleId : bleId // ignore: cast_nullable_to_non_nullable
as String?,wasReset: null == wasReset ? _self.wasReset : wasReset // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Light].
extension LightPatterns on Light {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Light value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Light() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Light value)  $default,){
final _that = this;
switch (_that) {
case _Light():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Light value)?  $default,){
final _that = this;
switch (_that) {
case _Light() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int addr,  int elements,  String name,  String devKey,  bool configured,  Map<String, bool> models,  int level,  int kelvin,  Set<String> groupModels,  String? bleId,  bool wasReset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Light() when $default != null:
return $default(_that.addr,_that.elements,_that.name,_that.devKey,_that.configured,_that.models,_that.level,_that.kelvin,_that.groupModels,_that.bleId,_that.wasReset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int addr,  int elements,  String name,  String devKey,  bool configured,  Map<String, bool> models,  int level,  int kelvin,  Set<String> groupModels,  String? bleId,  bool wasReset)  $default,) {final _that = this;
switch (_that) {
case _Light():
return $default(_that.addr,_that.elements,_that.name,_that.devKey,_that.configured,_that.models,_that.level,_that.kelvin,_that.groupModels,_that.bleId,_that.wasReset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int addr,  int elements,  String name,  String devKey,  bool configured,  Map<String, bool> models,  int level,  int kelvin,  Set<String> groupModels,  String? bleId,  bool wasReset)?  $default,) {final _that = this;
switch (_that) {
case _Light() when $default != null:
return $default(_that.addr,_that.elements,_that.name,_that.devKey,_that.configured,_that.models,_that.level,_that.kelvin,_that.groupModels,_that.bleId,_that.wasReset);case _:
  return null;

}
}

}

/// @nodoc


class _Light extends Light {
  const _Light({required this.addr, this.elements = 1, required this.name, required this.devKey, this.configured = false,  Map<String, bool> models = const {}, this.level = 70, this.kelvin = 3000,  Set<String> groupModels = const {}, this.bleId, this.wasReset = false}): _models = models,_groupModels = groupModels,super._();
  

@override final  int addr;
@override@JsonKey() final  int elements;
@override final  String name;
/// Hex.
@override final  String devKey;
@override@JsonKey() final  bool configured;
/// Models the AppKey is bound to, by key of `Models.bindable`.
 final  Map<String, bool> _models;
/// Models the AppKey is bound to, by key of `Models.bindable`.
@override@JsonKey() Map<String, bool> get models {
  if (_models is EqualUnmodifiableMapView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_models);
}

/// 1–100 %.
@override@JsonKey() final  int level;
@override@JsonKey() final  int kelvin;
/// Models (keys of `Models.bindable`) subscribed to [allLightsGroup].
 final  Set<String> _groupModels;
/// Models (keys of `Models.bindable`) subscribed to [allLightsGroup].
@override@JsonKey() Set<String> get groupModels {
  if (_groupModels is EqualUnmodifiableSetView) return _groupModels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_groupModels);
}

/// Platform Bluetooth id (MAC on Android), if known. Not in web backups.
@override final  String? bleId;
/// The bulb was seen advertising as a new bulb: it was reset outside
/// Luminar and has forgotten the network.
@override@JsonKey() final  bool wasReset;

/// Create a copy of Light
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LightCopyWith<_Light> get copyWith => __$LightCopyWithImpl<_Light>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Light&&(identical(other.addr, addr) || other.addr == addr)&&(identical(other.elements, elements) || other.elements == elements)&&(identical(other.name, name) || other.name == name)&&(identical(other.devKey, devKey) || other.devKey == devKey)&&(identical(other.configured, configured) || other.configured == configured)&&const DeepCollectionEquality().equals(other.models, _models)&&(identical(other.level, level) || other.level == level)&&(identical(other.kelvin, kelvin) || other.kelvin == kelvin)&&const DeepCollectionEquality().equals(other.groupModels, _groupModels)&&(identical(other.bleId, bleId) || other.bleId == bleId)&&(identical(other.wasReset, wasReset) || other.wasReset == wasReset));
}


@override
int get hashCode {
    return Object.hash(runtimeType,addr,elements,name,devKey,configured,const DeepCollectionEquality().hash(_models),level,kelvin,const DeepCollectionEquality().hash(_groupModels),bleId,wasReset);
}

@override
String toString() {
    return 'Light(addr: $addr, elements: $elements, name: $name, devKey: $devKey, configured: $configured, models: $models, level: $level, kelvin: $kelvin, groupModels: $groupModels, bleId: $bleId, wasReset: $wasReset)';
}


}

/// @nodoc
abstract mixin class _$LightCopyWith<$Res> implements $LightCopyWith<$Res> {
  factory _$LightCopyWith(_Light value, $Res Function(_Light) _then) = __$LightCopyWithImpl;
@override @useResult
$Res call({
 int addr, int elements, String name, String devKey, bool configured, Map<String, bool> models, int level, int kelvin, Set<String> groupModels, String? bleId, bool wasReset
});




}
/// @nodoc
class __$LightCopyWithImpl<$Res>
    implements _$LightCopyWith<$Res> {
  __$LightCopyWithImpl(this._self, this._then);

  final _Light _self;
  final $Res Function(_Light) _then;

/// Create a copy of Light
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? addr = null,Object? elements = null,Object? name = null,Object? devKey = null,Object? configured = null,Object? models = null,Object? level = null,Object? kelvin = null,Object? groupModels = null,Object? bleId = freezed,Object? wasReset = null,}) {
  return _then(_Light(
addr: null == addr ? _self.addr : addr // ignore: cast_nullable_to_non_nullable
as int,elements: null == elements ? _self.elements : elements // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,devKey: null == devKey ? _self.devKey : devKey // ignore: cast_nullable_to_non_nullable
as String,configured: null == configured ? _self.configured : configured // ignore: cast_nullable_to_non_nullable
as bool,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as Map<String, bool>,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as int,kelvin: null == kelvin ? _self.kelvin : kelvin // ignore: cast_nullable_to_non_nullable
as int,groupModels: null == groupModels ? _self._groupModels : groupModels // ignore: cast_nullable_to_non_nullable
as Set<String>,bleId: freezed == bleId ? _self.bleId : bleId // ignore: cast_nullable_to_non_nullable
as String?,wasReset: null == wasReset ? _self.wasReset : wasReset // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
