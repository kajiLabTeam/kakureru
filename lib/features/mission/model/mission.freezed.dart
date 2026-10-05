// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mission.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Mission {

 String get id;/// 何回目のミッションか(1始まり。`missionDueDelays`参照)。
 int get round;/// 書いた時刻(ServerValue.timestamp)。
 int get createdAt;/// 期限(サーバー時刻のミリ秒)。この時刻ちょうどから取れない。
 int get expiresAt;/// 地点がすべて取られて終わった時刻。期限切れでは書かない。
 int? get finishedAt;/// 地点。id順に並べる。
 List<MissionSpot> get spots;
/// Create a copy of Mission
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MissionCopyWith<Mission> get copyWith => _$MissionCopyWithImpl<Mission>(this as Mission, _$identity);

  /// Serializes this Mission to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Mission;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Mission&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.round, _this.round) || other.round == _this.round)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.finishedAt, _this.finishedAt) || other.finishedAt == _this.finishedAt)&&const DeepCollectionEquality().equals(other.spots, _this.spots));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Mission;
  return Object.hash(runtimeType,_this.id,_this.round,_this.createdAt,_this.expiresAt,_this.finishedAt,const DeepCollectionEquality().hash(_this.spots));
}

@override
String toString() {
  final _this = this as Mission;
  return 'Mission(id: ${_this.id}, round: ${_this.round}, createdAt: ${_this.createdAt}, expiresAt: ${_this.expiresAt}, finishedAt: ${_this.finishedAt}, spots: ${_this.spots})';
}


}

/// @nodoc
abstract mixin class $MissionCopyWith<$Res>  {
  factory $MissionCopyWith(Mission value, $Res Function(Mission) _then) = _$MissionCopyWithImpl;
@useResult
$Res call({
 String id, int round, int createdAt, int expiresAt, int? finishedAt, List<MissionSpot> spots
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? round = null,Object? createdAt = null,Object? expiresAt = null,Object? finishedAt = freezed,Object? spots = null,}) {
  return _then(Mission(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as int,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as int?,spots: null == spots ? _self.spots : spots // ignore: cast_nullable_to_non_nullable
as List<MissionSpot>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int round,  int createdAt,  int expiresAt,  int? finishedAt,  List<MissionSpot> spots)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Mission() when $default != null:
return $default(_that.id,_that.round,_that.createdAt,_that.expiresAt,_that.finishedAt,_that.spots);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int round,  int createdAt,  int expiresAt,  int? finishedAt,  List<MissionSpot> spots)  $default,) {final _that = this;
switch (_that) {
case _Mission():
return $default(_that.id,_that.round,_that.createdAt,_that.expiresAt,_that.finishedAt,_that.spots);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int round,  int createdAt,  int expiresAt,  int? finishedAt,  List<MissionSpot> spots)?  $default,) {final _that = this;
switch (_that) {
case _Mission() when $default != null:
return $default(_that.id,_that.round,_that.createdAt,_that.expiresAt,_that.finishedAt,_that.spots);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Mission implements Mission {
  const _Mission({required this.id, required this.round, required this.createdAt, required this.expiresAt, this.finishedAt,  List<MissionSpot> spots = const <MissionSpot>[]}): _spots = spots;
  factory _Mission.fromJson(Map<String, dynamic> json) => _$MissionFromJson(json);

@override final  String id;
/// 何回目のミッションか(1始まり。`missionDueDelays`参照)。
@override final  int round;
/// 書いた時刻(ServerValue.timestamp)。
@override final  int createdAt;
/// 期限(サーバー時刻のミリ秒)。この時刻ちょうどから取れない。
@override final  int expiresAt;
/// 地点がすべて取られて終わった時刻。期限切れでは書かない。
@override final  int? finishedAt;
/// 地点。id順に並べる。
 final  List<MissionSpot> _spots;
/// 地点。id順に並べる。
@override@JsonKey() List<MissionSpot> get spots {
  if (_spots is EqualUnmodifiableListView) return _spots;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_spots);
}


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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Mission&&(identical(other.id, id) || other.id == id)&&(identical(other.round, round) || other.round == round)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.finishedAt, finishedAt) || other.finishedAt == finishedAt)&&const DeepCollectionEquality().equals(other.spots, _spots));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,round,createdAt,expiresAt,finishedAt,const DeepCollectionEquality().hash(_spots));
}

