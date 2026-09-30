// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_catch.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RoomCatch {

 String get id; String? get demonUserId; String get fugitiveUserId; int get caughtAt;/// 捕まえた瞬間の写真のID(`catchPhotos/{photoId}`)。撮らなかった・
/// まだ送っていないときは省略される。
 String? get catchPhotoId;
/// Create a copy of RoomCatch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomCatchCopyWith<RoomCatch> get copyWith => _$RoomCatchCopyWithImpl<RoomCatch>(this as RoomCatch, _$identity);

  /// Serializes this RoomCatch to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomCatch&&(identical(other.id, id) || other.id == id)&&(identical(other.demonUserId, demonUserId) || other.demonUserId == demonUserId)&&(identical(other.fugitiveUserId, fugitiveUserId) || other.fugitiveUserId == fugitiveUserId)&&(identical(other.caughtAt, caughtAt) || other.caughtAt == caughtAt)&&(identical(other.catchPhotoId, catchPhotoId) || other.catchPhotoId == catchPhotoId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,demonUserId,fugitiveUserId,caughtAt,catchPhotoId);

@override
String toString() {
  return 'RoomCatch(id: $id, demonUserId: $demonUserId, fugitiveUserId: $fugitiveUserId, caughtAt: $caughtAt, catchPhotoId: $catchPhotoId)';
}


}

/// @nodoc
abstract mixin class $RoomCatchCopyWith<$Res>  {
  factory $RoomCatchCopyWith(RoomCatch value, $Res Function(RoomCatch) _then) = _$RoomCatchCopyWithImpl;
@useResult
$Res call({
 String id, String? demonUserId, String fugitiveUserId, int caughtAt, String? catchPhotoId
});




}
/// @nodoc
class _$RoomCatchCopyWithImpl<$Res>
    implements $RoomCatchCopyWith<$Res> {
  _$RoomCatchCopyWithImpl(this._self, this._then);

  final RoomCatch _self;
  final $Res Function(RoomCatch) _then;

/// Create a copy of RoomCatch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? demonUserId = freezed,Object? fugitiveUserId = null,Object? caughtAt = null,Object? catchPhotoId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,demonUserId: freezed == demonUserId ? _self.demonUserId : demonUserId // ignore: cast_nullable_to_non_nullable
as String?,fugitiveUserId: null == fugitiveUserId ? _self.fugitiveUserId : fugitiveUserId // ignore: cast_nullable_to_non_nullable
as String,caughtAt: null == caughtAt ? _self.caughtAt : caughtAt // ignore: cast_nullable_to_non_nullable
as int,catchPhotoId: freezed == catchPhotoId ? _self.catchPhotoId : catchPhotoId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomCatch].
extension RoomCatchPatterns on RoomCatch {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomCatch value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomCatch() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomCatch value)  $default,){
final _that = this;
switch (_that) {
case _RoomCatch():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomCatch value)?  $default,){
final _that = this;
switch (_that) {
case _RoomCatch() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? demonUserId,  String fugitiveUserId,  int caughtAt,  String? catchPhotoId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomCatch() when $default != null:
return $default(_that.id,_that.demonUserId,_that.fugitiveUserId,_that.caughtAt,_that.catchPhotoId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? demonUserId,  String fugitiveUserId,  int caughtAt,  String? catchPhotoId)  $default,) {final _that = this;
switch (_that) {
case _RoomCatch():
return $default(_that.id,_that.demonUserId,_that.fugitiveUserId,_that.caughtAt,_that.catchPhotoId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? demonUserId,  String fugitiveUserId,  int caughtAt,  String? catchPhotoId)?  $default,) {final _that = this;
switch (_that) {
case _RoomCatch() when $default != null:
return $default(_that.id,_that.demonUserId,_that.fugitiveUserId,_that.caughtAt,_that.catchPhotoId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomCatch implements RoomCatch {
  const _RoomCatch({required this.id, this.demonUserId, required this.fugitiveUserId, required this.caughtAt, this.catchPhotoId});
  factory _RoomCatch.fromJson(Map<String, dynamic> json) => _$RoomCatchFromJson(json);

@override final  String id;
@override final  String? demonUserId;
@override final  String fugitiveUserId;
@override final  int caughtAt;
/// 捕まえた瞬間の写真のID(`catchPhotos/{photoId}`)。撮らなかった・
/// まだ送っていないときは省略される。
@override final  String? catchPhotoId;

/// Create a copy of RoomCatch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomCatchCopyWith<_RoomCatch> get copyWith => __$RoomCatchCopyWithImpl<_RoomCatch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomCatchToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomCatch&&(identical(other.id, id) || other.id == id)&&(identical(other.demonUserId, demonUserId) || other.demonUserId == demonUserId)&&(identical(other.fugitiveUserId, fugitiveUserId) || other.fugitiveUserId == fugitiveUserId)&&(identical(other.caughtAt, caughtAt) || other.caughtAt == caughtAt)&&(identical(other.catchPhotoId, catchPhotoId) || other.catchPhotoId == catchPhotoId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,demonUserId,fugitiveUserId,caughtAt,catchPhotoId);

@override
String toString() {
  return 'RoomCatch(id: $id, demonUserId: $demonUserId, fugitiveUserId: $fugitiveUserId, caughtAt: $caughtAt, catchPhotoId: $catchPhotoId)';
}


}

/// @nodoc
abstract mixin class _$RoomCatchCopyWith<$Res> implements $RoomCatchCopyWith<$Res> {
  factory _$RoomCatchCopyWith(_RoomCatch value, $Res Function(_RoomCatch) _then) = __$RoomCatchCopyWithImpl;
@override @useResult
$Res call({
 String id, String? demonUserId, String fugitiveUserId, int caughtAt, String? catchPhotoId
});




}
/// @nodoc
class __$RoomCatchCopyWithImpl<$Res>
    implements _$RoomCatchCopyWith<$Res> {
  __$RoomCatchCopyWithImpl(this._self, this._then);

  final _RoomCatch _self;
  final $Res Function(_RoomCatch) _then;

/// Create a copy of RoomCatch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? demonUserId = freezed,Object? fugitiveUserId = null,Object? caughtAt = null,Object? catchPhotoId = freezed,}) {
  return _then(_RoomCatch(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,demonUserId: freezed == demonUserId ? _self.demonUserId : demonUserId // ignore: cast_nullable_to_non_nullable
as String?,fugitiveUserId: null == fugitiveUserId ? _self.fugitiveUserId : fugitiveUserId // ignore: cast_nullable_to_non_nullable
as String,caughtAt: null == caughtAt ? _self.caughtAt : caughtAt // ignore: cast_nullable_to_non_nullable
as int,catchPhotoId: freezed == catchPhotoId ? _self.catchPhotoId : catchPhotoId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
