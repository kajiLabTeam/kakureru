// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Room {

 String get id; String get roomCode; String get hostUserId; RoomStatus get status; double? get basePressure; int get createdAt; int? get startedAt; int? get releasedAt; int? get endsAt; int? get endedAt; String? get pendingDemonUid; RoomSetting get setting; List<RoomUser> get users;
/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomCopyWith<Room> get copyWith => _$RoomCopyWithImpl<Room>(this as Room, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Room&&(identical(other.id, id) || other.id == id)&&(identical(other.roomCode, roomCode) || other.roomCode == roomCode)&&(identical(other.hostUserId, hostUserId) || other.hostUserId == hostUserId)&&(identical(other.status, status) || other.status == status)&&(identical(other.basePressure, basePressure) || other.basePressure == basePressure)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.releasedAt, releasedAt) || other.releasedAt == releasedAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.pendingDemonUid, pendingDemonUid) || other.pendingDemonUid == pendingDemonUid)&&(identical(other.setting, setting) || other.setting == setting)&&const DeepCollectionEquality().equals(other.users, users));
}


@override
int get hashCode => Object.hash(runtimeType,id,roomCode,hostUserId,status,basePressure,createdAt,startedAt,releasedAt,endsAt,endedAt,pendingDemonUid,setting,const DeepCollectionEquality().hash(users));

@override
String toString() {
  return 'Room(id: $id, roomCode: $roomCode, hostUserId: $hostUserId, status: $status, basePressure: $basePressure, createdAt: $createdAt, startedAt: $startedAt, releasedAt: $releasedAt, endsAt: $endsAt, endedAt: $endedAt, pendingDemonUid: $pendingDemonUid, setting: $setting, users: $users)';
}


}

/// @nodoc
abstract mixin class $RoomCopyWith<$Res>  {
  factory $RoomCopyWith(Room value, $Res Function(Room) _then) = _$RoomCopyWithImpl;
@useResult
$Res call({
 String id, String roomCode, String hostUserId, RoomStatus status, double? basePressure, int createdAt, int? startedAt, int? releasedAt, int? endsAt, int? endedAt, String? pendingDemonUid, RoomSetting setting, List<RoomUser> users
});


$RoomSettingCopyWith<$Res> get setting;

}
/// @nodoc
class _$RoomCopyWithImpl<$Res>
    implements $RoomCopyWith<$Res> {
  _$RoomCopyWithImpl(this._self, this._then);

  final Room _self;
  final $Res Function(Room) _then;

/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? roomCode = null,Object? hostUserId = null,Object? status = null,Object? basePressure = freezed,Object? createdAt = null,Object? startedAt = freezed,Object? releasedAt = freezed,Object? endsAt = freezed,Object? endedAt = freezed,Object? pendingDemonUid = freezed,Object? setting = null,Object? users = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomCode: null == roomCode ? _self.roomCode : roomCode // ignore: cast_nullable_to_non_nullable
as String,hostUserId: null == hostUserId ? _self.hostUserId : hostUserId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RoomStatus,basePressure: freezed == basePressure ? _self.basePressure : basePressure // ignore: cast_nullable_to_non_nullable
as double?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as int?,releasedAt: freezed == releasedAt ? _self.releasedAt : releasedAt // ignore: cast_nullable_to_non_nullable
as int?,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as int?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as int?,pendingDemonUid: freezed == pendingDemonUid ? _self.pendingDemonUid : pendingDemonUid // ignore: cast_nullable_to_non_nullable
as String?,setting: null == setting ? _self.setting : setting // ignore: cast_nullable_to_non_nullable
as RoomSetting,users: null == users ? _self.users : users // ignore: cast_nullable_to_non_nullable
as List<RoomUser>,
  ));
}
/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomSettingCopyWith<$Res> get setting {
  
  return $RoomSettingCopyWith<$Res>(_self.setting, (value) {
    return _then(_self.copyWith(setting: value));
  });
}
}


/// Adds pattern-matching-related methods to [Room].
extension RoomPatterns on Room {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Room value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Room() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Room value)  $default,){
final _that = this;
switch (_that) {
case _Room():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Room value)?  $default,){
final _that = this;
switch (_that) {
case _Room() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String roomCode,  String hostUserId,  RoomStatus status,  double? basePressure,  int createdAt,  int? startedAt,  int? releasedAt,  int? endsAt,  int? endedAt,  String? pendingDemonUid,  RoomSetting setting,  List<RoomUser> users)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Room() when $default != null:
return $default(_that.id,_that.roomCode,_that.hostUserId,_that.status,_that.basePressure,_that.createdAt,_that.startedAt,_that.releasedAt,_that.endsAt,_that.endedAt,_that.pendingDemonUid,_that.setting,_that.users);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String roomCode,  String hostUserId,  RoomStatus status,  double? basePressure,  int createdAt,  int? startedAt,  int? releasedAt,  int? endsAt,  int? endedAt,  String? pendingDemonUid,  RoomSetting setting,  List<RoomUser> users)  $default,) {final _that = this;
switch (_that) {
case _Room():
return $default(_that.id,_that.roomCode,_that.hostUserId,_that.status,_that.basePressure,_that.createdAt,_that.startedAt,_that.releasedAt,_that.endsAt,_that.endedAt,_that.pendingDemonUid,_that.setting,_that.users);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String roomCode,  String hostUserId,  RoomStatus status,  double? basePressure,  int createdAt,  int? startedAt,  int? releasedAt,  int? endsAt,  int? endedAt,  String? pendingDemonUid,  RoomSetting setting,  List<RoomUser> users)?  $default,) {final _that = this;
switch (_that) {
case _Room() when $default != null:
return $default(_that.id,_that.roomCode,_that.hostUserId,_that.status,_that.basePressure,_that.createdAt,_that.startedAt,_that.releasedAt,_that.endsAt,_that.endedAt,_that.pendingDemonUid,_that.setting,_that.users);case _:
  return null;

}
}

}