@override
String toString() {
    return 'Mission(id: $id, round: $round, createdAt: $createdAt, expiresAt: $expiresAt, finishedAt: $finishedAt, spots: $spots)';
}


}

/// @nodoc
abstract mixin class _$MissionCopyWith<$Res> implements $MissionCopyWith<$Res> {
  factory _$MissionCopyWith(_Mission value, $Res Function(_Mission) _then) = __$MissionCopyWithImpl;
@override @useResult
$Res call({
 String id, int round, int createdAt, int expiresAt, int? finishedAt, List<MissionSpot> spots
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? round = null,Object? createdAt = null,Object? expiresAt = null,Object? finishedAt = freezed,Object? spots = null,}) {
  return _then(_Mission(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,round: null == round ? _self.round : round // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as int,finishedAt: freezed == finishedAt ? _self.finishedAt : finishedAt // ignore: cast_nullable_to_non_nullable
as int?,spots: null == spots ? _self._spots : spots // ignore: cast_nullable_to_non_nullable
as List<MissionSpot>,
  ));
}


}


/// @nodoc
mixin _$MissionSpot {

 String get id; double get lat; double get lng;/// 判定の半径(m)。
 double get radiusM;/// 先に取った人のuid。未取得はnull。
 String? get claimedBy;/// 取った時刻(サーバー時刻のミリ秒)。
 int? get claimedAt;/// 取った人が引いたごほうび。引く前・知らない値はnull。
@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) RewardType? get reward;
/// Create a copy of MissionSpot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MissionSpotCopyWith<MissionSpot> get copyWith => _$MissionSpotCopyWithImpl<MissionSpot>(this as MissionSpot, _$identity);

  /// Serializes this MissionSpot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MissionSpot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MissionSpot&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.lat, _this.lat) || other.lat == _this.lat)&&(identical(other.lng, _this.lng) || other.lng == _this.lng)&&(identical(other.radiusM, _this.radiusM) || other.radiusM == _this.radiusM)&&(identical(other.claimedBy, _this.claimedBy) || other.claimedBy == _this.claimedBy)&&(identical(other.claimedAt, _this.claimedAt) || other.claimedAt == _this.claimedAt)&&(identical(other.reward, _this.reward) || other.reward == _this.reward));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MissionSpot;
  return Object.hash(runtimeType,_this.id,_this.lat,_this.lng,_this.radiusM,_this.claimedBy,_this.claimedAt,_this.reward);
}

@override
String toString() {
  final _this = this as MissionSpot;
  return 'MissionSpot(id: ${_this.id}, lat: ${_this.lat}, lng: ${_this.lng}, radiusM: ${_this.radiusM}, claimedBy: ${_this.claimedBy}, claimedAt: ${_this.claimedAt}, reward: ${_this.reward})';
}


}

/// @nodoc
abstract mixin class $MissionSpotCopyWith<$Res>  {
  factory $MissionSpotCopyWith(MissionSpot value, $Res Function(MissionSpot) _then) = _$MissionSpotCopyWithImpl;
@useResult
$Res call({
 String id, double lat, double lng, double radiusM, String? claimedBy, int? claimedAt,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) RewardType? reward
});




}
/// @nodoc
class _$MissionSpotCopyWithImpl<$Res>
    implements $MissionSpotCopyWith<$Res> {
  _$MissionSpotCopyWithImpl(this._self, this._then);

  final MissionSpot _self;
  final $Res Function(MissionSpot) _then;

/// Create a copy of MissionSpot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? lat = null,Object? lng = null,Object? radiusM = null,Object? claimedBy = freezed,Object? claimedAt = freezed,Object? reward = freezed,}) {
  return _then(MissionSpot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,radiusM: null == radiusM ? _self.radiusM : radiusM // ignore: cast_nullable_to_non_nullable
as double,claimedBy: freezed == claimedBy ? _self.claimedBy : claimedBy // ignore: cast_nullable_to_non_nullable
as String?,claimedAt: freezed == claimedAt ? _self.claimedAt : claimedAt // ignore: cast_nullable_to_non_nullable
as int?,reward: freezed == reward ? _self.reward : reward // ignore: cast_nullable_to_non_nullable
as RewardType?,
  ));
}

}


