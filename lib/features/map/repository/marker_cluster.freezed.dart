// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'marker_cluster.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MarkerCluster {

 List<ClusterInput> get members; double get x; double get y;
/// Create a copy of MarkerCluster
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MarkerClusterCopyWith<MarkerCluster> get copyWith => _$MarkerClusterCopyWithImpl<MarkerCluster>(this as MarkerCluster, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MarkerCluster;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MarkerCluster&&const DeepCollectionEquality().equals(other.members, _this.members)&&(identical(other.x, _this.x) || other.x == _this.x)&&(identical(other.y, _this.y) || other.y == _this.y));
}


@override
int get hashCode {
  final _this = this as MarkerCluster;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.members),_this.x,_this.y);
}

@override
String toString() {
  final _this = this as MarkerCluster;
  return 'MarkerCluster(members: ${_this.members}, x: ${_this.x}, y: ${_this.y})';
}


}

/// @nodoc
abstract mixin class $MarkerClusterCopyWith<$Res>  {
  factory $MarkerClusterCopyWith(MarkerCluster value, $Res Function(MarkerCluster) _then) = _$MarkerClusterCopyWithImpl;
@useResult
$Res call({
 List<ClusterInput> members, double x, double y
});




}
/// @nodoc
class _$MarkerClusterCopyWithImpl<$Res>
    implements $MarkerClusterCopyWith<$Res> {
  _$MarkerClusterCopyWithImpl(this._self, this._then);

  final MarkerCluster _self;
  final $Res Function(MarkerCluster) _then;

/// Create a copy of MarkerCluster
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? members = null,Object? x = null,Object? y = null,}) {
  return _then(MarkerCluster(
members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as List<ClusterInput>,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [MarkerCluster].
extension MarkerClusterPatterns on MarkerCluster {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MarkerCluster value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MarkerCluster() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MarkerCluster value)  $default,){
final _that = this;
switch (_that) {
case _MarkerCluster():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MarkerCluster value)?  $default,){
final _that = this;
switch (_that) {
case _MarkerCluster() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ClusterInput> members,  double x,  double y)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MarkerCluster() when $default != null:
return $default(_that.members,_that.x,_that.y);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ClusterInput> members,  double x,  double y)  $default,) {final _that = this;
switch (_that) {
case _MarkerCluster():
return $default(_that.members,_that.x,_that.y);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ClusterInput> members,  double x,  double y)?  $default,) {final _that = this;
switch (_that) {
case _MarkerCluster() when $default != null:
return $default(_that.members,_that.x,_that.y);case _:
  return null;

}
}

}

/// @nodoc


class _MarkerCluster extends MarkerCluster {
  const _MarkerCluster({required  List<ClusterInput> members, required this.x, required this.y}): _members = members,super._();
  

 final  List<ClusterInput> _members;
@override List<ClusterInput> get members {
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_members);
}

@override final  double x;
@override final  double y;

/// Create a copy of MarkerCluster
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MarkerClusterCopyWith<_MarkerCluster> get copyWith => __$MarkerClusterCopyWithImpl<_MarkerCluster>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MarkerCluster&&const DeepCollectionEquality().equals(other.members, _members)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_members),x,y);
}

@override
String toString() {
    return 'MarkerCluster(members: $members, x: $x, y: $y)';
}


}

/// @nodoc
abstract mixin class _$MarkerClusterCopyWith<$Res> implements $MarkerClusterCopyWith<$Res> {
  factory _$MarkerClusterCopyWith(_MarkerCluster value, $Res Function(_MarkerCluster) _then) = __$MarkerClusterCopyWithImpl;
@override @useResult
$Res call({
 List<ClusterInput> members, double x, double y
});




}
/// @nodoc
class __$MarkerClusterCopyWithImpl<$Res>
    implements _$MarkerClusterCopyWith<$Res> {
  __$MarkerClusterCopyWithImpl(this._self, this._then);

  final _MarkerCluster _self;
  final $Res Function(_MarkerCluster) _then;

/// Create a copy of MarkerCluster
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? members = null,Object? x = null,Object? y = null,}) {
  return _then(_MarkerCluster(
members: null == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<ClusterInput>,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
