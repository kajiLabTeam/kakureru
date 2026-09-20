import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';

part 'room_setting.freezed.dart';
part 'room_setting.g.dart';

@freezed
abstract class LatLng with _$LatLng {
  const factory LatLng({required double lat, required double lng}) = _LatLng;

  factory LatLng.fromJson(Map<String, dynamic> json) => _$LatLngFromJson(json);
}

@freezed
abstract class RoomSetting with _$RoomSetting {
  const factory RoomSetting({
    @Default([]) List<LatLng> gameArea,
    @Default(60) int releaseWaitSec,
    @Default(1800) int gameDurationSec,
    @Default(300) int photoIntervalSec,
    @Default(60) int fugitiveInfoDelaySec,
    @Default(50) int senseDistanceRadiusM,
    int? updatedAt,
  }) = _RoomSetting;

  const RoomSetting._();

  factory RoomSetting.fromJson(Map<String, dynamic> json) => _$RoomSettingFromJson(json);

  factory RoomSetting.fromMap(Map<dynamic, dynamic> raw) =>
      RoomSetting.fromJson(rtdbMapToJson(raw));

  /// `updatedAt` はサーバー側(ServerValue.timestamp)で決める値なので書き込み対象に含めない。
  Map<String, dynamic> toMap() {
    final json = toJson();
    json.remove('updatedAt');
    return json;
  }
}
