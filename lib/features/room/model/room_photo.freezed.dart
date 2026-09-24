// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_photo.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RoomPhoto {

 String get id; String get uid; int get takenAt;
/// Create a copy of RoomPhoto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomPhotoCopyWith<RoomPhoto> get copyWith => _$RoomPhotoCopyWithImpl<RoomPhoto>(this as RoomPhoto, _$identity);

  /// Serializes this RoomPhoto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomPhoto&&(identical(other.id, id) || other.id == id)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.takenAt, takenAt) || other.takenAt == takenAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,uid,takenAt);

@override
String toString() {
  return 'RoomPhoto(id: $id, uid: $uid, takenAt: $takenAt)';
}


}

/// @nodoc
abstract mixin class $RoomPhotoCopyWith<$Res>  {
  factory $RoomPhotoCopyWith(RoomPhoto value, $Res Function(RoomPhoto) _then) = _$RoomPhotoCopyWithImpl;
@useResult
$Res call({
 String id, String uid, int takenAt
});




}
/// @nodoc
class _$RoomPhotoCopyWithImpl<$Res>
    implements $RoomPhotoCopyWith<$Res> {
  _$RoomPhotoCopyWithImpl(this._self, this._then);

  final RoomPhoto _self;
  final $Res Function(RoomPhoto) _then;

/// Create a copy of RoomPhoto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? uid = null,Object? takenAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,takenAt: null == takenAt ? _self.takenAt : takenAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomPhoto].
extension RoomPhotoPatterns on RoomPhoto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomPhoto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomPhoto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomPhoto value)  $default,){
final _that = this;
switch (_that) {
case _RoomPhoto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomPhoto value)?  $default,){
final _that = this;
switch (_that) {
case _RoomPhoto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String uid,  int takenAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomPhoto() when $default != null:
return $default(_that.id,_that.uid,_that.takenAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String uid,  int takenAt)  $default,) {final _that = this;
switch (_that) {
case _RoomPhoto():
return $default(_that.id,_that.uid,_that.takenAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String uid,  int takenAt)?  $default,) {final _that = this;
switch (_that) {
case _RoomPhoto() when $default != null:
return $default(_that.id,_that.uid,_that.takenAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomPhoto implements RoomPhoto {
  const _RoomPhoto({required this.id, required this.uid, required this.takenAt});
  factory _RoomPhoto.fromJson(Map<String, dynamic> json) => _$RoomPhotoFromJson(json);

@override final  String id;
@override final  String uid;
@override final  int takenAt;

/// Create a copy of RoomPhoto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomPhotoCopyWith<_RoomPhoto> get copyWith => __$RoomPhotoCopyWithImpl<_RoomPhoto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomPhotoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomPhoto&&(identical(other.id, id) || other.id == id)&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.takenAt, takenAt) || other.takenAt == takenAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,uid,takenAt);

@override
String toString() {
  return 'RoomPhoto(id: $id, uid: $uid, takenAt: $takenAt)';
}


}

/// @nodoc
abstract mixin class _$RoomPhotoCopyWith<$Res> implements $RoomPhotoCopyWith<$Res> {
  factory _$RoomPhotoCopyWith(_RoomPhoto value, $Res Function(_RoomPhoto) _then) = __$RoomPhotoCopyWithImpl;
@override @useResult
$Res call({
 String id, String uid, int takenAt
});




}
/// @nodoc
class __$RoomPhotoCopyWithImpl<$Res>
    implements _$RoomPhotoCopyWith<$Res> {
  __$RoomPhotoCopyWithImpl(this._self, this._then);

  final _RoomPhoto _self;
  final $Res Function(_RoomPhoto) _then;

/// Create a copy of RoomPhoto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? uid = null,Object? takenAt = null,}) {
  return _then(_RoomPhoto(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as String,takenAt: null == takenAt ? _self.takenAt : takenAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
