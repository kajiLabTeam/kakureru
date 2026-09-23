// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_photo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoomPhoto _$RoomPhotoFromJson(Map<String, dynamic> json) => _RoomPhoto(
  id: json['id'] as String,
  uid: json['uid'] as String,
  takenAt: (json['takenAt'] as num).toInt(),
);

Map<String, dynamic> _$RoomPhotoToJson(_RoomPhoto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'uid': instance.uid,
      'takenAt': instance.takenAt,
    };
