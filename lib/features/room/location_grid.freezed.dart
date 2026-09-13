// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'location_grid.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GridCell {

 double get south; double get north; double get west; double get east;
/// Create a copy of GridCell
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GridCellCopyWith<GridCell> get copyWith => _$GridCellCopyWithImpl<GridCell>(this as GridCell, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GridCell&&(identical(other.south, south) || other.south == south)&&(identical(other.north, north) || other.north == north)&&(identical(other.west, west) || other.west == west)&&(identical(other.east, east) || other.east == east));
}


@override
int get hashCode => Object.hash(runtimeType,south,north,west,east);

@override
String toString() {
  return 'GridCell(south: $south, north: $north, west: $west, east: $east)';
}


}

/// @nodoc
abstract mixin class $GridCellCopyWith<$Res>  {
  factory $GridCellCopyWith(GridCell value, $Res Function(GridCell) _then) = _$GridCellCopyWithImpl;
@useResult
$Res call({
 double south, double north, double west, double east
});




}
/// @nodoc
class _$GridCellCopyWithImpl<$Res>
    implements $GridCellCopyWith<$Res> {
  _$GridCellCopyWithImpl(this._self, this._then);

  final GridCell _self;
  final $Res Function(GridCell) _then;

/// Create a copy of GridCell
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? south = null,Object? north = null,Object? west = null,Object? east = null,}) {
  return _then(_self.copyWith(
south: null == south ? _self.south : south // ignore: cast_nullable_to_non_nullable
as double,north: null == north ? _self.north : north // ignore: cast_nullable_to_non_nullable
as double,west: null == west ? _self.west : west // ignore: cast_nullable_to_non_nullable
as double,east: null == east ? _self.east : east // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [GridCell].
extension GridCellPatterns on GridCell {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GridCell value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GridCell() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GridCell value)  $default,){
final _that = this;
switch (_that) {
case _GridCell():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GridCell value)?  $default,){
final _that = this;
switch (_that) {
case _GridCell() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double south,  double north,  double west,  double east)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GridCell() when $default != null:
return $default(_that.south,_that.north,_that.west,_that.east);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double south,  double north,  double west,  double east)  $default,) {final _that = this;
switch (_that) {
case _GridCell():
return $default(_that.south,_that.north,_that.west,_that.east);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double south,  double north,  double west,  double east)?  $default,) {final _that = this;
switch (_that) {
case _GridCell() when $default != null:
return $default(_that.south,_that.north,_that.west,_that.east);case _:
  return null;

}
}

}

/// @nodoc


class _GridCell extends GridCell {
  const _GridCell({required this.south, required this.north, required this.west, required this.east}): super._();
  

@override final  double south;
@override final  double north;
@override final  double west;
@override final  double east;

/// Create a copy of GridCell
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GridCellCopyWith<_GridCell> get copyWith => __$GridCellCopyWithImpl<_GridCell>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GridCell&&(identical(other.south, south) || other.south == south)&&(identical(other.north, north) || other.north == north)&&(identical(other.west, west) || other.west == west)&&(identical(other.east, east) || other.east == east));
}


@override
int get hashCode => Object.hash(runtimeType,south,north,west,east);

@override
String toString() {
  return 'GridCell(south: $south, north: $north, west: $west, east: $east)';
}


}

/// @nodoc
abstract mixin class _$GridCellCopyWith<$Res> implements $GridCellCopyWith<$Res> {
  factory _$GridCellCopyWith(_GridCell value, $Res Function(_GridCell) _then) = __$GridCellCopyWithImpl;
@override @useResult
$Res call({
 double south, double north, double west, double east
});




}
/// @nodoc
class __$GridCellCopyWithImpl<$Res>
    implements _$GridCellCopyWith<$Res> {
  __$GridCellCopyWithImpl(this._self, this._then);

  final _GridCell _self;
  final $Res Function(_GridCell) _then;

/// Create a copy of GridCell
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? south = null,Object? north = null,Object? west = null,Object? east = null,}) {
  return _then(_GridCell(
south: null == south ? _self.south : south // ignore: cast_nullable_to_non_nullable
as double,north: null == north ? _self.north : north // ignore: cast_nullable_to_non_nullable
as double,west: null == west ? _self.west : west // ignore: cast_nullable_to_non_nullable
as double,east: null == east ? _self.east : east // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
