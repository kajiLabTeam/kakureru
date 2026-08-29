// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RoomUser {

 String get id; String get displayName; String get deviceId; bool get isHost;@JsonKey(unknownEnumValue: UserRole.fugitive) UserRole get role; double? get pressureOffset; bool? get pressureSensorAvailable; int? get becameDemonAt; int? get lastPhotoAt; int get joinedAt;
/// Create a copy of RoomUser
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomUserCopyWith<RoomUser> get copyWith => _$RoomUserCopyWithImpl<RoomUser>(this as RoomUser, _$identity);

  /// Serializes this RoomUser to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomUser&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.isHost, isHost) || other.isHost == isHost)&&(identical(other.role, role) || other.role == role)&&(identical(other.pressureOffset, pressureOffset) || other.pressureOffset == pressureOffset)&&(identical(other.pressureSensorAvailable, pressureSensorAvailable) || other.pressureSensorAvailable == pressureSensorAvailable)&&(identical(other.becameDemonAt, becameDemonAt) || other.becameDemonAt == becameDemonAt)&&(identical(other.lastPhotoAt, lastPhotoAt) || other.lastPhotoAt == lastPhotoAt)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,deviceId,isHost,role,pressureOffset,pressureSensorAvailable,becameDemonAt,lastPhotoAt,joinedAt);

