// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'room_effect.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RoomEffect {

 String get id; RewardType get type;/// 引いた人のuid。
 String get byUid;/// 発動した時刻(ServerValue.timestamp)。
 int get startedAt;/// 効いている時間(ミリ秒)。回数もの(skip_foot_photo)は0。
 int get durationMs;/// skip_foot_photo で飛ばす撮影スロットの番号。引いた瞬間の状態(撮影
/// タイムが来ていたか)で決めて書く。後から撮り直しても変わらないように、
/// 読む側で計算し直さない。古いデータには無い。
 int? get skipSlot;
/// Create a copy of RoomEffect
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoomEffectCopyWith<RoomEffect> get copyWith => _$RoomEffectCopyWithImpl<RoomEffect>(this as RoomEffect, _$identity);

  /// Serializes this RoomEffect to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RoomEffect;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoomEffect&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.byUid, _this.byUid) || other.byUid == _this.byUid)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&(identical(other.skipSlot, _this.skipSlot) || other.skipSlot == _this.skipSlot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RoomEffect;
  return Object.hash(runtimeType,_this.id,_this.type,_this.byUid,_this.startedAt,_this.durationMs,_this.skipSlot);
}

@override
String toString() {
  final _this = this as RoomEffect;
  return 'RoomEffect(id: ${_this.id}, type: ${_this.type}, byUid: ${_this.byUid}, startedAt: ${_this.startedAt}, durationMs: ${_this.durationMs}, skipSlot: ${_this.skipSlot})';
}


}

/// @nodoc
abstract mixin class $RoomEffectCopyWith<$Res>  {
  factory $RoomEffectCopyWith(RoomEffect value, $Res Function(RoomEffect) _then) = _$RoomEffectCopyWithImpl;
@useResult
$Res call({
 String id, RewardType type, String byUid, int startedAt, int durationMs, int? skipSlot
});




}
/// @nodoc
class _$RoomEffectCopyWithImpl<$Res>
    implements $RoomEffectCopyWith<$Res> {
  _$RoomEffectCopyWithImpl(this._self, this._then);

  final RoomEffect _self;
  final $Res Function(RoomEffect) _then;

/// Create a copy of RoomEffect
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? byUid = null,Object? startedAt = null,Object? durationMs = null,Object? skipSlot = freezed,}) {
  return _then(RoomEffect(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RewardType,byUid: null == byUid ? _self.byUid : byUid // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as int,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,skipSlot: freezed == skipSlot ? _self.skipSlot : skipSlot // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [RoomEffect].
extension RoomEffectPatterns on RoomEffect {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoomEffect value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoomEffect() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoomEffect value)  $default,){
final _that = this;
switch (_that) {
case _RoomEffect():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoomEffect value)?  $default,){
final _that = this;
switch (_that) {
case _RoomEffect() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  RewardType type,  String byUid,  int startedAt,  int durationMs,  int? skipSlot)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoomEffect() when $default != null:
return $default(_that.id,_that.type,_that.byUid,_that.startedAt,_that.durationMs,_that.skipSlot);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  RewardType type,  String byUid,  int startedAt,  int durationMs,  int? skipSlot)  $default,) {final _that = this;
switch (_that) {
case _RoomEffect():
return $default(_that.id,_that.type,_that.byUid,_that.startedAt,_that.durationMs,_that.skipSlot);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  RewardType type,  String byUid,  int startedAt,  int durationMs,  int? skipSlot)?  $default,) {final _that = this;
switch (_that) {
case _RoomEffect() when $default != null:
return $default(_that.id,_that.type,_that.byUid,_that.startedAt,_that.durationMs,_that.skipSlot);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoomEffect implements RoomEffect {
  const _RoomEffect({required this.id, required this.type, required this.byUid, required this.startedAt, required this.durationMs, this.skipSlot});
  factory _RoomEffect.fromJson(Map<String, dynamic> json) => _$RoomEffectFromJson(json);

@override final  String id;
@override final  RewardType type;
/// 引いた人のuid。
@override final  String byUid;
/// 発動した時刻(ServerValue.timestamp)。
@override final  int startedAt;
/// 効いている時間(ミリ秒)。回数もの(skip_foot_photo)は0。
@override final  int durationMs;
/// skip_foot_photo で飛ばす撮影スロットの番号。引いた瞬間の状態(撮影
/// タイムが来ていたか)で決めて書く。後から撮り直しても変わらないように、
/// 読む側で計算し直さない。古いデータには無い。
@override final  int? skipSlot;

/// Create a copy of RoomEffect
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoomEffectCopyWith<_RoomEffect> get copyWith => __$RoomEffectCopyWithImpl<_RoomEffect>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoomEffectToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoomEffect&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.byUid, byUid) || other.byUid == byUid)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.skipSlot, skipSlot) || other.skipSlot == skipSlot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,type,byUid,startedAt,durationMs,skipSlot);
}

@override
String toString() {
    return 'RoomEffect(id: $id, type: $type, byUid: $byUid, startedAt: $startedAt, durationMs: $durationMs, skipSlot: $skipSlot)';
}


}

/// @nodoc
abstract mixin class _$RoomEffectCopyWith<$Res> implements $RoomEffectCopyWith<$Res> {
  factory _$RoomEffectCopyWith(_RoomEffect value, $Res Function(_RoomEffect) _then) = __$RoomEffectCopyWithImpl;
@override @useResult
$Res call({
 String id, RewardType type, String byUid, int startedAt, int durationMs, int? skipSlot
});




}
/// @nodoc
class __$RoomEffectCopyWithImpl<$Res>
    implements _$RoomEffectCopyWith<$Res> {
  __$RoomEffectCopyWithImpl(this._self, this._then);

  final _RoomEffect _self;
  final $Res Function(_RoomEffect) _then;

/// Create a copy of RoomEffect
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? byUid = null,Object? startedAt = null,Object? durationMs = null,Object? skipSlot = freezed,}) {
  return _then(_RoomEffect(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as RewardType,byUid: null == byUid ? _self.byUid : byUid // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as int,durationMs: null == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int,skipSlot: freezed == skipSlot ? _self.skipSlot : skipSlot // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