/// Adds pattern-matching-related methods to [MissionSpot].
extension MissionSpotPatterns on MissionSpot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MissionSpot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MissionSpot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MissionSpot value)  $default,){
final _that = this;
switch (_that) {
case _MissionSpot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MissionSpot value)?  $default,){
final _that = this;
switch (_that) {
case _MissionSpot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  double lat,  double lng,  double radiusM,  String? claimedBy,  int? claimedAt, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  RewardType? reward)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MissionSpot() when $default != null:
return $default(_that.id,_that.lat,_that.lng,_that.radiusM,_that.claimedBy,_that.claimedAt,_that.reward);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  double lat,  double lng,  double radiusM,  String? claimedBy,  int? claimedAt, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  RewardType? reward)  $default,) {final _that = this;
switch (_that) {
case _MissionSpot():
return $default(_that.id,_that.lat,_that.lng,_that.radiusM,_that.claimedBy,_that.claimedAt,_that.reward);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  double lat,  double lng,  double radiusM,  String? claimedBy,  int? claimedAt, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  RewardType? reward)?  $default,) {final _that = this;
switch (_that) {
case _MissionSpot() when $default != null:
return $default(_that.id,_that.lat,_that.lng,_that.radiusM,_that.claimedBy,_that.claimedAt,_that.reward);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MissionSpot implements MissionSpot {
  const _MissionSpot({required this.id, required this.lat, required this.lng, required this.radiusM, this.claimedBy, this.claimedAt, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.reward});
  factory _MissionSpot.fromJson(Map<String, dynamic> json) => _$MissionSpotFromJson(json);

@override final  String id;
@override final  double lat;
@override final  double lng;
/// 判定の半径(m)。
@override final  double radiusM;
/// 先に取った人のuid。未取得はnull。
@override final  String? claimedBy;
/// 取った時刻(サーバー時刻のミリ秒)。
@override final  int? claimedAt;
/// 取った人が引いたごほうび。引く前・知らない値はnull。
@override@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) final  RewardType? reward;

/// Create a copy of MissionSpot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MissionSpotCopyWith<_MissionSpot> get copyWith => __$MissionSpotCopyWithImpl<_MissionSpot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MissionSpotToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MissionSpot&&(identical(other.id, id) || other.id == id)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.radiusM, radiusM) || other.radiusM == radiusM)&&(identical(other.claimedBy, claimedBy) || other.claimedBy == claimedBy)&&(identical(other.claimedAt, claimedAt) || other.claimedAt == claimedAt)&&(identical(other.reward, reward) || other.reward == reward));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,lat,lng,radiusM,claimedBy,claimedAt,reward);
}

@override
String toString() {
    return 'MissionSpot(id: $id, lat: $lat, lng: $lng, radiusM: $radiusM, claimedBy: $claimedBy, claimedAt: $claimedAt, reward: $reward)';
}


}

/// @nodoc
abstract mixin class _$MissionSpotCopyWith<$Res> implements $MissionSpotCopyWith<$Res> {
  factory _$MissionSpotCopyWith(_MissionSpot value, $Res Function(_MissionSpot) _then) = __$MissionSpotCopyWithImpl;
@override @useResult
$Res call({
 String id, double lat, double lng, double radiusM, String? claimedBy, int? claimedAt,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) RewardType? reward
});




}
/// @nodoc
class __$MissionSpotCopyWithImpl<$Res>
    implements _$MissionSpotCopyWith<$Res> {
  __$MissionSpotCopyWithImpl(this._self, this._then);

  final _MissionSpot _self;
  final $Res Function(_MissionSpot) _then;

/// Create a copy of MissionSpot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? lat = null,Object? lng = null,Object? radiusM = null,Object? claimedBy = freezed,Object? claimedAt = freezed,Object? reward = freezed,}) {
  return _then(_MissionSpot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,radiusM: null == radiusM ? _self.radiusM : radiusM // ignore: cast_nullable_to_non_nullable
as double,claimedBy: freezed == claimedBy ? _self.claimedBy : claimedBy // ignore: cast_nullable_to_non_nullable
as String?,claimedAt: freezed == claimedAt ? _self.claimedAt : claimedAt // ignore: cast_nullable_to_non_nullable
as int?,reward: freezed == reward ? _self.reward : reward // ignore: cast_nullable_to_non_nullable
as RewardType?,
  ));
}


}

// dart format on
