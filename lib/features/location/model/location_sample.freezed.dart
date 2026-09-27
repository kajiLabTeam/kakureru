// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'location_sample.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LocationSample {

 double get latitude; double get longitude; double? get altitude;/// 測位の誤差(m)。大きいほど信頼できない。
 double? get accuracy;/// 端末が測位した時刻(エポックミリ秒)。順序の逆転を検出するのに使う。
 int? get timestampMs;
/// Create a copy of LocationSample
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocationSampleCopyWith<LocationSample> get copyWith => _$LocationSampleCopyWithImpl<LocationSample>(this as LocationSample, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocationSample&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.altitude, altitude) || other.altitude == altitude)&&(identical(other.accuracy, accuracy) || other.accuracy == accuracy)&&(identical(other.timestampMs, timestampMs) || other.timestampMs == timestampMs));
}


@override
int get hashCode => Object.hash(runtimeType,latitude,longitude,altitude,accuracy,timestampMs);

@override
String toString() {
  return 'LocationSample(latitude: $latitude, longitude: $longitude, altitude: $altitude, accuracy: $accuracy, timestampMs: $timestampMs)';
}


}

/// @nodoc
abstract mixin class $LocationSampleCopyWith<$Res>  {
  factory $LocationSampleCopyWith(LocationSample value, $Res Function(LocationSample) _then) = _$LocationSampleCopyWithImpl;
@useResult
$Res call({
 double latitude, double longitude, double? altitude, double? accuracy, int? timestampMs
});




}
/// @nodoc
class _$LocationSampleCopyWithImpl<$Res>
    implements $LocationSampleCopyWith<$Res> {
  _$LocationSampleCopyWithImpl(this._self, this._then);

  final LocationSample _self;
  final $Res Function(LocationSample) _then;

/// Create a copy of LocationSample
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? latitude = null,Object? longitude = null,Object? altitude = freezed,Object? accuracy = freezed,Object? timestampMs = freezed,}) {
  return _then(_self.copyWith(
latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,altitude: freezed == altitude ? _self.altitude : altitude // ignore: cast_nullable_to_non_nullable
as double?,accuracy: freezed == accuracy ? _self.accuracy : accuracy // ignore: cast_nullable_to_non_nullable
as double?,timestampMs: freezed == timestampMs ? _self.timestampMs : timestampMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [LocationSample].
extension LocationSamplePatterns on LocationSample {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LocationSample value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LocationSample() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LocationSample value)  $default,){
final _that = this;
switch (_that) {
case _LocationSample():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LocationSample value)?  $default,){
final _that = this;
switch (_that) {
case _LocationSample() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double latitude,  double longitude,  double? altitude,  double? accuracy,  int? timestampMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LocationSample() when $default != null:
return $default(_that.latitude,_that.longitude,_that.altitude,_that.accuracy,_that.timestampMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double latitude,  double longitude,  double? altitude,  double? accuracy,  int? timestampMs)  $default,) {final _that = this;
switch (_that) {
case _LocationSample():
return $default(_that.latitude,_that.longitude,_that.altitude,_that.accuracy,_that.timestampMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double latitude,  double longitude,  double? altitude,  double? accuracy,  int? timestampMs)?  $default,) {final _that = this;
switch (_that) {
case _LocationSample() when $default != null:
return $default(_that.latitude,_that.longitude,_that.altitude,_that.accuracy,_that.timestampMs);case _:
  return null;

}
}

}

/// @nodoc


class _LocationSample implements LocationSample {
  const _LocationSample({required this.latitude, required this.longitude, this.altitude, this.accuracy, this.timestampMs});
  

@override final  double latitude;
@override final  double longitude;
@override final  double? altitude;
/// 測位の誤差(m)。大きいほど信頼できない。
@override final  double? accuracy;
/// 端末が測位した時刻(エポックミリ秒)。順序の逆転を検出するのに使う。
@override final  int? timestampMs;

/// Create a copy of LocationSample
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocationSampleCopyWith<_LocationSample> get copyWith => __$LocationSampleCopyWithImpl<_LocationSample>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LocationSample&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.altitude, altitude) || other.altitude == altitude)&&(identical(other.accuracy, accuracy) || other.accuracy == accuracy)&&(identical(other.timestampMs, timestampMs) || other.timestampMs == timestampMs));
}


@override
int get hashCode => Object.hash(runtimeType,latitude,longitude,altitude,accuracy,timestampMs);

@override
String toString() {
  return 'LocationSample(latitude: $latitude, longitude: $longitude, altitude: $altitude, accuracy: $accuracy, timestampMs: $timestampMs)';
}


}

/// @nodoc
abstract mixin class _$LocationSampleCopyWith<$Res> implements $LocationSampleCopyWith<$Res> {
  factory _$LocationSampleCopyWith(_LocationSample value, $Res Function(_LocationSample) _then) = __$LocationSampleCopyWithImpl;
@override @useResult
$Res call({
 double latitude, double longitude, double? altitude, double? accuracy, int? timestampMs
});




}
/// @nodoc
class __$LocationSampleCopyWithImpl<$Res>
    implements _$LocationSampleCopyWith<$Res> {
  __$LocationSampleCopyWithImpl(this._self, this._then);

  final _LocationSample _self;
  final $Res Function(_LocationSample) _then;

/// Create a copy of LocationSample
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? latitude = null,Object? longitude = null,Object? altitude = freezed,Object? accuracy = freezed,Object? timestampMs = freezed,}) {
  return _then(_LocationSample(
latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,altitude: freezed == altitude ? _self.altitude : altitude // ignore: cast_nullable_to_non_nullable
as double?,accuracy: freezed == accuracy ? _self.accuracy : accuracy // ignore: cast_nullable_to_non_nullable
as double?,timestampMs: freezed == timestampMs ? _self.timestampMs : timestampMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
