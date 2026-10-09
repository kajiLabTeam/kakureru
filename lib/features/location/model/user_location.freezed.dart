// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_location.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserLocation {

 String get uid;@JsonKey(name: 'lat') double get latitude;@JsonKey(name: 'lng') double get longitude; double? get altitude; double? get accuracy;@JsonKey(name: 'snapLat') double? get snapLatitude;@JsonKey(name: 'snapLng') double? get snapLongitude; double? get pressure; WifiScanResult? get wifiScan; int get updatedAt;
/// Create a copy of UserLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserLocationCopyWith<UserLocation> get copyWith => _$UserLocationCopyWithImpl<UserLocation>(this as UserLocation, _$identity);

  /// Serializes this UserLocation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as UserLocation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserLocation&&(identical(other.uid, _this.uid) || other.uid == _this.uid)&&(identical(other.latitude, _this.latitude) || other.latitude == _this.latitude)&&(identical(other.longitude, _this.longitude) || other.longitude == _this.longitude)&&(identical(other.altitude, _this.altitude) || other.altitude == _this.altitude)&&(identical(other.accuracy, _this.accuracy) || other.accuracy == _this.accuracy)&&(identical(other.snapLatitude, _this.snapLatitude) || other.snapLatitude == _this.snapLatitude)&&(identical(other.snapLongitude, _this.snapLongitude) || other.snapLongitude == _this.snapLongitude)&&(identical(other.pressure, _this.pressure) || other.pressure == _this.pressure)&&(identical(other.wifiScan, _this.wifiScan) || other.wifiScan == _this.wifiScan)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as UserLocation;
  return Object.hash(runtimeType,_this.uid,_this.latitude,_this.longitude,_this.altitude,_this.accuracy,_this.snapLatitude,_this.snapLongitude,_this.pressure,_this.wifiScan,_this.updatedAt);
}

