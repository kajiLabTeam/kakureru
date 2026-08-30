// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ble_detection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BleDetection {

 String get shortUid; int get rssiDbm; int get detectedAtMillis;
/// Create a copy of BleDetection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BleDetectionCopyWith<BleDetection> get copyWith => _$BleDetectionCopyWithImpl<BleDetection>(this as BleDetection, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BleDetection&&(identical(other.shortUid, shortUid) || other.shortUid == shortUid)&&(identical(other.rssiDbm, rssiDbm) || other.rssiDbm == rssiDbm)&&(identical(other.detectedAtMillis, detectedAtMillis) || other.detectedAtMillis == detectedAtMillis));
}


@override
int get hashCode => Object.hash(runtimeType,shortUid,rssiDbm,detectedAtMillis);

@override
String toString() {
  return 'BleDetection(shortUid: $shortUid, rssiDbm: $rssiDbm, detectedAtMillis: $detectedAtMillis)';
}


}

/// @nodoc
abstract mixin class $BleDetectionCopyWith<$Res>  {
  factory $BleDetectionCopyWith(BleDetection value, $Res Function(BleDetection) _then) = _$BleDetectionCopyWithImpl;
@useResult
$Res call({
 String shortUid, int rssiDbm, int detectedAtMillis
});




}
/// @nodoc
class _$BleDetectionCopyWithImpl<$Res>
    implements $BleDetectionCopyWith<$Res> {
  _$BleDetectionCopyWithImpl(this._self, this._then);

  final BleDetection _self;
  final $Res Function(BleDetection) _then;

/// Create a copy of BleDetection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? shortUid = null,Object? rssiDbm = null,Object? detectedAtMillis = null,}) {
  return _then(_self.copyWith(
shortUid: null == shortUid ? _self.shortUid : shortUid // ignore: cast_nullable_to_non_nullable
as String,rssiDbm: null == rssiDbm ? _self.rssiDbm : rssiDbm // ignore: cast_nullable_to_non_nullable
as int,detectedAtMillis: null == detectedAtMillis ? _self.detectedAtMillis : detectedAtMillis // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [BleDetection].
extension BleDetectionPatterns on BleDetection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BleDetection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BleDetection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BleDetection value)  $default,){
final _that = this;
switch (_that) {
case _BleDetection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BleDetection value)?  $default,){
final _that = this;
switch (_that) {
case _BleDetection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String shortUid,  int rssiDbm,  int detectedAtMillis)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BleDetection() when $default != null:
return $default(_that.shortUid,_that.rssiDbm,_that.detectedAtMillis);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String shortUid,  int rssiDbm,  int detectedAtMillis)  $default,) {final _that = this;
switch (_that) {
case _BleDetection():
return $default(_that.shortUid,_that.rssiDbm,_that.detectedAtMillis);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String shortUid,  int rssiDbm,  int detectedAtMillis)?  $default,) {final _that = this;
switch (_that) {
case _BleDetection() when $default != null:
return $default(_that.shortUid,_that.rssiDbm,_that.detectedAtMillis);case _:
  return null;

}
}

}

/// @nodoc


class _BleDetection implements BleDetection {
  const _BleDetection({required this.shortUid, required this.rssiDbm, required this.detectedAtMillis});
  

@override final  String shortUid;
@override final  int rssiDbm;
@override final  int detectedAtMillis;

/// Create a copy of BleDetection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BleDetectionCopyWith<_BleDetection> get copyWith => __$BleDetectionCopyWithImpl<_BleDetection>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BleDetection&&(identical(other.shortUid, shortUid) || other.shortUid == shortUid)&&(identical(other.rssiDbm, rssiDbm) || other.rssiDbm == rssiDbm)&&(identical(other.detectedAtMillis, detectedAtMillis) || other.detectedAtMillis == detectedAtMillis));
}


@override
int get hashCode => Object.hash(runtimeType,shortUid,rssiDbm,detectedAtMillis);

@override
String toString() {
  return 'BleDetection(shortUid: $shortUid, rssiDbm: $rssiDbm, detectedAtMillis: $detectedAtMillis)';
}


}

/// @nodoc
abstract mixin class _$BleDetectionCopyWith<$Res> implements $BleDetectionCopyWith<$Res> {
  factory _$BleDetectionCopyWith(_BleDetection value, $Res Function(_BleDetection) _then) = __$BleDetectionCopyWithImpl;
@override @useResult
$Res call({
 String shortUid, int rssiDbm, int detectedAtMillis
});




}
/// @nodoc
class __$BleDetectionCopyWithImpl<$Res>
    implements _$BleDetectionCopyWith<$Res> {
  __$BleDetectionCopyWithImpl(this._self, this._then);

  final _BleDetection _self;
  final $Res Function(_BleDetection) _then;

/// Create a copy of BleDetection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? shortUid = null,Object? rssiDbm = null,Object? detectedAtMillis = null,}) {
  return _then(_BleDetection(
shortUid: null == shortUid ? _self.shortUid : shortUid // ignore: cast_nullable_to_non_nullable
as String,rssiDbm: null == rssiDbm ? _self.rssiDbm : rssiDbm // ignore: cast_nullable_to_non_nullable
as int,detectedAtMillis: null == detectedAtMillis ? _self.detectedAtMillis : detectedAtMillis // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
