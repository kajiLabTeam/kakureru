// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'photo_capture_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PhotoCaptureState {

/// 次の撮影タイミングが来ているか。trueの間だけ撮影バナーを出す。
 bool get isDue;/// アップロード中(通信・RTDB書き込み含む)か。
 bool get isUploading;/// アップロードが最終的に失敗した後、手動再送のために保持している画像。
/// 成功時・413での失敗時はnullに戻す。
 Uint8List? get pendingBytes;/// 直近の失敗の説明文。バナーに出す。成功したらnullに戻す。
 String? get lastErrorMessage;
/// Create a copy of PhotoCaptureState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoCaptureStateCopyWith<PhotoCaptureState> get copyWith => _$PhotoCaptureStateCopyWithImpl<PhotoCaptureState>(this as PhotoCaptureState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoCaptureState&&(identical(other.isDue, isDue) || other.isDue == isDue)&&(identical(other.isUploading, isUploading) || other.isUploading == isUploading)&&const DeepCollectionEquality().equals(other.pendingBytes, pendingBytes)&&(identical(other.lastErrorMessage, lastErrorMessage) || other.lastErrorMessage == lastErrorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,isDue,isUploading,const DeepCollectionEquality().hash(pendingBytes),lastErrorMessage);

@override
String toString() {
  return 'PhotoCaptureState(isDue: $isDue, isUploading: $isUploading, pendingBytes: $pendingBytes, lastErrorMessage: $lastErrorMessage)';
}


}

/// @nodoc
abstract mixin class $PhotoCaptureStateCopyWith<$Res>  {
  factory $PhotoCaptureStateCopyWith(PhotoCaptureState value, $Res Function(PhotoCaptureState) _then) = _$PhotoCaptureStateCopyWithImpl;
@useResult
$Res call({
 bool isDue, bool isUploading, Uint8List? pendingBytes, String? lastErrorMessage
});




}
/// @nodoc
class _$PhotoCaptureStateCopyWithImpl<$Res>
    implements $PhotoCaptureStateCopyWith<$Res> {
  _$PhotoCaptureStateCopyWithImpl(this._self, this._then);

  final PhotoCaptureState _self;
  final $Res Function(PhotoCaptureState) _then;

/// Create a copy of PhotoCaptureState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isDue = null,Object? isUploading = null,Object? pendingBytes = freezed,Object? lastErrorMessage = freezed,}) {
  return _then(_self.copyWith(
isDue: null == isDue ? _self.isDue : isDue // ignore: cast_nullable_to_non_nullable
as bool,isUploading: null == isUploading ? _self.isUploading : isUploading // ignore: cast_nullable_to_non_nullable
as bool,pendingBytes: freezed == pendingBytes ? _self.pendingBytes : pendingBytes // ignore: cast_nullable_to_non_nullable
as Uint8List?,lastErrorMessage: freezed == lastErrorMessage ? _self.lastErrorMessage : lastErrorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [PhotoCaptureState].
extension PhotoCaptureStatePatterns on PhotoCaptureState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhotoCaptureState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhotoCaptureState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhotoCaptureState value)  $default,){
final _that = this;
switch (_that) {
case _PhotoCaptureState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhotoCaptureState value)?  $default,){
final _that = this;
switch (_that) {
case _PhotoCaptureState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isDue,  bool isUploading,  Uint8List? pendingBytes,  String? lastErrorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhotoCaptureState() when $default != null:
return $default(_that.isDue,_that.isUploading,_that.pendingBytes,_that.lastErrorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isDue,  bool isUploading,  Uint8List? pendingBytes,  String? lastErrorMessage)  $default,) {final _that = this;
switch (_that) {
case _PhotoCaptureState():
return $default(_that.isDue,_that.isUploading,_that.pendingBytes,_that.lastErrorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isDue,  bool isUploading,  Uint8List? pendingBytes,  String? lastErrorMessage)?  $default,) {final _that = this;
switch (_that) {
case _PhotoCaptureState() when $default != null:
return $default(_that.isDue,_that.isUploading,_that.pendingBytes,_that.lastErrorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _PhotoCaptureState implements PhotoCaptureState {
  const _PhotoCaptureState({this.isDue = false, this.isUploading = false, this.pendingBytes, this.lastErrorMessage});
  

/// 次の撮影タイミングが来ているか。trueの間だけ撮影バナーを出す。
@override@JsonKey() final  bool isDue;
/// アップロード中(通信・RTDB書き込み含む)か。
@override@JsonKey() final  bool isUploading;
/// アップロードが最終的に失敗した後、手動再送のために保持している画像。
/// 成功時・413での失敗時はnullに戻す。
@override final  Uint8List? pendingBytes;
/// 直近の失敗の説明文。バナーに出す。成功したらnullに戻す。
@override final  String? lastErrorMessage;

/// Create a copy of PhotoCaptureState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoCaptureStateCopyWith<_PhotoCaptureState> get copyWith => __$PhotoCaptureStateCopyWithImpl<_PhotoCaptureState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhotoCaptureState&&(identical(other.isDue, isDue) || other.isDue == isDue)&&(identical(other.isUploading, isUploading) || other.isUploading == isUploading)&&const DeepCollectionEquality().equals(other.pendingBytes, pendingBytes)&&(identical(other.lastErrorMessage, lastErrorMessage) || other.lastErrorMessage == lastErrorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,isDue,isUploading,const DeepCollectionEquality().hash(pendingBytes),lastErrorMessage);

@override
String toString() {
  return 'PhotoCaptureState(isDue: $isDue, isUploading: $isUploading, pendingBytes: $pendingBytes, lastErrorMessage: $lastErrorMessage)';
}


}

/// @nodoc
abstract mixin class _$PhotoCaptureStateCopyWith<$Res> implements $PhotoCaptureStateCopyWith<$Res> {
  factory _$PhotoCaptureStateCopyWith(_PhotoCaptureState value, $Res Function(_PhotoCaptureState) _then) = __$PhotoCaptureStateCopyWithImpl;
@override @useResult
$Res call({
 bool isDue, bool isUploading, Uint8List? pendingBytes, String? lastErrorMessage
});




}
/// @nodoc
class __$PhotoCaptureStateCopyWithImpl<$Res>
    implements _$PhotoCaptureStateCopyWith<$Res> {
  __$PhotoCaptureStateCopyWithImpl(this._self, this._then);

  final _PhotoCaptureState _self;
  final $Res Function(_PhotoCaptureState) _then;

/// Create a copy of PhotoCaptureState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isDue = null,Object? isUploading = null,Object? pendingBytes = freezed,Object? lastErrorMessage = freezed,}) {
  return _then(_PhotoCaptureState(
isDue: null == isDue ? _self.isDue : isDue // ignore: cast_nullable_to_non_nullable
as bool,isUploading: null == isUploading ? _self.isUploading : isUploading // ignore: cast_nullable_to_non_nullable
as bool,pendingBytes: freezed == pendingBytes ? _self.pendingBytes : pendingBytes // ignore: cast_nullable_to_non_nullable
as Uint8List?,lastErrorMessage: freezed == lastErrorMessage ? _self.lastErrorMessage : lastErrorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