/// @nodoc


class _Room implements Room {
  const _Room({required this.id, required this.roomCode, required this.hostUserId, required this.status, this.basePressure, required this.createdAt, this.startedAt, this.releasedAt, this.endsAt, this.endedAt, this.pendingDemonUid, required this.setting, required final  List<RoomUser> users}): _users = users;
  

@override final  String id;
@override final  String roomCode;
@override final  String hostUserId;
@override final  RoomStatus status;
@override final  double? basePressure;
@override final  int createdAt;
@override final  int? startedAt;
@override final  int? releasedAt;
@override final  int? endsAt;
@override final  int? endedAt;
@override final  String? pendingDemonUid;
@override final  RoomSetting setting;
 final  List<RoomUser> _users;
@override List<RoomUser> get users {
  if (_users is EqualUnmodifiableListView) return _users;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_users);
}


/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomCopyWith<_Room> get copyWith => __$RoomCopyWithImpl<_Room>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Room&&(identical(other.id, id) || other.id == id)&&(identical(other.roomCode, roomCode) || other.roomCode == roomCode)&&(identical(other.hostUserId, hostUserId) || other.hostUserId == hostUserId)&&(identical(other.status, status) || other.status == status)&&(identical(other.basePressure, basePressure) || other.basePressure == basePressure)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.releasedAt, releasedAt) || other.releasedAt == releasedAt)&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.pendingDemonUid, pendingDemonUid) || other.pendingDemonUid == pendingDemonUid)&&(identical(other.setting, setting) || other.setting == setting)&&const DeepCollectionEquality().equals(other._users, _users));
}


@override
int get hashCode => Object.hash(runtimeType,id,roomCode,hostUserId,status,basePressure,createdAt,startedAt,releasedAt,endsAt,endedAt,pendingDemonUid,setting,const DeepCollectionEquality().hash(_users));

@override
String toString() {
  return 'Room(id: $id, roomCode: $roomCode, hostUserId: $hostUserId, status: $status, basePressure: $basePressure, createdAt: $createdAt, startedAt: $startedAt, releasedAt: $releasedAt, endsAt: $endsAt, endedAt: $endedAt, pendingDemonUid: $pendingDemonUid, setting: $setting, users: $users)';
}


}

/// @nodoc
abstract mixin class _$RoomCopyWith<$Res> implements $RoomCopyWith<$Res> {
  factory _$RoomCopyWith(_Room value, $Res Function(_Room) _then) = __$RoomCopyWithImpl;
@override @useResult
$Res call({
 String id, String roomCode, String hostUserId, RoomStatus status, double? basePressure, int createdAt, int? startedAt, int? releasedAt, int? endsAt, int? endedAt, String? pendingDemonUid, RoomSetting setting, List<RoomUser> users
});


@override $RoomSettingCopyWith<$Res> get setting;

}
/// @nodoc
class __$RoomCopyWithImpl<$Res>
    implements _$RoomCopyWith<$Res> {
  __$RoomCopyWithImpl(this._self, this._then);

  final _Room _self;
  final $Res Function(_Room) _then;

/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? roomCode = null,Object? hostUserId = null,Object? status = null,Object? basePressure = freezed,Object? createdAt = null,Object? startedAt = freezed,Object? releasedAt = freezed,Object? endsAt = freezed,Object? endedAt = freezed,Object? pendingDemonUid = freezed,Object? setting = null,Object? users = null,}) {
  return _then(_Room(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,roomCode: null == roomCode ? _self.roomCode : roomCode // ignore: cast_nullable_to_non_nullable
as String,hostUserId: null == hostUserId ? _self.hostUserId : hostUserId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as RoomStatus,basePressure: freezed == basePressure ? _self.basePressure : basePressure // ignore: cast_nullable_to_non_nullable
as double?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as int?,releasedAt: freezed == releasedAt ? _self.releasedAt : releasedAt // ignore: cast_nullable_to_non_nullable
as int?,endsAt: freezed == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as int?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as int?,pendingDemonUid: freezed == pendingDemonUid ? _self.pendingDemonUid : pendingDemonUid // ignore: cast_nullable_to_non_nullable
as String?,setting: null == setting ? _self.setting : setting // ignore: cast_nullable_to_non_nullable
as RoomSetting,users: null == users ? _self._users : users // ignore: cast_nullable_to_non_nullable
as List<RoomUser>,
  ));
}

/// Create a copy of Room
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RoomSettingCopyWith<$Res> get setting {
  
  return $RoomSettingCopyWith<$Res>(_self.setting, (value) {
    return _then(_self.copyWith(setting: value));
  });
}
}

// dart format on
