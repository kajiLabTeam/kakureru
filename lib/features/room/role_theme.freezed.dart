// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'role_theme.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RoleTheme {

 Color get color; String get label; IconData get icon;
/// Create a copy of RoleTheme
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoleThemeCopyWith<RoleTheme> get copyWith => _$RoleThemeCopyWithImpl<RoleTheme>(this as RoleTheme, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoleTheme&&(identical(other.color, color) || other.color == color)&&(identical(other.label, label) || other.label == label)&&(identical(other.icon, icon) || other.icon == icon));
}


@override
int get hashCode => Object.hash(runtimeType,color,label,icon);

@override
String toString() {
  return 'RoleTheme(color: $color, label: $label, icon: $icon)';
}


}

/// @nodoc
abstract mixin class $RoleThemeCopyWith<$Res>  {
  factory $RoleThemeCopyWith(RoleTheme value, $Res Function(RoleTheme) _then) = _$RoleThemeCopyWithImpl;
@useResult
$Res call({
 Color color, String label, IconData icon
});




}
/// @nodoc
class _$RoleThemeCopyWithImpl<$Res>
    implements $RoleThemeCopyWith<$Res> {
  _$RoleThemeCopyWithImpl(this._self, this._then);

  final RoleTheme _self;
  final $Res Function(RoleTheme) _then;

/// Create a copy of RoleTheme
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? color = null,Object? label = null,Object? icon = null,}) {
  return _then(_self.copyWith(
color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as Color,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as IconData,
  ));
}

}


/// Adds pattern-matching-related methods to [RoleTheme].
extension RoleThemePatterns on RoleTheme {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoleTheme value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoleTheme() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoleTheme value)  $default,){
final _that = this;
switch (_that) {
case _RoleTheme():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoleTheme value)?  $default,){
final _that = this;
switch (_that) {
case _RoleTheme() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Color color,  String label,  IconData icon)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoleTheme() when $default != null:
return $default(_that.color,_that.label,_that.icon);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Color color,  String label,  IconData icon)  $default,) {final _that = this;
switch (_that) {
case _RoleTheme():
return $default(_that.color,_that.label,_that.icon);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Color color,  String label,  IconData icon)?  $default,) {final _that = this;
switch (_that) {
case _RoleTheme() when $default != null:
return $default(_that.color,_that.label,_that.icon);case _:
  return null;

}
}

}

/// @nodoc


class _RoleTheme implements RoleTheme {
  const _RoleTheme({required this.color, required this.label, required this.icon});
  

@override final  Color color;
@override final  String label;
@override final  IconData icon;

/// Create a copy of RoleTheme
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoleThemeCopyWith<_RoleTheme> get copyWith => __$RoleThemeCopyWithImpl<_RoleTheme>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoleTheme&&(identical(other.color, color) || other.color == color)&&(identical(other.label, label) || other.label == label)&&(identical(other.icon, icon) || other.icon == icon));
}


@override
int get hashCode => Object.hash(runtimeType,color,label,icon);

@override
String toString() {
  return 'RoleTheme(color: $color, label: $label, icon: $icon)';
}


}

/// @nodoc
abstract mixin class _$RoleThemeCopyWith<$Res> implements $RoleThemeCopyWith<$Res> {
  factory _$RoleThemeCopyWith(_RoleTheme value, $Res Function(_RoleTheme) _then) = __$RoleThemeCopyWithImpl;
@override @useResult
$Res call({
 Color color, String label, IconData icon
});




}
/// @nodoc
class __$RoleThemeCopyWithImpl<$Res>
    implements _$RoleThemeCopyWith<$Res> {
  __$RoleThemeCopyWithImpl(this._self, this._then);

  final _RoleTheme _self;
  final $Res Function(_RoleTheme) _then;

/// Create a copy of RoleTheme
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? color = null,Object? label = null,Object? icon = null,}) {
  return _then(_RoleTheme(
color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as Color,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,icon: null == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as IconData,
  ));
}


}

// dart format on
