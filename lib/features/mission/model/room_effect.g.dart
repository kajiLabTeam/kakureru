// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_effect.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoomEffect _$RoomEffectFromJson(Map<String, dynamic> json) => _RoomEffect(
  id: json['id'] as String,
  type: $enumDecode(_$RewardTypeEnumMap, json['type']),
  byUid: json['byUid'] as String,
  startedAt: (json['startedAt'] as num).toInt(),
  durationMs: (json['durationMs'] as num).toInt(),
  skipSlot: (json['skipSlot'] as num?)?.toInt(),
);

Map<String, dynamic> _$RoomEffectToJson(_RoomEffect instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$RewardTypeEnumMap[instance.type]!,
      'byUid': instance.byUid,
      'startedAt': instance.startedAt,
      'durationMs': instance.durationMs,
      'skipSlot': instance.skipSlot,
    };

const _$RewardTypeEnumMap = {
  RewardType.blockClues: 'block_clues',
  RewardType.bigDemonIcon: 'big_demon_icon',
  RewardType.skipFootPhoto: 'skip_foot_photo',
  RewardType.enlargeSelfIcon: 'enlarge_self_icon',
};
