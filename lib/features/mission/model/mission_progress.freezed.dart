// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mission_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MissionProgress {

/// どのミッションの進み具合か。ミッションが無ければnull。
 String? get missionId;/// どの地点への到着判定か(いちばん近い、空いている地点)。
 String? get spotId;/// アクセスポイントの到着判定。
 ArrivalProgress get arrival;
/// Create a copy of MissionProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MissionProgressCopyWith<MissionProgress> get copyWith => _$MissionProgressCopyWithImpl<MissionProgress>(this as MissionProgress, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MissionProgress&&(identical(other.missionId, missionId) || other.missionId == missionId)&&(identical(other.spotId, spotId) || other.spotId == spotId)&&(identical(other.arrival, arrival) || other.arrival == arrival));
}


@override
int get hashCode => Object.hash(runtimeType,missionId,spotId,arrival);

@override
String toString() {
  return 'MissionProgress(missionId: $missionId, spotId: $spotId, arrival: $arrival)';
}


}

/// @nodoc
abstract mixin class $MissionProgressCopyWith<$Res>  {
  factory $MissionProgressCopyWith(MissionProgress value, $Res Function(MissionProgress) _then) = _$MissionProgressCopyWithImpl;
@useResult
$Res call({
 String? missionId, String? spotId, ArrivalProgress arrival
});




}
/// @nodoc
class _$MissionProgressCopyWithImpl<$Res>
    implements $MissionProgressCopyWith<$Res> {
  _$MissionProgressCopyWithImpl(this._self, this._then);

  final MissionProgress _self;
  final $Res Function(MissionProgress) _then;

/// Create a copy of MissionProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? missionId = freezed,Object? spotId = freezed,Object? arrival = null,}) {
  return _then(_self.copyWith(
missionId: freezed == missionId ? _self.missionId : missionId // ignore: cast_nullable_to_non_nullable
as String?,spotId: freezed == spotId ? _self.spotId : spotId // ignore: cast_nullable_to_non_nullable
as String?,arrival: null == arrival ? _self.arrival : arrival // ignore: cast_nullable_to_non_nullable
as ArrivalProgress,
  ));
}

}


/// Adds pattern-matching-related methods to [MissionProgress].
extension MissionProgressPatterns on MissionProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MissionProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MissionProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MissionProgress value)  $default,){
final _that = this;
switch (_that) {
case _MissionProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MissionProgress value)?  $default,){
final _that = this;
switch (_that) {
case _MissionProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? missionId,  String? spotId,  ArrivalProgress arrival)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MissionProgress() when $default != null:
return $default(_that.missionId,_that.spotId,_that.arrival);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? missionId,  String? spotId,  ArrivalProgress arrival)  $default,) {final _that = this;
switch (_that) {
case _MissionProgress():
return $default(_that.missionId,_that.spotId,_that.arrival);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? missionId,  String? spotId,  ArrivalProgress arrival)?  $default,) {final _that = this;
switch (_that) {
case _MissionProgress() when $default != null:
return $default(_that.missionId,_that.spotId,_that.arrival);case _:
  return null;

}
}

}

/// @nodoc


class _MissionProgress implements MissionProgress {
  const _MissionProgress({this.missionId, this.spotId, this.arrival = initialArrival});
  

/// どのミッションの進み具合か。ミッションが無ければnull。
@override final  String? missionId;
/// どの地点への到着判定か(いちばん近い、空いている地点)。
@override final  String? spotId;
/// アクセスポイントの到着判定。
@override@JsonKey() final  ArrivalProgress arrival;

/// Create a copy of MissionProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MissionProgressCopyWith<_MissionProgress> get copyWith => __$MissionProgressCopyWithImpl<_MissionProgress>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MissionProgress&&(identical(other.missionId, missionId) || other.missionId == missionId)&&(identical(other.spotId, spotId) || other.spotId == spotId)&&(identical(other.arrival, arrival) || other.arrival == arrival));
}


@override
int get hashCode => Object.hash(runtimeType,missionId,spotId,arrival);

@override
String toString() {
  return 'MissionProgress(missionId: $missionId, spotId: $spotId, arrival: $arrival)';
}


}

/// @nodoc
abstract mixin class _$MissionProgressCopyWith<$Res> implements $MissionProgressCopyWith<$Res> {
  factory _$MissionProgressCopyWith(_MissionProgress value, $Res Function(_MissionProgress) _then) = __$MissionProgressCopyWithImpl;
@override @useResult
$Res call({
 String? missionId, String? spotId, ArrivalProgress arrival
});




}
/// @nodoc
class __$MissionProgressCopyWithImpl<$Res>
    implements _$MissionProgressCopyWith<$Res> {
  __$MissionProgressCopyWithImpl(this._self, this._then);

  final _MissionProgress _self;
  final $Res Function(_MissionProgress) _then;

/// Create a copy of MissionProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? missionId = freezed,Object? spotId = freezed,Object? arrival = null,}) {
  return _then(_MissionProgress(
missionId: freezed == missionId ? _self.missionId : missionId // ignore: cast_nullable_to_non_nullable
as String?,spotId: freezed == spotId ? _self.spotId : spotId // ignore: cast_nullable_to_non_nullable
as String?,arrival: null == arrival ? _self.arrival : arrival // ignore: cast_nullable_to_non_nullable
as ArrivalProgress,
  ));
}


}

// dart format on
