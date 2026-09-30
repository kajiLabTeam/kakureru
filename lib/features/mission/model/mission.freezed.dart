// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mission.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Mission {

 String get id; MissionType get type;/// 書いた時刻(ServerValue.timestamp)。
 int get createdAt;/// 期限(サーバー時刻のミリ秒)。この時刻ちょうどから取れない。
 int get expiresAt;/// 地点(access_pointのみ)。
 double? get lat; double? get lng;/// 判定の半径(m。access_pointのみ)。
 double? get radiusM;/// 先に取った人のuid。未取得はnull。
 String? get claimedBy;/// 取った時刻(サーバー時刻のミリ秒)。
 int? get claimedAt;/// 取った人が引いた特典。引く前・知らない値はnull。
@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) RewardType? get reward;
/// Create a copy of Mission
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MissionCopyWith<Mission> get copyWith => _$MissionCopyWithImpl<Mission>(this as Mission, _$identity);

  /// Serializes this Mission to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Mission&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.radiusM, radiusM) || other.radiusM == radiusM)&&(identical(other.claimedBy, claimedBy) || other.claimedBy == claimedBy)&&(identical(other.claimedAt, claimedAt) || other.claimedAt == claimedAt)&&(identical(other.reward, reward) || other.reward == reward));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,createdAt,expiresAt,lat,lng,radiusM,claimedBy,claimedAt,reward);

@override
String toString() {
  return 'Mission(id: $id, type: $type, createdAt: $createdAt, expiresAt: $expiresAt, lat: $lat, lng: $lng, radiusM: $radiusM, claimedBy: $claimedBy, claimedAt: $claimedAt, reward: $reward)';
}


}

/// @nodoc
abstract mixin class $MissionCopyWith<$Res>  {
  factory $MissionCopyWith(Mission value, $Res Function(Mission) _then) = _$MissionCopyWithImpl;
@useResult
$Res call({
 String id, MissionType type, int createdAt, int expiresAt, double? lat, double? lng, double? radiusM, String? claimedBy, int? claimedAt,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) RewardType? reward
});




}
/// @nodoc
class _$MissionCopyWithImpl<$Res>
    implements $MissionCopyWith<$Res> {
  _$MissionCopyWithImpl(this._self, this._then);

  final Mission _self;
  final $Res Function(Mission) _then;

/// Create a copy of Mission
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? createdAt = null,Object? expiresAt = null,Object? lat = freezed,Object? lng = freezed,Object? radiusM = freezed,Object? claimedBy = freezed,Object? claimedAt = freezed,Object? reward = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MissionType,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as int,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,radiusM: freezed == radiusM ? _self.radiusM : radiusM // ignore: cast_nullable_to_non_nullable
as double?,claimedBy: freezed == claimedBy ? _self.claimedBy : claimedBy // ignore: cast_nullable_to_non_nullable
as String?,claimedAt: freezed == claimedAt ? _self.claimedAt : claimedAt // ignore: cast_nullable_to_non_nullable
as int?,reward: freezed == reward ? _self.reward : reward // ignore: cast_nullable_to_non_nullable
as RewardType?,
  ));
}

}


