// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoomUser _$RoomUserFromJson(Map<String, dynamic> json) => _RoomUser(
  id: json['id'] as String,
  displayName: json['displayName'] as String? ?? '',
  isHost: json['isHost'] as bool? ?? false,
  role:
      $enumDecodeNullable(
        _$UserRoleEnumMap,
        json['role'],
        unknownValue: UserRole.fugitive,
      ) ??
      UserRole.fugitive,
  pressureOffset: (json['pressureOffset'] as num?)?.toDouble(),
  pressureSensorAvailable: json['pressureSensorAvailable'] as bool?,
  usesTethering: json['usesTethering'] as bool?,
  becameDemonAt: (json['becameDemonAt'] as num?)?.toInt(),
  lastPhotoAt: (json['lastPhotoAt'] as num?)?.toInt(),
  joinedAt: (json['joinedAt'] as num?)?.toInt() ?? 0,
  online: json['online'] as bool?,
  leftAt: (json['leftAt'] as num?)?.toInt(),
);

Map<String, dynamic> _$RoomUserToJson(_RoomUser instance) => <String, dynamic>{
  'id': instance.id,
  'displayName': instance.displayName,
  'isHost': instance.isHost,
  'role': _$UserRoleEnumMap[instance.role]!,
  'pressureOffset': instance.pressureOffset,
  'pressureSensorAvailable': instance.pressureSensorAvailable,
  'usesTethering': instance.usesTethering,
  'becameDemonAt': instance.becameDemonAt,
  'lastPhotoAt': instance.lastPhotoAt,
  'joinedAt': instance.joinedAt,
  'online': instance.online,
  'leftAt': instance.leftAt,
};

const _$UserRoleEnumMap = {
  UserRole.fugitive: 'FUGITIVE',
  UserRole.demon: 'DEMON',
};
