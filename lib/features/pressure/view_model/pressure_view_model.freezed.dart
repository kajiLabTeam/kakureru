// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pressure_view_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PressureState {

 PressureSensorAvailability get sensorAvailability; double? get myPressureHPa; bool get isCalibrating;
/// Create a copy of PressureState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PressureStateCopyWith<PressureState> get copyWith => _$PressureStateCopyWithImpl<PressureState>(this as PressureState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PressureState&&(identical(other.sensorAvailability, sensorAvailability) || other.sensorAvailability == sensorAvailability)&&(identical(other.myPressureHPa, myPressureHPa) || other.myPressureHPa == myPressureHPa)&&(identical(other.isCalibrating, isCalibrating) || other.isCalibrating == isCalibrating));
}


@override
int get hashCode => Object.hash(runtimeType,sensorAvailability,myPressureHPa,isCalibrating);

@override
String toString() {
  return 'PressureState(sensorAvailability: $sensorAvailability, myPressureHPa: $myPressureHPa, isCalibrating: $isCalibrating)';
}


}

/// @nodoc
abstract mixin class $PressureStateCopyWith<$Res>  {
  factory $PressureStateCopyWith(PressureState value, $Res Function(PressureState) _then) = _$PressureStateCopyWithImpl;
@useResult
$Res call({
 PressureSensorAvailability sensorAvailability, double? myPressureHPa, bool isCalibrating
});




}
/// @nodoc
class _$PressureStateCopyWithImpl<$Res>
    implements $PressureStateCopyWith<$Res> {
  _$PressureStateCopyWithImpl(this._self, this._then);

  final PressureState _self;
  final $Res Function(PressureState) _then;

/// Create a copy of PressureState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sensorAvailability = null,Object? myPressureHPa = freezed,Object? isCalibrating = null,}) {
  return _then(_self.copyWith(
sensorAvailability: null == sensorAvailability ? _self.sensorAvailability : sensorAvailability // ignore: cast_nullable_to_non_nullable
as PressureSensorAvailability,myPressureHPa: freezed == myPressureHPa ? _self.myPressureHPa : myPressureHPa // ignore: cast_nullable_to_non_nullable
as double?,isCalibrating: null == isCalibrating ? _self.isCalibrating : isCalibrating // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PressureState].
extension PressureStatePatterns on PressureState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PressureState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PressureState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PressureState value)  $default,){
final _that = this;
switch (_that) {
case _PressureState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PressureState value)?  $default,){
final _that = this;
switch (_that) {
case _PressureState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PressureSensorAvailability sensorAvailability,  double? myPressureHPa,  bool isCalibrating)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PressureState() when $default != null:
return $default(_that.sensorAvailability,_that.myPressureHPa,_that.isCalibrating);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PressureSensorAvailability sensorAvailability,  double? myPressureHPa,  bool isCalibrating)  $default,) {final _that = this;
switch (_that) {
case _PressureState():
return $default(_that.sensorAvailability,_that.myPressureHPa,_that.isCalibrating);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PressureSensorAvailability sensorAvailability,  double? myPressureHPa,  bool isCalibrating)?  $default,) {final _that = this;
switch (_that) {
case _PressureState() when $default != null:
return $default(_that.sensorAvailability,_that.myPressureHPa,_that.isCalibrating);case _:
  return null;

}
}

}

/// @nodoc


class _PressureState implements PressureState {
  const _PressureState({this.sensorAvailability = PressureSensorAvailability.checking, this.myPressureHPa, this.isCalibrating = false});
  

@override@JsonKey() final  PressureSensorAvailability sensorAvailability;
@override final  double? myPressureHPa;
@override@JsonKey() final  bool isCalibrating;

/// Create a copy of PressureState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PressureStateCopyWith<_PressureState> get copyWith => __$PressureStateCopyWithImpl<_PressureState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PressureState&&(identical(other.sensorAvailability, sensorAvailability) || other.sensorAvailability == sensorAvailability)&&(identical(other.myPressureHPa, myPressureHPa) || other.myPressureHPa == myPressureHPa)&&(identical(other.isCalibrating, isCalibrating) || other.isCalibrating == isCalibrating));
}


@override
int get hashCode => Object.hash(runtimeType,sensorAvailability,myPressureHPa,isCalibrating);

@override
String toString() {
  return 'PressureState(sensorAvailability: $sensorAvailability, myPressureHPa: $myPressureHPa, isCalibrating: $isCalibrating)';
}


}

/// @nodoc
abstract mixin class _$PressureStateCopyWith<$Res> implements $PressureStateCopyWith<$Res> {
  factory _$PressureStateCopyWith(_PressureState value, $Res Function(_PressureState) _then) = __$PressureStateCopyWithImpl;
@override @useResult
$Res call({
 PressureSensorAvailability sensorAvailability, double? myPressureHPa, bool isCalibrating
});




}
/// @nodoc
class __$PressureStateCopyWithImpl<$Res>
    implements _$PressureStateCopyWith<$Res> {
  __$PressureStateCopyWithImpl(this._self, this._then);

  final _PressureState _self;
  final $Res Function(_PressureState) _then;

/// Create a copy of PressureState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sensorAvailability = null,Object? myPressureHPa = freezed,Object? isCalibrating = null,}) {
  return _then(_PressureState(
sensorAvailability: null == sensorAvailability ? _self.sensorAvailability : sensorAvailability // ignore: cast_nullable_to_non_nullable
as PressureSensorAvailability,myPressureHPa: freezed == myPressureHPa ? _self.myPressureHPa : myPressureHPa // ignore: cast_nullable_to_non_nullable
as double?,isCalibrating: null == isCalibrating ? _self.isCalibrating : isCalibrating // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
