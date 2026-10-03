// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Mission _$MissionFromJson(Map<String, dynamic> json) => _Mission(
  id: json['id'] as String,
  round: (json['round'] as num).toInt(),
  createdAt: (json['createdAt'] as num).toInt(),
  expiresAt: (json['expiresAt'] as num).toInt(),
  finishedAt: (json['finishedAt'] as num?)?.toInt(),
  spots:
      (json['spots'] as List<dynamic>?)
          ?.map((e) => MissionSpot.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <MissionSpot>[],
);

Map<String, dynamic> _$MissionToJson(_Mission instance) => <String, dynamic>{
  'id': instance.id,
  'round': instance.round,
  'createdAt': instance.createdAt,
  'expiresAt': instance.expiresAt,
  'finishedAt': instance.finishedAt,
  'spots': instance.spots.map((e) => e.toJson()).toList(),
};

_MissionSpot _$MissionSpotFromJson(Map<String, dynamic> json) => _MissionSpot(
  id: json['id'] as String,
  lat: (json['lat'] as num).toDouble(),
  lng: (json['lng'] as num).toDouble(),
  radiusM: (json['radiusM'] as num).toDouble(),
  claimedBy: json['claimedBy'] as String?,
  claimedAt: (json['claimedAt'] as num?)?.toInt(),
  reward: $enumDecodeNullable(
    _$RewardTypeEnumMap,
    json['reward'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
);

Map<String, dynamic> _$MissionSpotToJson(_MissionSpot instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lat': instance.lat,
      'lng': instance.lng,
      'radiusM': instance.radiusM,
      'claimedBy': instance.claimedBy,
      'claimedAt': instance.claimedAt,
      'reward': _$RewardTypeEnumMap[instance.reward],
    };

const _$RewardTypeEnumMap = {
  RewardType.blockClues: 'block_clues',
  RewardType.enlargeSelfIcon: 'enlarge_self_icon',
  RewardType.skipFootPhoto: 'skip_foot_photo',
  RewardType.miss: 'miss',
};
