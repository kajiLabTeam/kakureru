// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mission_notice.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MissionNotice {

 MissionNoticeKind get kind; String get missionId; String get message;
/// Create a copy of MissionNotice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MissionNoticeCopyWith<MissionNotice> get copyWith => _$MissionNoticeCopyWithImpl<MissionNotice>(this as MissionNotice, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MissionNotice;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MissionNotice&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.missionId, _this.missionId) || other.missionId == _this.missionId)&&(identical(other.message, _this.message) || other.message == _this.message));
}


@override
int get hashCode {
  final _this = this as MissionNotice;
  return Object.hash(runtimeType,_this.kind,_this.missionId,_this.message);
}

@override
String toString() {
  final _this = this as MissionNotice;
  return 'MissionNotice(kind: ${_this.kind}, missionId: ${_this.missionId}, message: ${_this.message})';
}


}

/// @nodoc
abstract mixin class $MissionNoticeCopyWith<$Res>  {
  factory $MissionNoticeCopyWith(MissionNotice value, $Res Function(MissionNotice) _then) = _$MissionNoticeCopyWithImpl;
@useResult
$Res call({
 MissionNoticeKind kind, String missionId, String message
});




}
/// @nodoc
class _$MissionNoticeCopyWithImpl<$Res>
    implements $MissionNoticeCopyWith<$Res> {
  _$MissionNoticeCopyWithImpl(this._self, this._then);

  final MissionNotice _self;
  final $Res Function(MissionNotice) _then;

/// Create a copy of MissionNotice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? missionId = null,Object? message = null,}) {
  return _then(MissionNotice(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MissionNoticeKind,missionId: null == missionId ? _self.missionId : missionId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MissionNotice].
extension MissionNoticePatterns on MissionNotice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MissionNotice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MissionNotice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MissionNotice value)  $default,){
final _that = this;
switch (_that) {
case _MissionNotice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MissionNotice value)?  $default,){
final _that = this;
switch (_that) {
case _MissionNotice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MissionNoticeKind kind,  String missionId,  String message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MissionNotice() when $default != null:
return $default(_that.kind,_that.missionId,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MissionNoticeKind kind,  String missionId,  String message)  $default,) {final _that = this;
switch (_that) {
case _MissionNotice():
return $default(_that.kind,_that.missionId,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MissionNoticeKind kind,  String missionId,  String message)?  $default,) {final _that = this;
switch (_that) {
case _MissionNotice() when $default != null:
return $default(_that.kind,_that.missionId,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class _MissionNotice extends MissionNotice {
  const _MissionNotice({required this.kind, required this.missionId, required this.message}): super._();
  

@override final  MissionNoticeKind kind;
@override final  String missionId;
@override final  String message;

/// Create a copy of MissionNotice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MissionNoticeCopyWith<_MissionNotice> get copyWith => __$MissionNoticeCopyWithImpl<_MissionNotice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MissionNotice&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.missionId, missionId) || other.missionId == missionId)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kind,missionId,message);
}

@override
String toString() {
    return 'MissionNotice(kind: $kind, missionId: $missionId, message: $message)';
}


}

/// @nodoc
abstract mixin class _$MissionNoticeCopyWith<$Res> implements $MissionNoticeCopyWith<$Res> {
  factory _$MissionNoticeCopyWith(_MissionNotice value, $Res Function(_MissionNotice) _then) = __$MissionNoticeCopyWithImpl;
@override @useResult
$Res call({
 MissionNoticeKind kind, String missionId, String message
});




}
/// @nodoc
class __$MissionNoticeCopyWithImpl<$Res>
    implements _$MissionNoticeCopyWith<$Res> {
  __$MissionNoticeCopyWithImpl(this._self, this._then);

  final _MissionNotice _self;
  final $Res Function(_MissionNotice) _then;

/// Create a copy of MissionNotice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? missionId = null,Object? message = null,}) {
  return _then(_MissionNotice(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as MissionNoticeKind,missionId: null == missionId ? _self.missionId : missionId // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
