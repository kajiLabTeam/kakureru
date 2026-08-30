import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';

part 'room_user.freezed.dart';
part 'room_user.g.dart';

enum UserRole {
  @JsonValue('FUGITIVE')
  fugitive,
  @JsonValue('DEMON')
  demon,
}

@freezed
abstract class RoomUser with _$RoomUser {
  const factory RoomUser({
    required String id,
    @Default('') String displayName,
    @Default('') String deviceId,
    @Default(false) bool isHost,
    @Default(UserRole.fugitive)
    @JsonKey(unknownEnumValue: UserRole.fugitive)
    UserRole role,
    double? pressureOffset,
    bool? pressureSensorAvailable,
    int? becameDemonAt,
    int? lastPhotoAt,
    @Default(0) int joinedAt,
  }) = _RoomUser;

  const RoomUser._();

  factory RoomUser.fromJson(Map<String, dynamic> json) =>
      _$RoomUserFromJson(json);

  /// RTDBの `users/{uid}` は uid がパスのキーであり値の中には無いため、
  /// 呼び出し側から id を別途渡して合成する。
  factory RoomUser.fromMap(String id, Map<dynamic, dynamic> raw) =>
      RoomUser.fromJson({...rtdbMapToJson(raw), 'id': id});

  /// id はパスのキーに現れるため、値としては書き込まない。
  Map<String, dynamic> toMap() {
    final json = toJson();
    json.remove('id');
    return json;
  }
}