@override
String toString() {
  final _this = this as UserLocation;
  return 'UserLocation(uid: ${_this.uid}, latitude: ${_this.latitude}, longitude: ${_this.longitude}, altitude: ${_this.altitude}, accuracy: ${_this.accuracy}, snapLatitude: ${_this.snapLatitude}, snapLongitude: ${_this.snapLongitude}, pressure: ${_this.pressure}, wifiScan: ${_this.wifiScan}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $UserLocationCopyWith<$Res>  {
  factory $UserLocationCopyWith(UserLocation value, $Res Function(UserLocation) _then) = _$UserLocationCopyWithImpl;
@useResult
$Res call({
 String uid,@JsonKey(name: 'lat') double latitude,@JsonKey(name: 'lng') double longitude, double? altitude, double? accuracy,@JsonKey(name: 'snapLat') double? snapLatitude,@JsonKey(name: 'snapLng') double? snapLongitude, double? pressure, WifiScanResult? wifiScan, int updatedAt
});


$WifiScanResultCopyWith<$Res>? get wifiScan;

}
/// @nodoc
class _$UserLocationCopyWithImpl<$Res>
    implements $UserLocationCopyWith<$Res> {
  _$UserLocationCopyWithImpl(this._self, this._then);

  final UserLocation _self;
  final $Res Function(UserLocation) _then;

/// Create a copy of UserLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,Object? latitude = null,Object? longitude = null,Object? altitude = freezed,Object? accuracy = freezed,Object? snapLatitude = freezed,Object? snapLongitude = freezed,Object? pressure = freezed,Object? wifiScan = freezed,Object? updatedAt = null,}) {
  return _then(UserLocation(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,altitude: freezed == altitude ? _self.altitude : altitude // ignore: cast_nullable_to_non_nullable
as double?,accuracy: freezed == accuracy ? _self.accuracy : accuracy // ignore: cast_nullable_to_non_nullable
as double?,snapLatitude: freezed == snapLatitude ? _self.snapLatitude : snapLatitude // ignore: cast_nullable_to_non_nullable
as double?,snapLongitude: freezed == snapLongitude ? _self.snapLongitude : snapLongitude // ignore: cast_nullable_to_non_nullable
as double?,pressure: freezed == pressure ? _self.pressure : pressure // ignore: cast_nullable_to_non_nullable
as double?,wifiScan: freezed == wifiScan ? _self.wifiScan : wifiScan // ignore: cast_nullable_to_non_nullable
as WifiScanResult?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of UserLocation
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WifiScanResultCopyWith<$Res>? get wifiScan {
    if (_self.wifiScan == null) {
    return null;
  }

  return $WifiScanResultCopyWith<$Res>(_self.wifiScan!, (value) {
    return _then(_self.copyWith(wifiScan: value));
  });
}
}


/// Adds pattern-matching-related methods to [UserLocation].
extension UserLocationPatterns on UserLocation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserLocation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserLocation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserLocation value)  $default,){
final _that = this;
switch (_that) {
case _UserLocation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserLocation value)?  $default,){
final _that = this;
switch (_that) {
case _UserLocation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uid, @JsonKey(name: 'lat')  double latitude, @JsonKey(name: 'lng')  double longitude,  double? altitude,  double? accuracy, @JsonKey(name: 'snapLat')  double? snapLatitude, @JsonKey(name: 'snapLng')  double? snapLongitude,  double? pressure,  WifiScanResult? wifiScan,  int updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserLocation() when $default != null:
return $default(_that.uid,_that.latitude,_that.longitude,_that.altitude,_that.accuracy,_that.snapLatitude,_that.snapLongitude,_that.pressure,_that.wifiScan,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uid, @JsonKey(name: 'lat')  double latitude, @JsonKey(name: 'lng')  double longitude,  double? altitude,  double? accuracy, @JsonKey(name: 'snapLat')  double? snapLatitude, @JsonKey(name: 'snapLng')  double? snapLongitude,  double? pressure,  WifiScanResult? wifiScan,  int updatedAt)  $default,) {final _that = this;
switch (_that) {
case _UserLocation():
return $default(_that.uid,_that.latitude,_that.longitude,_that.altitude,_that.accuracy,_that.snapLatitude,_that.snapLongitude,_that.pressure,_that.wifiScan,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uid, @JsonKey(name: 'lat')  double latitude, @JsonKey(name: 'lng')  double longitude,  double? altitude,  double? accuracy, @JsonKey(name: 'snapLat')  double? snapLatitude, @JsonKey(name: 'snapLng')  double? snapLongitude,  double? pressure,  WifiScanResult? wifiScan,  int updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _UserLocation() when $default != null:
return $default(_that.uid,_that.latitude,_that.longitude,_that.altitude,_that.accuracy,_that.snapLatitude,_that.snapLongitude,_that.pressure,_that.wifiScan,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserLocation extends UserLocation {
  const _UserLocation({required this.uid, @JsonKey(name: 'lat') required this.latitude, @JsonKey(name: 'lng') required this.longitude, this.altitude, this.accuracy, @JsonKey(name: 'snapLat') this.snapLatitude, @JsonKey(name: 'snapLng') this.snapLongitude, this.pressure, this.wifiScan, this.updatedAt = 0}): super._();
  factory _UserLocation.fromJson(Map<String, dynamic> json) => _$UserLocationFromJson(json);

@override final  String uid;
@override@JsonKey(name: 'lat') final  double latitude;
@override@JsonKey(name: 'lng') final  double longitude;
@override final  double? altitude;
@override final  double? accuracy;
@override@JsonKey(name: 'snapLat') final  double? snapLatitude;
@override@JsonKey(name: 'snapLng') final  double? snapLongitude;
@override final  double? pressure;
@override final  WifiScanResult? wifiScan;
@override@JsonKey() final  int updatedAt;

/// Create a copy of UserLocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserLocationCopyWith<_UserLocation> get copyWith => __$UserLocationCopyWithImpl<_UserLocation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserLocationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserLocation&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.latitude, latitude) || other.latitude == latitude)&&(identical(other.longitude, longitude) || other.longitude == longitude)&&(identical(other.altitude, altitude) || other.altitude == altitude)&&(identical(other.accuracy, accuracy) || other.accuracy == accuracy)&&(identical(other.snapLatitude, snapLatitude) || other.snapLatitude == snapLatitude)&&(identical(other.snapLongitude, snapLongitude) || other.snapLongitude == snapLongitude)&&(identical(other.pressure, pressure) || other.pressure == pressure)&&(identical(other.wifiScan, wifiScan) || other.wifiScan == wifiScan)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,uid,latitude,longitude,altitude,accuracy,snapLatitude,snapLongitude,pressure,wifiScan,updatedAt);
}

@override
String toString() {
    return 'UserLocation(uid: $uid, latitude: $latitude, longitude: $longitude, altitude: $altitude, accuracy: $accuracy, snapLatitude: $snapLatitude, snapLongitude: $snapLongitude, pressure: $pressure, wifiScan: $wifiScan, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$UserLocationCopyWith<$Res> implements $UserLocationCopyWith<$Res> {
  factory _$UserLocationCopyWith(_UserLocation value, $Res Function(_UserLocation) _then) = __$UserLocationCopyWithImpl;
@override @useResult
$Res call({
 String uid,@JsonKey(name: 'lat') double latitude,@JsonKey(name: 'lng') double longitude, double? altitude, double? accuracy,@JsonKey(name: 'snapLat') double? snapLatitude,@JsonKey(name: 'snapLng') double? snapLongitude, double? pressure, WifiScanResult? wifiScan, int updatedAt
});


@override $WifiScanResultCopyWith<$Res>? get wifiScan;

}
/// @nodoc
class __$UserLocationCopyWithImpl<$Res>
    implements _$UserLocationCopyWith<$Res> {
  __$UserLocationCopyWithImpl(this._self, this._then);

  final _UserLocation _self;
  final $Res Function(_UserLocation) _then;

/// Create a copy of UserLocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? latitude = null,Object? longitude = null,Object? altitude = freezed,Object? accuracy = freezed,Object? snapLatitude = freezed,Object? snapLongitude = freezed,Object? pressure = freezed,Object? wifiScan = freezed,Object? updatedAt = null,}) {
  return _then(_UserLocation(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,latitude: null == latitude ? _self.latitude : latitude // ignore: cast_nullable_to_non_nullable
as double,longitude: null == longitude ? _self.longitude : longitude // ignore: cast_nullable_to_non_nullable
as double,altitude: freezed == altitude ? _self.altitude : altitude // ignore: cast_nullable_to_non_nullable
as double?,accuracy: freezed == accuracy ? _self.accuracy : accuracy // ignore: cast_nullable_to_non_nullable
as double?,snapLatitude: freezed == snapLatitude ? _self.snapLatitude : snapLatitude // ignore: cast_nullable_to_non_nullable
as double?,snapLongitude: freezed == snapLongitude ? _self.snapLongitude : snapLongitude // ignore: cast_nullable_to_non_nullable
as double?,pressure: freezed == pressure ? _self.pressure : pressure // ignore: cast_nullable_to_non_nullable
as double?,wifiScan: freezed == wifiScan ? _self.wifiScan : wifiScan // ignore: cast_nullable_to_non_nullable
as WifiScanResult?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of UserLocation
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WifiScanResultCopyWith<$Res>? get wifiScan {
    if (_self.wifiScan == null) {
    return null;
  }

  return $WifiScanResultCopyWith<$Res>(_self.wifiScan!, (value) {
    return _then(_self.copyWith(wifiScan: value));
  });
}
}

// dart format on
