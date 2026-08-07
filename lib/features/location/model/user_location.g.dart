// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_location.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserLocation _$UserLocationFromJson(Map<String, dynamic> json) =>
    _UserLocation(
      uid: json['uid'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      pressure: (json['pressure'] as num?)?.toDouble(),
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$UserLocationToJson(_UserLocation instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'lat': instance.latitude,
      'lng': instance.longitude,
      'altitude': instance.altitude,
      'pressure': instance.pressure,
      'updatedAt': instance.updatedAt,
    };
