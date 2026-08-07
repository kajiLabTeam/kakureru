// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'relative_vertical_position.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RelativeVerticalPosition {

 String get uid; double get deltaMeters;
/// Create a copy of RelativeVerticalPosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RelativeVerticalPositionCopyWith<RelativeVerticalPosition> get copyWith => _$RelativeVerticalPositionCopyWithImpl<RelativeVerticalPosition>(this as RelativeVerticalPosition, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RelativeVerticalPosition&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.deltaMeters, deltaMeters) || other.deltaMeters == deltaMeters));
}


@override
int get hashCode => Object.hash(runtimeType,uid,deltaMeters);

@override
String toString() {
  return 'RelativeVerticalPosition(uid: $uid, deltaMeters: $deltaMeters)';
}


}

/// @nodoc
abstract mixin class $RelativeVerticalPositionCopyWith<$Res>  {
  factory $RelativeVerticalPositionCopyWith(RelativeVerticalPosition value, $Res Function(RelativeVerticalPosition) _then) = _$RelativeVerticalPositionCopyWithImpl;
@useResult
$Res call({
 String uid, double deltaMeters
});




}
/// @nodoc
class _$RelativeVerticalPositionCopyWithImpl<$Res>
    implements $RelativeVerticalPositionCopyWith<$Res> {
  _$RelativeVerticalPositionCopyWithImpl(this._self, this._then);

  final RelativeVerticalPosition _self;
  final $Res Function(RelativeVerticalPosition) _then;

/// Create a copy of RelativeVerticalPosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,Object? deltaMeters = null,}) {
  return _then(_self.copyWith(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,deltaMeters: null == deltaMeters ? _self.deltaMeters : deltaMeters // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [RelativeVerticalPosition].
extension RelativeVerticalPositionPatterns on RelativeVerticalPosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RelativeVerticalPosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RelativeVerticalPosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RelativeVerticalPosition value)  $default,){
final _that = this;
switch (_that) {
case _RelativeVerticalPosition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RelativeVerticalPosition value)?  $default,){
final _that = this;
switch (_that) {
case _RelativeVerticalPosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String uid,  double deltaMeters)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RelativeVerticalPosition() when $default != null:
return $default(_that.uid,_that.deltaMeters);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String uid,  double deltaMeters)  $default,) {final _that = this;
switch (_that) {
case _RelativeVerticalPosition():
return $default(_that.uid,_that.deltaMeters);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String uid,  double deltaMeters)?  $default,) {final _that = this;
switch (_that) {
case _RelativeVerticalPosition() when $default != null:
return $default(_that.uid,_that.deltaMeters);case _:
  return null;

}
}

}

/// @nodoc


class _RelativeVerticalPosition implements RelativeVerticalPosition {
  const _RelativeVerticalPosition({required this.uid, required this.deltaMeters});
  

@override final  String uid;
@override final  double deltaMeters;

/// Create a copy of RelativeVerticalPosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RelativeVerticalPositionCopyWith<_RelativeVerticalPosition> get copyWith => __$RelativeVerticalPositionCopyWithImpl<_RelativeVerticalPosition>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RelativeVerticalPosition&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.deltaMeters, deltaMeters) || other.deltaMeters == deltaMeters));
}


@override
int get hashCode => Object.hash(runtimeType,uid,deltaMeters);

@override
String toString() {
  return 'RelativeVerticalPosition(uid: $uid, deltaMeters: $deltaMeters)';
}


}

/// @nodoc
abstract mixin class _$RelativeVerticalPositionCopyWith<$Res> implements $RelativeVerticalPositionCopyWith<$Res> {
  factory _$RelativeVerticalPositionCopyWith(_RelativeVerticalPosition value, $Res Function(_RelativeVerticalPosition) _then) = __$RelativeVerticalPositionCopyWithImpl;
@override @useResult
$Res call({
 String uid, double deltaMeters
});




}
/// @nodoc
class __$RelativeVerticalPositionCopyWithImpl<$Res>
    implements _$RelativeVerticalPositionCopyWith<$Res> {
  __$RelativeVerticalPositionCopyWithImpl(this._self, this._then);

  final _RelativeVerticalPosition _self;
  final $Res Function(_RelativeVerticalPosition) _then;

/// Create a copy of RelativeVerticalPosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? deltaMeters = null,}) {
  return _then(_RelativeVerticalPosition(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,deltaMeters: null == deltaMeters ? _self.deltaMeters : deltaMeters // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
