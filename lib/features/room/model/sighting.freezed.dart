// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sighting.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Sighting {

 String get id;/// 撮った人のuid。
 String get uid;/// 撮った時刻(ServerValue.timestamp)。
 int get takenAt;/// 撮った場所の説明(「1号館の前」など)。作る仕組みはまだ無く、
/// 書かれていれば表示するだけ。
 String? get place;
/// Create a copy of Sighting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SightingCopyWith<Sighting> get copyWith => _$SightingCopyWithImpl<Sighting>(this as Sighting, _$identity);

  /// Serializes this Sighting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Sighting&&(identical(other.id, id) || other.id == id)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.takenAt, takenAt) || other.takenAt == takenAt)&&(identical(other.place, place) || other.place == place));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,uid,takenAt,place);

@override
String toString() {
  return 'Sighting(id: $id, uid: $uid, takenAt: $takenAt, place: $place)';
}


}

/// @nodoc
abstract mixin class $SightingCopyWith<$Res>  {
  factory $SightingCopyWith(Sighting value, $Res Function(Sighting) _then) = _$SightingCopyWithImpl;
@useResult
$Res call({
 String id, String uid, int takenAt, String? place
});




}
/// @nodoc
class _$SightingCopyWithImpl<$Res>
    implements $SightingCopyWith<$Res> {
  _$SightingCopyWithImpl(this._self, this._then);

  final Sighting _self;
  final $Res Function(Sighting) _then;

/// Create a copy of Sighting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? uid = null,Object? takenAt = null,Object? place = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,takenAt: null == takenAt ? _self.takenAt : takenAt // ignore: cast_nullable_to_non_nullable
as int,place: freezed == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Sighting].
extension SightingPatterns on Sighting {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Sighting value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Sighting() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Sighting value)  $default,){
final _that = this;
switch (_that) {
case _Sighting():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Sighting value)?  $default,){
final _that = this;
switch (_that) {
case _Sighting() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String uid,  int takenAt,  String? place)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Sighting() when $default != null:
return $default(_that.id,_that.uid,_that.takenAt,_that.place);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String uid,  int takenAt,  String? place)  $default,) {final _that = this;
switch (_that) {
case _Sighting():
return $default(_that.id,_that.uid,_that.takenAt,_that.place);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String uid,  int takenAt,  String? place)?  $default,) {final _that = this;
switch (_that) {
case _Sighting() when $default != null:
return $default(_that.id,_that.uid,_that.takenAt,_that.place);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Sighting implements Sighting {
  const _Sighting({required this.id, required this.uid, required this.takenAt, this.place});
  factory _Sighting.fromJson(Map<String, dynamic> json) => _$SightingFromJson(json);

@override final  String id;
/// 撮った人のuid。
@override final  String uid;
/// 撮った時刻(ServerValue.timestamp)。
@override final  int takenAt;
/// 撮った場所の説明(「1号館の前」など)。作る仕組みはまだ無く、
/// 書かれていれば表示するだけ。
@override final  String? place;

/// Create a copy of Sighting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SightingCopyWith<_Sighting> get copyWith => __$SightingCopyWithImpl<_Sighting>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SightingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Sighting&&(identical(other.id, id) || other.id == id)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.takenAt, takenAt) || other.takenAt == takenAt)&&(identical(other.place, place) || other.place == place));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,uid,takenAt,place);

@override
String toString() {
  return 'Sighting(id: $id, uid: $uid, takenAt: $takenAt, place: $place)';
}


}

/// @nodoc
abstract mixin class _$SightingCopyWith<$Res> implements $SightingCopyWith<$Res> {
  factory _$SightingCopyWith(_Sighting value, $Res Function(_Sighting) _then) = __$SightingCopyWithImpl;
@override @useResult
$Res call({
 String id, String uid, int takenAt, String? place
});




}
/// @nodoc
class __$SightingCopyWithImpl<$Res>
    implements _$SightingCopyWith<$Res> {
  __$SightingCopyWithImpl(this._self, this._then);

  final _Sighting _self;
  final $Res Function(_Sighting) _then;

/// Create a copy of Sighting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? uid = null,Object? takenAt = null,Object? place = freezed,}) {
  return _then(_Sighting(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,takenAt: null == takenAt ? _self.takenAt : takenAt // ignore: cast_nullable_to_non_nullable
as int,place: freezed == place ? _self.place : place // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
