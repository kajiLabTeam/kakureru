// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mission.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Mission _$MissionFromJson(Map<String, dynamic> json) => _Mission(
  id: json['id'] as String,
  type: $enumDecode(_$MissionTypeEnumMap, json['type']),
  createdAt: (json['createdAt'] as num).toInt(),
  expiresAt: (json['expiresAt'] as num).toInt(),
  lat: (json['lat'] as num?)?.toDouble(),
  lng: (json['lng'] as num?)?.toDouble(),
  radiusM: (json['radiusM'] as num?)?.toDouble(),
  claimedBy: json['claimedBy'] as String?,
  claimedAt: (json['claimedAt'] as num?)?.toInt(),
  reward: $enumDecodeNullable(
    _$RewardTypeEnumMap,
    json['reward'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
);

Map<String, dynamic> _$MissionToJson(_Mission instance) => <String, dynamic>{
  'id': instance.id,
  'type': _$MissionTypeEnumMap[instance.type]!,
  'createdAt': instance.createdAt,
  'expiresAt': instance.expiresAt,
  'lat': instance.lat,
  'lng': instance.lng,
  'radiusM': instance.radiusM,
  'claimedBy': instance.claimedBy,
  'claimedAt': instance.claimedAt,
  'reward': _$RewardTypeEnumMap[instance.reward],
};

const _$MissionTypeEnumMap = {
  MissionType.accessPoint: 'access_point',
  MissionType.approachDemon: 'approach_demon',
};

const _$RewardTypeEnumMap = {
  RewardType.blockClues: 'block_clues',
  RewardType.bigDemonIcon: 'big_demon_icon',
  RewardType.skipFootPhoto: 'skip_foot_photo',
};