@override
String toString() {
  return 'RoomUser(id: $id, displayName: $displayName, deviceId: $deviceId, isHost: $isHost, role: $role, pressureOffset: $pressureOffset, pressureSensorAvailable: $pressureSensorAvailable, becameDemonAt: $becameDemonAt, lastPhotoAt: $lastPhotoAt, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class $RoomUserCopyWith<$Res>  {
  factory $RoomUserCopyWith(RoomUser value, $Res Function(RoomUser) _then) = _$RoomUserCopyWithImpl;
@useResult
$Res call({
 String id, String displayName, String deviceId, bool isHost,@JsonKey(unknownEnumValue: UserRole.fugitive) UserRole role, double? pressureOffset, bool? pressureSensorAvailable, int? becameDemonAt, int? lastPhotoAt, int joinedAt
});




}
/// @nodoc
class _$RoomUserCopyWithImpl<$Res>
    implements $RoomUserCopyWith<$Res> {
  _$RoomUserCopyWithImpl(this._self, this._then);

  final RoomUser _self;
  final $Res Function(RoomUser) _then;

/// Create a copy of RoomUser
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? displayName = null,Object? deviceId = null,Object? isHost = null,Object? role = null,Object? pressureOffset = freezed,Object? pressureSensorAvailable = freezed,Object? becameDemonAt = freezed,Object? lastPhotoAt = freezed,Object? joinedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,isHost: null == isHost ? _self.isHost : isHost // ignore: cast_nullable_to_non_nullable
as bool,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,pressureOffset: freezed == pressureOffset ? _self.pressureOffset : pressureOffset // ignore: cast_nullable_to_non_nullable
as double?,pressureSensorAvailable: freezed == pressureSensorAvailable ? _self.pressureSensorAvailable : pressureSensorAvailable // ignore: cast_nullable_to_non_nullable
as bool?,becameDemonAt: freezed == becameDemonAt ? _self.becameDemonAt : becameDemonAt // ignore: cast_nullable_to_non_nullable
as int?,lastPhotoAt: freezed == lastPhotoAt ? _self.lastPhotoAt : lastPhotoAt // ignore: cast_nullable_to_non_nullable
as int?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomUser].
extension RoomUserPatterns on RoomUser {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomUser value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomUser() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomUser value)  $default,){
final _that = this;
switch (_that) {
case _RoomUser():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomUser value)?  $default,){
final _that = this;
switch (_that) {
case _RoomUser() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String displayName,  String deviceId,  bool isHost, @JsonKey(unknownEnumValue: UserRole.fugitive)  UserRole role,  double? pressureOffset,  bool? pressureSensorAvailable,  int? becameDemonAt,  int? lastPhotoAt,  int joinedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomUser() when $default != null:
return $default(_that.id,_that.displayName,_that.deviceId,_that.isHost,_that.role,_that.pressureOffset,_that.pressureSensorAvailable,_that.becameDemonAt,_that.lastPhotoAt,_that.joinedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String displayName,  String deviceId,  bool isHost, @JsonKey(unknownEnumValue: UserRole.fugitive)  UserRole role,  double? pressureOffset,  bool? pressureSensorAvailable,  int? becameDemonAt,  int? lastPhotoAt,  int joinedAt)  $default,) {final _that = this;
switch (_that) {
case _RoomUser():
return $default(_that.id,_that.displayName,_that.deviceId,_that.isHost,_that.role,_that.pressureOffset,_that.pressureSensorAvailable,_that.becameDemonAt,_that.lastPhotoAt,_that.joinedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String displayName,  String deviceId,  bool isHost, @JsonKey(unknownEnumValue: UserRole.fugitive)  UserRole role,  double? pressureOffset,  bool? pressureSensorAvailable,  int? becameDemonAt,  int? lastPhotoAt,  int joinedAt)?  $default,) {final _that = this;
switch (_that) {
case _RoomUser() when $default != null:
return $default(_that.id,_that.displayName,_that.deviceId,_that.isHost,_that.role,_that.pressureOffset,_that.pressureSensorAvailable,_that.becameDemonAt,_that.lastPhotoAt,_that.joinedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomUser extends RoomUser {
  const _RoomUser({required this.id, this.displayName = '', this.deviceId = '', this.isHost = false, @JsonKey(unknownEnumValue: UserRole.fugitive) this.role = UserRole.fugitive, this.pressureOffset, this.pressureSensorAvailable, this.becameDemonAt, this.lastPhotoAt, this.joinedAt = 0}): super._();
  factory _RoomUser.fromJson(Map<String, dynamic> json) => _$RoomUserFromJson(json);

@override final  String id;
@override@JsonKey() final  String displayName;
@override@JsonKey() final  String deviceId;
@override@JsonKey() final  bool isHost;
@override@JsonKey(unknownEnumValue: UserRole.fugitive) final  UserRole role;
@override final  double? pressureOffset;
@override final  bool? pressureSensorAvailable;
@override final  int? becameDemonAt;
@override final  int? lastPhotoAt;
@override@JsonKey() final  int joinedAt;

/// Create a copy of RoomUser
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomUserCopyWith<_RoomUser> get copyWith => __$RoomUserCopyWithImpl<_RoomUser>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomUserToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomUser&&(identical(other.id, id) || other.id == id)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.deviceId, deviceId) || other.deviceId == deviceId)&&(identical(other.isHost, isHost) || other.isHost == isHost)&&(identical(other.role, role) || other.role == role)&&(identical(other.pressureOffset, pressureOffset) || other.pressureOffset == pressureOffset)&&(identical(other.pressureSensorAvailable, pressureSensorAvailable) || other.pressureSensorAvailable == pressureSensorAvailable)&&(identical(other.becameDemonAt, becameDemonAt) || other.becameDemonAt == becameDemonAt)&&(identical(other.lastPhotoAt, lastPhotoAt) || other.lastPhotoAt == lastPhotoAt)&&(identical(other.joinedAt, joinedAt) || other.joinedAt == joinedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,displayName,deviceId,isHost,role,pressureOffset,pressureSensorAvailable,becameDemonAt,lastPhotoAt,joinedAt);

@override
String toString() {
  return 'RoomUser(id: $id, displayName: $displayName, deviceId: $deviceId, isHost: $isHost, role: $role, pressureOffset: $pressureOffset, pressureSensorAvailable: $pressureSensorAvailable, becameDemonAt: $becameDemonAt, lastPhotoAt: $lastPhotoAt, joinedAt: $joinedAt)';
}


}

/// @nodoc
abstract mixin class _$RoomUserCopyWith<$Res> implements $RoomUserCopyWith<$Res> {
  factory _$RoomUserCopyWith(_RoomUser value, $Res Function(_RoomUser) _then) = __$RoomUserCopyWithImpl;
@override @useResult
$Res call({
 String id, String displayName, String deviceId, bool isHost,@JsonKey(unknownEnumValue: UserRole.fugitive) UserRole role, double? pressureOffset, bool? pressureSensorAvailable, int? becameDemonAt, int? lastPhotoAt, int joinedAt
});




}
/// @nodoc
class __$RoomUserCopyWithImpl<$Res>
    implements _$RoomUserCopyWith<$Res> {
  __$RoomUserCopyWithImpl(this._self, this._then);

  final _RoomUser _self;
  final $Res Function(_RoomUser) _then;

/// Create a copy of RoomUser
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? displayName = null,Object? deviceId = null,Object? isHost = null,Object? role = null,Object? pressureOffset = freezed,Object? pressureSensorAvailable = freezed,Object? becameDemonAt = freezed,Object? lastPhotoAt = freezed,Object? joinedAt = null,}) {
  return _then(_RoomUser(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,deviceId: null == deviceId ? _self.deviceId : deviceId // ignore: cast_nullable_to_non_nullable
as String,isHost: null == isHost ? _self.isHost : isHost // ignore: cast_nullable_to_non_nullable
as bool,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,pressureOffset: freezed == pressureOffset ? _self.pressureOffset : pressureOffset // ignore: cast_nullable_to_non_nullable
as double?,pressureSensorAvailable: freezed == pressureSensorAvailable ? _self.pressureSensorAvailable : pressureSensorAvailable // ignore: cast_nullable_to_non_nullable
as bool?,becameDemonAt: freezed == becameDemonAt ? _self.becameDemonAt : becameDemonAt // ignore: cast_nullable_to_non_nullable
as int?,lastPhotoAt: freezed == lastPhotoAt ? _self.lastPhotoAt : lastPhotoAt // ignore: cast_nullable_to_non_nullable
as int?,joinedAt: null == joinedAt ? _self.joinedAt : joinedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
