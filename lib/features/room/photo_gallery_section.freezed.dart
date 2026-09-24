// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'photo_gallery_section.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PhotoGallerySection {

 int get slotIndex; List<RoomPhoto> get photos;
/// Create a copy of PhotoGallerySection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PhotoGallerySectionCopyWith<PhotoGallerySection> get copyWith => _$PhotoGallerySectionCopyWithImpl<PhotoGallerySection>(this as PhotoGallerySection, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PhotoGallerySection&&(identical(other.slotIndex, slotIndex) || other.slotIndex == slotIndex)&&const DeepCollectionEquality().equals(other.photos, photos));
}


@override
int get hashCode => Object.hash(runtimeType,slotIndex,const DeepCollectionEquality().hash(photos));

@override
String toString() {
  return 'PhotoGallerySection(slotIndex: $slotIndex, photos: $photos)';
}


}

/// @nodoc
abstract mixin class $PhotoGallerySectionCopyWith<$Res>  {
  factory $PhotoGallerySectionCopyWith(PhotoGallerySection value, $Res Function(PhotoGallerySection) _then) = _$PhotoGallerySectionCopyWithImpl;
@useResult
$Res call({
 int slotIndex, List<RoomPhoto> photos
});




}
/// @nodoc
class _$PhotoGallerySectionCopyWithImpl<$Res>
    implements $PhotoGallerySectionCopyWith<$Res> {
  _$PhotoGallerySectionCopyWithImpl(this._self, this._then);

  final PhotoGallerySection _self;
  final $Res Function(PhotoGallerySection) _then;

/// Create a copy of PhotoGallerySection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? slotIndex = null,Object? photos = null,}) {
  return _then(_self.copyWith(
slotIndex: null == slotIndex ? _self.slotIndex : slotIndex // ignore: cast_nullable_to_non_nullable
as int,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<RoomPhoto>,
  ));
}

}


/// Adds pattern-matching-related methods to [PhotoGallerySection].
extension PhotoGallerySectionPatterns on PhotoGallerySection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PhotoGallerySection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PhotoGallerySection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PhotoGallerySection value)  $default,){
final _that = this;
switch (_that) {
case _PhotoGallerySection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PhotoGallerySection value)?  $default,){
final _that = this;
switch (_that) {
case _PhotoGallerySection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int slotIndex,  List<RoomPhoto> photos)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PhotoGallerySection() when $default != null:
return $default(_that.slotIndex,_that.photos);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int slotIndex,  List<RoomPhoto> photos)  $default,) {final _that = this;
switch (_that) {
case _PhotoGallerySection():
return $default(_that.slotIndex,_that.photos);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int slotIndex,  List<RoomPhoto> photos)?  $default,) {final _that = this;
switch (_that) {
case _PhotoGallerySection() when $default != null:
return $default(_that.slotIndex,_that.photos);case _:
  return null;

}
}

}

/// @nodoc


class _PhotoGallerySection implements PhotoGallerySection {
  const _PhotoGallerySection({required this.slotIndex, required final  List<RoomPhoto> photos}): _photos = photos;
  

@override final  int slotIndex;
 final  List<RoomPhoto> _photos;
@override List<RoomPhoto> get photos {
  if (_photos is EqualUnmodifiableListView) return _photos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_photos);
}


/// Create a copy of PhotoGallerySection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PhotoGallerySectionCopyWith<_PhotoGallerySection> get copyWith => __$PhotoGallerySectionCopyWithImpl<_PhotoGallerySection>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PhotoGallerySection&&(identical(other.slotIndex, slotIndex) || other.slotIndex == slotIndex)&&const DeepCollectionEquality().equals(other._photos, _photos));
}


@override
int get hashCode => Object.hash(runtimeType,slotIndex,const DeepCollectionEquality().hash(_photos));

@override
String toString() {
  return 'PhotoGallerySection(slotIndex: $slotIndex, photos: $photos)';
}


}

/// @nodoc
abstract mixin class _$PhotoGallerySectionCopyWith<$Res> implements $PhotoGallerySectionCopyWith<$Res> {
  factory _$PhotoGallerySectionCopyWith(_PhotoGallerySection value, $Res Function(_PhotoGallerySection) _then) = __$PhotoGallerySectionCopyWithImpl;
@override @useResult
$Res call({
 int slotIndex, List<RoomPhoto> photos
});




}
/// @nodoc
class __$PhotoGallerySectionCopyWithImpl<$Res>
    implements _$PhotoGallerySectionCopyWith<$Res> {
  __$PhotoGallerySectionCopyWithImpl(this._self, this._then);

  final _PhotoGallerySection _self;
  final $Res Function(_PhotoGallerySection) _then;

/// Create a copy of PhotoGallerySection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? slotIndex = null,Object? photos = null,}) {
  return _then(_PhotoGallerySection(
slotIndex: null == slotIndex ? _self.slotIndex : slotIndex // ignore: cast_nullable_to_non_nullable
as int,photos: null == photos ? _self._photos : photos // ignore: cast_nullable_to_non_nullable
as List<RoomPhoto>,
  ));
}


}

// dart format on
