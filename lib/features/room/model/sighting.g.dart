// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sighting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Sighting _$SightingFromJson(Map<String, dynamic> json) => _Sighting(
  id: json['id'] as String,
  uid: json['uid'] as String,
  takenAt: (json['takenAt'] as num).toInt(),
  place: json['place'] as String?,
);

Map<String, dynamic> _$SightingToJson(_Sighting instance) => <String, dynamic>{
  'id': instance.id,
  'uid': instance.uid,
  'takenAt': instance.takenAt,
  'place': instance.place,
};
