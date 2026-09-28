// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'clue_meter_sample.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ClueMeterSample {

/// 測った時刻(端末の時計)。
 DateTime get at;/// 0〜100。`calculateClueMeter`の戻り値。
 double get meter;
/// Create a copy of ClueMeterSample
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClueMeterSampleCopyWith<ClueMeterSample> get copyWith => _$ClueMeterSampleCopyWithImpl<ClueMeterSample>(this as ClueMeterSample, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClueMeterSample&&(identical(other.at, at) || other.at == at)&&(identical(other.meter, meter) || other.meter == meter));
}


@override
int get hashCode => Object.hash(runtimeType,at,meter);

@override
String toString() {
  return 'ClueMeterSample(at: $at, meter: $meter)';
}


}

/// @nodoc
abstract mixin class $ClueMeterSampleCopyWith<$Res>  {
  factory $ClueMeterSampleCopyWith(ClueMeterSample value, $Res Function(ClueMeterSample) _then) = _$ClueMeterSampleCopyWithImpl;
@useResult
$Res call({
 DateTime at, double meter
});




}
/// @nodoc
class _$ClueMeterSampleCopyWithImpl<$Res>
    implements $ClueMeterSampleCopyWith<$Res> {
  _$ClueMeterSampleCopyWithImpl(this._self, this._then);

  final ClueMeterSample _self;
  final $Res Function(ClueMeterSample) _then;

/// Create a copy of ClueMeterSample
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? at = null,Object? meter = null,}) {
  return _then(_self.copyWith(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,meter: null == meter ? _self.meter : meter // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [ClueMeterSample].
extension ClueMeterSamplePatterns on ClueMeterSample {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClueMeterSample value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClueMeterSample() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClueMeterSample value)  $default,){
final _that = this;
switch (_that) {
case _ClueMeterSample():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClueMeterSample value)?  $default,){
final _that = this;
switch (_that) {
case _ClueMeterSample() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime at,  double meter)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClueMeterSample() when $default != null:
return $default(_that.at,_that.meter);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime at,  double meter)  $default,) {final _that = this;
switch (_that) {
case _ClueMeterSample():
return $default(_that.at,_that.meter);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime at,  double meter)?  $default,) {final _that = this;
switch (_that) {
case _ClueMeterSample() when $default != null:
return $default(_that.at,_that.meter);case _:
  return null;

}
}

}

/// @nodoc


class _ClueMeterSample implements ClueMeterSample {
  const _ClueMeterSample({required this.at, required this.meter});
  

/// 測った時刻(端末の時計)。
@override final  DateTime at;
/// 0〜100。`calculateClueMeter`の戻り値。
@override final  double meter;

/// Create a copy of ClueMeterSample
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClueMeterSampleCopyWith<_ClueMeterSample> get copyWith => __$ClueMeterSampleCopyWithImpl<_ClueMeterSample>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClueMeterSample&&(identical(other.at, at) || other.at == at)&&(identical(other.meter, meter) || other.meter == meter));
}


@override
int get hashCode => Object.hash(runtimeType,at,meter);

@override
String toString() {
  return 'ClueMeterSample(at: $at, meter: $meter)';
}


}

/// @nodoc
abstract mixin class _$ClueMeterSampleCopyWith<$Res> implements $ClueMeterSampleCopyWith<$Res> {
  factory _$ClueMeterSampleCopyWith(_ClueMeterSample value, $Res Function(_ClueMeterSample) _then) = __$ClueMeterSampleCopyWithImpl;
@override @useResult
$Res call({
 DateTime at, double meter
});




}
/// @nodoc
class __$ClueMeterSampleCopyWithImpl<$Res>
    implements _$ClueMeterSampleCopyWith<$Res> {
  __$ClueMeterSampleCopyWithImpl(this._self, this._then);

  final _ClueMeterSample _self;
  final $Res Function(_ClueMeterSample) _then;

/// Create a copy of ClueMeterSample
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? at = null,Object? meter = null,}) {
  return _then(_ClueMeterSample(
at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,meter: null == meter ? _self.meter : meter // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