/// Adds pattern-matching-related methods to [Mission].
extension MissionPatterns on Mission {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Mission value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Mission() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Mission value)  $default,){
final _that = this;
switch (_that) {
case _Mission():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Mission value)?  $default,){
final _that = this;
switch (_that) {
case _Mission() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  MissionType type,  int createdAt,  int expiresAt,  double? lat,  double? lng,  double? radiusM,  String? claimedBy,  int? claimedAt, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  RewardType? reward)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Mission() when $default != null:
return $default(_that.id,_that.type,_that.createdAt,_that.expiresAt,_that.lat,_that.lng,_that.radiusM,_that.claimedBy,_that.claimedAt,_that.reward);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  MissionType type,  int createdAt,  int expiresAt,  double? lat,  double? lng,  double? radiusM,  String? claimedBy,  int? claimedAt, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  RewardType? reward)  $default,) {final _that = this;
switch (_that) {
case _Mission():
return $default(_that.id,_that.type,_that.createdAt,_that.expiresAt,_that.lat,_that.lng,_that.radiusM,_that.claimedBy,_that.claimedAt,_that.reward);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  MissionType type,  int createdAt,  int expiresAt,  double? lat,  double? lng,  double? radiusM,  String? claimedBy,  int? claimedAt, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  RewardType? reward)?  $default,) {final _that = this;
switch (_that) {
case _Mission() when $default != null:
return $default(_that.id,_that.type,_that.createdAt,_that.expiresAt,_that.lat,_that.lng,_that.radiusM,_that.claimedBy,_that.claimedAt,_that.reward);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Mission implements Mission {
  const _Mission({required this.id, required this.type, required this.createdAt, required this.expiresAt, this.lat, this.lng, this.radiusM, this.claimedBy, this.claimedAt, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.reward});
  factory _Mission.fromJson(Map<String, dynamic> json) => _$MissionFromJson(json);

@override final  String id;
@override final  MissionType type;
/// 書いた時刻(ServerValue.timestamp)。
@override final  int createdAt;
/// 期限(サーバー時刻のミリ秒)。この時刻ちょうどから取れない。
@override final  int expiresAt;
/// 地点(access_pointのみ)。
@override final  double? lat;
@override final  double? lng;
/// 判定の半径(m。access_pointのみ)。
@override final  double? radiusM;
/// 先に取った人のuid。未取得はnull。
@override final  String? claimedBy;
/// 取った時刻(サーバー時刻のミリ秒)。
@override final  int? claimedAt;
/// 取った人が引いた特典。引く前・知らない値はnull。
@override@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) final  RewardType? reward;

/// Create a copy of Mission
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MissionCopyWith<_Mission> get copyWith => __$MissionCopyWithImpl<_Mission>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MissionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Mission&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.radiusM, radiusM) || other.radiusM == radiusM)&&(identical(other.claimedBy, claimedBy) || other.claimedBy == claimedBy)&&(identical(other.claimedAt, claimedAt) || other.claimedAt == claimedAt)&&(identical(other.reward, reward) || other.reward == reward));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,createdAt,expiresAt,lat,lng,radiusM,claimedBy,claimedAt,reward);

@override
String toString() {
  return 'Mission(id: $id, type: $type, createdAt: $createdAt, expiresAt: $expiresAt, lat: $lat, lng: $lng, radiusM: $radiusM, claimedBy: $claimedBy, claimedAt: $claimedAt, reward: $reward)';
}


}

/// @nodoc
abstract mixin class _$MissionCopyWith<$Res> implements $MissionCopyWith<$Res> {
  factory _$MissionCopyWith(_Mission value, $Res Function(_Mission) _then) = __$MissionCopyWithImpl;
@override @useResult
$Res call({
 String id, MissionType type, int createdAt, int expiresAt, double? lat, double? lng, double? radiusM, String? claimedBy, int? claimedAt,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) RewardType? reward
});




}
/// @nodoc
class __$MissionCopyWithImpl<$Res>
    implements _$MissionCopyWith<$Res> {
  __$MissionCopyWithImpl(this._self, this._then);

  final _Mission _self;
  final $Res Function(_Mission) _then;

/// Create a copy of Mission
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? createdAt = null,Object? expiresAt = null,Object? lat = freezed,Object? lng = freezed,Object? radiusM = freezed,Object? claimedBy = freezed,Object? claimedAt = freezed,Object? reward = freezed,}) {
  return _then(_Mission(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as MissionType,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as int,lat: freezed == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double?,lng: freezed == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double?,radiusM: freezed == radiusM ? _self.radiusM : radiusM // ignore: cast_nullable_to_non_nullable
as double?,claimedBy: freezed == claimedBy ? _self.claimedBy : claimedBy // ignore: cast_nullable_to_non_nullable
as String?,claimedAt: freezed == claimedAt ? _self.claimedAt : claimedAt // ignore: cast_nullable_to_non_nullable
as int?,reward: freezed == reward ? _self.reward : reward // ignore: cast_nullable_to_non_nullable
as RewardType?,
  ));
}


}

// dart format on
