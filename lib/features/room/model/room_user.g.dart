// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoomUser _$RoomUserFromJson(Map<String, dynamic> json) => _RoomUser(
  id: json['id'] as String,
  displayName: json['displayName'] as String? ?? '',
  deviceId: json['deviceId'] as String? ?? '',
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
  becameDemonAt: (json['becameDemonAt'] as num?)?.toInt(),
  lastPhotoAt: (json['lastPhotoAt'] as num?)?.toInt(),
  joinedAt: (json['joinedAt'] as num?)?.toInt() ?? 0,
  leftAt: (json['leftAt'] as num?)?.toInt(),
);

Map<String, dynamic> _$RoomUserToJson(_RoomUser instance) => <String, dynamic>{
  'id': instance.id,
  'displayName': instance.displayName,
  'deviceId': instance.deviceId,
  'isHost': instance.isHost,
  'role': _$UserRoleEnumMap[instance.role]!,
  'pressureOffset': instance.pressureOffset,
  'pressureSensorAvailable': instance.pressureSensorAvailable,
  'becameDemonAt': instance.becameDemonAt,
  'lastPhotoAt': instance.lastPhotoAt,
  'joinedAt': instance.joinedAt,
  'leftAt': instance.leftAt,
};

const _$UserRoleEnumMap = {
  UserRole.fugitive: 'FUGITIVE',
  UserRole.demon: 'DEMON',
};
