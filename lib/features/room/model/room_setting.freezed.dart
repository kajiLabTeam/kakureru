// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_setting.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LatLng {

 double get lat; double get lng;
/// Create a copy of LatLng
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LatLngCopyWith<LatLng> get copyWith => _$LatLngCopyWithImpl<LatLng>(this as LatLng, _$identity);

  /// Serializes this LatLng to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LatLng&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lat,lng);

@override
String toString() {
  return 'LatLng(lat: $lat, lng: $lng)';
}


}

/// @nodoc
abstract mixin class $LatLngCopyWith<$Res>  {
  factory $LatLngCopyWith(LatLng value, $Res Function(LatLng) _then) = _$LatLngCopyWithImpl;
@useResult
$Res call({
 double lat, double lng
});




}
/// @nodoc
class _$LatLngCopyWithImpl<$Res>
    implements $LatLngCopyWith<$Res> {
  _$LatLngCopyWithImpl(this._self, this._then);

  final LatLng _self;
  final $Res Function(LatLng) _then;

/// Create a copy of LatLng
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lat = null,Object? lng = null,}) {
  return _then(_self.copyWith(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [LatLng].
extension LatLngPatterns on LatLng {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LatLng value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LatLng() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LatLng value)  $default,){
final _that = this;
switch (_that) {
case _LatLng():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LatLng value)?  $default,){
final _that = this;
switch (_that) {
case _LatLng() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double lat,  double lng)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LatLng() when $default != null:
return $default(_that.lat,_that.lng);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double lat,  double lng)  $default,) {final _that = this;
switch (_that) {
case _LatLng():
return $default(_that.lat,_that.lng);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double lat,  double lng)?  $default,) {final _that = this;
switch (_that) {
case _LatLng() when $default != null:
return $default(_that.lat,_that.lng);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LatLng implements LatLng {
  const _LatLng({required this.lat, required this.lng});
  factory _LatLng.fromJson(Map<String, dynamic> json) => _$LatLngFromJson(json);

@override final  double lat;
@override final  double lng;

/// Create a copy of LatLng
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LatLngCopyWith<_LatLng> get copyWith => __$LatLngCopyWithImpl<_LatLng>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LatLngToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LatLng&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lat,lng);

@override
String toString() {
  return 'LatLng(lat: $lat, lng: $lng)';
}


}

/// @nodoc
abstract mixin class _$LatLngCopyWith<$Res> implements $LatLngCopyWith<$Res> {
  factory _$LatLngCopyWith(_LatLng value, $Res Function(_LatLng) _then) = __$LatLngCopyWithImpl;
@override @useResult
$Res call({
 double lat, double lng
});




}
/// @nodoc
class __$LatLngCopyWithImpl<$Res>
    implements _$LatLngCopyWith<$Res> {
  __$LatLngCopyWithImpl(this._self, this._then);

  final _LatLng _self;
  final $Res Function(_LatLng) _then;

/// Create a copy of LatLng
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lat = null,Object? lng = null,}) {
  return _then(_LatLng(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$RoomSetting {

 List<LatLng> get gameArea; int get releaseWaitSec; int get gameDurationSec; int get photoIntervalSec; int get fugitiveInfoDelaySec; int get senseDistanceRadiusM; int? get updatedAt;
/// Create a copy of RoomSetting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomSettingCopyWith<RoomSetting> get copyWith => _$RoomSettingCopyWithImpl<RoomSetting>(this as RoomSetting, _$identity);

  /// Serializes this RoomSetting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomSetting&&const DeepCollectionEquality().equals(other.gameArea, gameArea)&&(identical(other.releaseWaitSec, releaseWaitSec) || other.releaseWaitSec == releaseWaitSec)&&(identical(other.gameDurationSec, gameDurationSec) || other.gameDurationSec == gameDurationSec)&&(identical(other.photoIntervalSec, photoIntervalSec) || other.photoIntervalSec == photoIntervalSec)&&(identical(other.fugitiveInfoDelaySec, fugitiveInfoDelaySec) || other.fugitiveInfoDelaySec == fugitiveInfoDelaySec)&&(identical(other.senseDistanceRadiusM, senseDistanceRadiusM) || other.senseDistanceRadiusM == senseDistanceRadiusM)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(gameArea),releaseWaitSec,gameDurationSec,photoIntervalSec,fugitiveInfoDelaySec,senseDistanceRadiusM,updatedAt);

@override
String toString() {
  return 'RoomSetting(gameArea: $gameArea, releaseWaitSec: $releaseWaitSec, gameDurationSec: $gameDurationSec, photoIntervalSec: $photoIntervalSec, fugitiveInfoDelaySec: $fugitiveInfoDelaySec, senseDistanceRadiusM: $senseDistanceRadiusM, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $RoomSettingCopyWith<$Res>  {
  factory $RoomSettingCopyWith(RoomSetting value, $Res Function(RoomSetting) _then) = _$RoomSettingCopyWithImpl;
@useResult
$Res call({
 List<LatLng> gameArea, int releaseWaitSec, int gameDurationSec, int photoIntervalSec, int fugitiveInfoDelaySec, int senseDistanceRadiusM, int? updatedAt
});




}
/// @nodoc
class _$RoomSettingCopyWithImpl<$Res>
    implements $RoomSettingCopyWith<$Res> {
  _$RoomSettingCopyWithImpl(this._self, this._then);

  final RoomSetting _self;
  final $Res Function(RoomSetting) _then;

/// Create a copy of RoomSetting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? gameArea = null,Object? releaseWaitSec = null,Object? gameDurationSec = null,Object? photoIntervalSec = null,Object? fugitiveInfoDelaySec = null,Object? senseDistanceRadiusM = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
gameArea: null == gameArea ? _self.gameArea : gameArea // ignore: cast_nullable_to_non_nullable
as List<LatLng>,releaseWaitSec: null == releaseWaitSec ? _self.releaseWaitSec : releaseWaitSec // ignore: cast_nullable_to_non_nullable
as int,gameDurationSec: null == gameDurationSec ? _self.gameDurationSec : gameDurationSec // ignore: cast_nullable_to_non_nullable
as int,photoIntervalSec: null == photoIntervalSec ? _self.photoIntervalSec : photoIntervalSec // ignore: cast_nullable_to_non_nullable
as int,fugitiveInfoDelaySec: null == fugitiveInfoDelaySec ? _self.fugitiveInfoDelaySec : fugitiveInfoDelaySec // ignore: cast_nullable_to_non_nullable
as int,senseDistanceRadiusM: null == senseDistanceRadiusM ? _self.senseDistanceRadiusM : senseDistanceRadiusM // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomSetting].
extension RoomSettingPatterns on RoomSetting {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomSetting value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomSetting() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomSetting value)  $default,){
final _that = this;
switch (_that) {
case _RoomSetting():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomSetting value)?  $default,){
final _that = this;
switch (_that) {
case _RoomSetting() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<LatLng> gameArea,  int releaseWaitSec,  int gameDurationSec,  int photoIntervalSec,  int fugitiveInfoDelaySec,  int senseDistanceRadiusM,  int? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomSetting() when $default != null:
return $default(_that.gameArea,_that.releaseWaitSec,_that.gameDurationSec,_that.photoIntervalSec,_that.fugitiveInfoDelaySec,_that.senseDistanceRadiusM,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<LatLng> gameArea,  int releaseWaitSec,  int gameDurationSec,  int photoIntervalSec,  int fugitiveInfoDelaySec,  int senseDistanceRadiusM,  int? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _RoomSetting():
return $default(_that.gameArea,_that.releaseWaitSec,_that.gameDurationSec,_that.photoIntervalSec,_that.fugitiveInfoDelaySec,_that.senseDistanceRadiusM,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<LatLng> gameArea,  int releaseWaitSec,  int gameDurationSec,  int photoIntervalSec,  int fugitiveInfoDelaySec,  int senseDistanceRadiusM,  int? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _RoomSetting() when $default != null:
return $default(_that.gameArea,_that.releaseWaitSec,_that.gameDurationSec,_that.photoIntervalSec,_that.fugitiveInfoDelaySec,_that.senseDistanceRadiusM,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomSetting extends RoomSetting {
  const _RoomSetting({final  List<LatLng> gameArea = const [], this.releaseWaitSec = 60, this.gameDurationSec = 1800, this.photoIntervalSec = 300, this.fugitiveInfoDelaySec = 60, this.senseDistanceRadiusM = 50, this.updatedAt}): _gameArea = gameArea,super._();
  factory _RoomSetting.fromJson(Map<String, dynamic> json) => _$RoomSettingFromJson(json);

 final  List<LatLng> _gameArea;
@override@JsonKey() List<LatLng> get gameArea {
  if (_gameArea is EqualUnmodifiableListView) return _gameArea;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_gameArea);
}

@override@JsonKey() final  int releaseWaitSec;
@override@JsonKey() final  int gameDurationSec;
@override@JsonKey() final  int photoIntervalSec;
@override@JsonKey() final  int fugitiveInfoDelaySec;
@override@JsonKey() final  int senseDistanceRadiusM;
@override final  int? updatedAt;

/// Create a copy of RoomSetting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomSettingCopyWith<_RoomSetting> get copyWith => __$RoomSettingCopyWithImpl<_RoomSetting>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomSettingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomSetting&&const DeepCollectionEquality().equals(other._gameArea, _gameArea)&&(identical(other.releaseWaitSec, releaseWaitSec) || other.releaseWaitSec == releaseWaitSec)&&(identical(other.gameDurationSec, gameDurationSec) || other.gameDurationSec == gameDurationSec)&&(identical(other.photoIntervalSec, photoIntervalSec) || other.photoIntervalSec == photoIntervalSec)&&(identical(other.fugitiveInfoDelaySec, fugitiveInfoDelaySec) || other.fugitiveInfoDelaySec == fugitiveInfoDelaySec)&&(identical(other.senseDistanceRadiusM, senseDistanceRadiusM) || other.senseDistanceRadiusM == senseDistanceRadiusM)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_gameArea),releaseWaitSec,gameDurationSec,photoIntervalSec,fugitiveInfoDelaySec,senseDistanceRadiusM,updatedAt);

@override
String toString() {
  return 'RoomSetting(gameArea: $gameArea, releaseWaitSec: $releaseWaitSec, gameDurationSec: $gameDurationSec, photoIntervalSec: $photoIntervalSec, fugitiveInfoDelaySec: $fugitiveInfoDelaySec, senseDistanceRadiusM: $senseDistanceRadiusM, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$RoomSettingCopyWith<$Res> implements $RoomSettingCopyWith<$Res> {
  factory _$RoomSettingCopyWith(_RoomSetting value, $Res Function(_RoomSetting) _then) = __$RoomSettingCopyWithImpl;
@override @useResult
$Res call({
 List<LatLng> gameArea, int releaseWaitSec, int gameDurationSec, int photoIntervalSec, int fugitiveInfoDelaySec, int senseDistanceRadiusM, int? updatedAt
});




}
/// @nodoc
class __$RoomSettingCopyWithImpl<$Res>
    implements _$RoomSettingCopyWith<$Res> {
  __$RoomSettingCopyWithImpl(this._self, this._then);

  final _RoomSetting _self;
  final $Res Function(_RoomSetting) _then;

/// Create a copy of RoomSetting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? gameArea = null,Object? releaseWaitSec = null,Object? gameDurationSec = null,Object? photoIntervalSec = null,Object? fugitiveInfoDelaySec = null,Object? senseDistanceRadiusM = null,Object? updatedAt = freezed,}) {
  return _then(_RoomSetting(
gameArea: null == gameArea ? _self._gameArea : gameArea // ignore: cast_nullable_to_non_nullable
as List<LatLng>,releaseWaitSec: null == releaseWaitSec ? _self.releaseWaitSec : releaseWaitSec // ignore: cast_nullable_to_non_nullable
as int,gameDurationSec: null == gameDurationSec ? _self.gameDurationSec : gameDurationSec // ignore: cast_nullable_to_non_nullable
as int,photoIntervalSec: null == photoIntervalSec ? _self.photoIntervalSec : photoIntervalSec // ignore: cast_nullable_to_non_nullable
as int,fugitiveInfoDelaySec: null == fugitiveInfoDelaySec ? _self.fugitiveInfoDelaySec : fugitiveInfoDelaySec // ignore: cast_nullable_to_non_nullable
as int,senseDistanceRadiusM: null == senseDistanceRadiusM ? _self.senseDistanceRadiusM : senseDistanceRadiusM // ignore: cast_nullable_to_non_nullable
as int,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
