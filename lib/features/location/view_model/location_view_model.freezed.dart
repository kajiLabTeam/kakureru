// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'location_view_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LocationState {

 List<UserLocation> get locations; bool get permissionDenied; bool get isSending;
/// Create a copy of LocationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocationStateCopyWith<LocationState> get copyWith => _$LocationStateCopyWithImpl<LocationState>(this as LocationState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocationState&&const DeepCollectionEquality().equals(other.locations, locations)&&(identical(other.permissionDenied, permissionDenied) || other.permissionDenied == permissionDenied)&&(identical(other.isSending, isSending) || other.isSending == isSending));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(locations),permissionDenied,isSending);

@override
String toString() {
  return 'LocationState(locations: $locations, permissionDenied: $permissionDenied, isSending: $isSending)';
}


}

/// @nodoc
abstract mixin class $LocationStateCopyWith<$Res>  {
  factory $LocationStateCopyWith(LocationState value, $Res Function(LocationState) _then) = _$LocationStateCopyWithImpl;
@useResult
$Res call({
 List<UserLocation> locations, bool permissionDenied, bool isSending
});




}
/// @nodoc
class _$LocationStateCopyWithImpl<$Res>
    implements $LocationStateCopyWith<$Res> {
  _$LocationStateCopyWithImpl(this._self, this._then);

  final LocationState _self;
  final $Res Function(LocationState) _then;

/// Create a copy of LocationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? locations = null,Object? permissionDenied = null,Object? isSending = null,}) {
  return _then(_self.copyWith(
locations: null == locations ? _self.locations : locations // ignore: cast_nullable_to_non_nullable
as List<UserLocation>,permissionDenied: null == permissionDenied ? _self.permissionDenied : permissionDenied // ignore: cast_nullable_to_non_nullable
as bool,isSending: null == isSending ? _self.isSending : isSending // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [LocationState].
extension LocationStatePatterns on LocationState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LocationState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LocationState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LocationState value)  $default,){
final _that = this;
switch (_that) {
case _LocationState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LocationState value)?  $default,){
final _that = this;
switch (_that) {
case _LocationState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<UserLocation> locations,  bool permissionDenied,  bool isSending)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LocationState() when $default != null:
return $default(_that.locations,_that.permissionDenied,_that.isSending);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<UserLocation> locations,  bool permissionDenied,  bool isSending)  $default,) {final _that = this;
switch (_that) {
case _LocationState():
return $default(_that.locations,_that.permissionDenied,_that.isSending);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<UserLocation> locations,  bool permissionDenied,  bool isSending)?  $default,) {final _that = this;
switch (_that) {
case _LocationState() when $default != null:
return $default(_that.locations,_that.permissionDenied,_that.isSending);case _:
  return null;

}
}

}

/// @nodoc


class _LocationState implements LocationState {
  const _LocationState({final  List<UserLocation> locations = const [], this.permissionDenied = false, this.isSending = false}): _locations = locations;
  

 final  List<UserLocation> _locations;
@override@JsonKey() List<UserLocation> get locations {
  if (_locations is EqualUnmodifiableListView) return _locations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_locations);
}

@override@JsonKey() final  bool permissionDenied;
@override@JsonKey() final  bool isSending;

/// Create a copy of LocationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LocationStateCopyWith<_LocationState> get copyWith => __$LocationStateCopyWithImpl<_LocationState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LocationState&&const DeepCollectionEquality().equals(other._locations, _locations)&&(identical(other.permissionDenied, permissionDenied) || other.permissionDenied == permissionDenied)&&(identical(other.isSending, isSending) || other.isSending == isSending));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_locations),permissionDenied,isSending);

@override
String toString() {
  return 'LocationState(locations: $locations, permissionDenied: $permissionDenied, isSending: $isSending)';
}


}

/// @nodoc
abstract mixin class _$LocationStateCopyWith<$Res> implements $LocationStateCopyWith<$Res> {
  factory _$LocationStateCopyWith(_LocationState value, $Res Function(_LocationState) _then) = __$LocationStateCopyWithImpl;
@override @useResult
$Res call({
 List<UserLocation> locations, bool permissionDenied, bool isSending
});




}
/// @nodoc
class __$LocationStateCopyWithImpl<$Res>
    implements _$LocationStateCopyWith<$Res> {
  __$LocationStateCopyWithImpl(this._self, this._then);

  final _LocationState _self;
  final $Res Function(_LocationState) _then;

/// Create a copy of LocationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? locations = null,Object? permissionDenied = null,Object? isSending = null,}) {
  return _then(_LocationState(
locations: null == locations ? _self._locations : locations // ignore: cast_nullable_to_non_nullable
as List<UserLocation>,permissionDenied: null == permissionDenied ? _self.permissionDenied : permissionDenied // ignore: cast_nullable_to_non_nullable
as bool,isSending: null == isSending ? _self.isSending : isSending // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
