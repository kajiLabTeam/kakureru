// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_setting.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LatLng _$LatLngFromJson(Map<String, dynamic> json) => _LatLng(
  lat: (json['lat'] as num).toDouble(),
  lng: (json['lng'] as num).toDouble(),
);

Map<String, dynamic> _$LatLngToJson(_LatLng instance) => <String, dynamic>{
  'lat': instance.lat,
  'lng': instance.lng,
};

_RoomSetting _$RoomSettingFromJson(Map<String, dynamic> json) => _RoomSetting(
  gameArea:
      (json['gameArea'] as List<dynamic>?)
          ?.map((e) => LatLng.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  releaseWaitSec: (json['releaseWaitSec'] as num?)?.toInt() ?? 60,
  gameDurationSec: (json['gameDurationSec'] as num?)?.toInt() ?? 1800,
  photoIntervalSec: (json['photoIntervalSec'] as num?)?.toInt() ?? 300,
  fugitiveInfoDelaySec: (json['fugitiveInfoDelaySec'] as num?)?.toInt() ?? 60,
  senseDistanceRadiusM: (json['senseDistanceRadiusM'] as num?)?.toInt() ?? 50,
  updatedAt: (json['updatedAt'] as num?)?.toInt(),
);

Map<String, dynamic> _$RoomSettingToJson(_RoomSetting instance) =>
    <String, dynamic>{
      'gameArea': instance.gameArea.map((e) => e.toJson()).toList(),
      'releaseWaitSec': instance.releaseWaitSec,
      'gameDurationSec': instance.gameDurationSec,
      'photoIntervalSec': instance.photoIntervalSec,
      'fugitiveInfoDelaySec': instance.fugitiveInfoDelaySec,
      'senseDistanceRadiusM': instance.senseDistanceRadiusM,
      'updatedAt': instance.updatedAt,
    };
