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
  becameDemonAt: (json['becameDemonAt'] as num?)?.toInt(),
  lastPhotoAt: (json['lastPhotoAt'] as num?)?.toInt(),
  joinedAt: (json['joinedAt'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$RoomUserToJson(_RoomUser instance) => <String, dynamic>{
  'id': instance.id,
  'displayName': instance.displayName,
  'deviceId': instance.deviceId,
  'isHost': instance.isHost,
  'role': _$UserRoleEnumMap[instance.role]!,
  'pressureOffset': instance.pressureOffset,
  'becameDemonAt': instance.becameDemonAt,
  'lastPhotoAt': instance.lastPhotoAt,
  'joinedAt': instance.joinedAt,
};

const _$UserRoleEnumMap = {
  UserRole.fugitive: 'FUGITIVE',
  UserRole.demon: 'DEMON',
};
