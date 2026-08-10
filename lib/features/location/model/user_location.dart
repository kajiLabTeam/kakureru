import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';
import 'package:kakureru/features/wifi/model/wifi_scan_result.dart';

part 'user_location.freezed.dart';
part 'user_location.g.dart';

@freezed
abstract class UserLocation with _$UserLocation {
  const factory UserLocation({
    required String uid,
    @JsonKey(name: 'lat') required double latitude,
    @JsonKey(name: 'lng') required double longitude,
    double? altitude,
    double? pressure,
    WifiScanResult? wifiScan,
    @Default(0) int updatedAt,
  }) = _UserLocation;

  const UserLocation._();

  factory UserLocation.fromJson(Map<String, dynamic> json) => _$UserLocationFromJson(json);

  /// RTDBの locations/{uid} は uid がパスのキーであり値の中には無いため、
  /// 呼び出し側から uid を別途渡して合成する(RoomUser.fromMapと同じ理由)。
  factory UserLocation.fromMap(String uid, Map<dynamic, dynamic> raw) =>
      UserLocation.fromJson({...rtdbMapToJson(raw), 'uid': uid});

  /// uid はパスのキーに現れるため、書き込み対象には含めない。
  Map<String, dynamic> toMap() {
    final json = toJson();
    json.remove('uid');
    return json;
  }
}
