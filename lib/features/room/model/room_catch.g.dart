// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_catch.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoomCatch _$RoomCatchFromJson(Map<String, dynamic> json) => _RoomCatch(
  id: json['id'] as String,
  demonUserId: json['demonUserId'] as String?,
  fugitiveUserId: json['fugitiveUserId'] as String,
  caughtAt: (json['caughtAt'] as num).toInt(),
  catchPhotoId: json['catchPhotoId'] as String?,
);

Map<String, dynamic> _$RoomCatchToJson(_RoomCatch instance) =>
    <String, dynamic>{
      'id': instance.id,
      'demonUserId': instance.demonUserId,
      'fugitiveUserId': instance.fugitiveUserId,
      'caughtAt': instance.caughtAt,
      'catchPhotoId': instance.catchPhotoId,
    };
