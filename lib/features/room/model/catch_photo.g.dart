// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catch_photo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CatchPhoto _$CatchPhotoFromJson(Map<String, dynamic> json) => _CatchPhoto(
  id: json['id'] as String,
  catchId: json['catchId'] as String,
  demonUid: json['demonUid'] as String,
  fugitiveUid: json['fugitiveUid'] as String,
  takenAt: (json['takenAt'] as num).toInt(),
);

Map<String, dynamic> _$CatchPhotoToJson(_CatchPhoto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'catchId': instance.catchId,
      'demonUid': instance.demonUid,
      'fugitiveUid': instance.fugitiveUid,
      'takenAt': instance.takenAt,
    };
