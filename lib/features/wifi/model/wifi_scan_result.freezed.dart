// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wifi_scan_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WifiScanResult {

 Map<String, int> get bssidRssi; int get scannedAt;
/// Create a copy of WifiScanResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WifiScanResultCopyWith<WifiScanResult> get copyWith => _$WifiScanResultCopyWithImpl<WifiScanResult>(this as WifiScanResult, _$identity);

  /// Serializes this WifiScanResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WifiScanResult&&const DeepCollectionEquality().equals(other.bssidRssi, bssidRssi)&&(identical(other.scannedAt, scannedAt) || other.scannedAt == scannedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(bssidRssi),scannedAt);

@override
String toString() {
  return 'WifiScanResult(bssidRssi: $bssidRssi, scannedAt: $scannedAt)';
}


}

/// @nodoc
abstract mixin class $WifiScanResultCopyWith<$Res>  {
  factory $WifiScanResultCopyWith(WifiScanResult value, $Res Function(WifiScanResult) _then) = _$WifiScanResultCopyWithImpl;
@useResult
$Res call({
 Map<String, int> bssidRssi, int scannedAt
});




}
/// @nodoc
class _$WifiScanResultCopyWithImpl<$Res>
    implements $WifiScanResultCopyWith<$Res> {
  _$WifiScanResultCopyWithImpl(this._self, this._then);

  final WifiScanResult _self;
  final $Res Function(WifiScanResult) _then;

/// Create a copy of WifiScanResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bssidRssi = null,Object? scannedAt = null,}) {
  return _then(_self.copyWith(
bssidRssi: null == bssidRssi ? _self.bssidRssi : bssidRssi // ignore: cast_nullable_to_non_nullable
as Map<String, int>,scannedAt: null == scannedAt ? _self.scannedAt : scannedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WifiScanResult].
extension WifiScanResultPatterns on WifiScanResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WifiScanResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WifiScanResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WifiScanResult value)  $default,){
final _that = this;
switch (_that) {
case _WifiScanResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WifiScanResult value)?  $default,){
final _that = this;
switch (_that) {
case _WifiScanResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, int> bssidRssi,  int scannedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WifiScanResult() when $default != null:
return $default(_that.bssidRssi,_that.scannedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, int> bssidRssi,  int scannedAt)  $default,) {final _that = this;
switch (_that) {
case _WifiScanResult():
return $default(_that.bssidRssi,_that.scannedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, int> bssidRssi,  int scannedAt)?  $default,) {final _that = this;
switch (_that) {
case _WifiScanResult() when $default != null:
return $default(_that.bssidRssi,_that.scannedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WifiScanResult extends WifiScanResult {
  const _WifiScanResult({final  Map<String, int> bssidRssi = const {}, this.scannedAt = 0}): _bssidRssi = bssidRssi,super._();
  factory _WifiScanResult.fromJson(Map<String, dynamic> json) => _$WifiScanResultFromJson(json);

 final  Map<String, int> _bssidRssi;
@override@JsonKey() Map<String, int> get bssidRssi {
  if (_bssidRssi is EqualUnmodifiableMapView) return _bssidRssi;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_bssidRssi);
}

@override@JsonKey() final  int scannedAt;

/// Create a copy of WifiScanResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WifiScanResultCopyWith<_WifiScanResult> get copyWith => __$WifiScanResultCopyWithImpl<_WifiScanResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WifiScanResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WifiScanResult&&const DeepCollectionEquality().equals(other._bssidRssi, _bssidRssi)&&(identical(other.scannedAt, scannedAt) || other.scannedAt == scannedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_bssidRssi),scannedAt);

@override
String toString() {
  return 'WifiScanResult(bssidRssi: $bssidRssi, scannedAt: $scannedAt)';
}


}

/// @nodoc
abstract mixin class _$WifiScanResultCopyWith<$Res> implements $WifiScanResultCopyWith<$Res> {
  factory _$WifiScanResultCopyWith(_WifiScanResult value, $Res Function(_WifiScanResult) _then) = __$WifiScanResultCopyWithImpl;
@override @useResult
$Res call({
 Map<String, int> bssidRssi, int scannedAt
});




}
/// @nodoc
class __$WifiScanResultCopyWithImpl<$Res>
    implements _$WifiScanResultCopyWith<$Res> {
  __$WifiScanResultCopyWithImpl(this._self, this._then);

  final _WifiScanResult _self;
  final $Res Function(_WifiScanResult) _then;

/// Create a copy of WifiScanResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bssidRssi = null,Object? scannedAt = null,}) {
  return _then(_WifiScanResult(
bssidRssi: null == bssidRssi ? _self._bssidRssi : bssidRssi // ignore: cast_nullable_to_non_nullable
as Map<String, int>,scannedAt: null == scannedAt ? _self.scannedAt : scannedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
