import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';
import 'package:kakureru/features/map/repository/grid_snap.dart';
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
    double? accuracy,
    // 他人に見せる用の、マスの中心に丸めた位置(grid_snap.dart)。送り出す
    // 端末が lat/lng と同じ update() で書く。旧バージョンの端末では無い。
    @JsonKey(name: 'snapLat') double? snapLatitude,
    @JsonKey(name: 'snapLng') double? snapLongitude,
    double? pressure,
    WifiScanResult? wifiScan,
    @Default(0) int updatedAt,
  }) = _UserLocation;

  const UserLocation._();

  factory UserLocation.fromJson(Map<String, dynamic> json) =>
      _$UserLocationFromJson(json);

  /// RTDBの locations/{uid} は uid がパスのキーであり値の中には無いため、
  /// 呼び出し側から uid を別途渡して合成する(RoomUser.fromMapと同じ理由)。
  factory UserLocation.fromMap(String uid, Map<dynamic, dynamic> raw) =>
      UserLocation.fromJson({...rtdbMapToJson(raw), 'uid': uid});

  /// 他人のマーカーに出す位置。丸めた値が無い(旧バージョンの端末)ときは、
  /// 生の位置を出さずに読む側でマスの中心へ丸める(ちらつき対策は無い)。
  /// 自分のマーカーや判定には使わず、[latitude]/[longitude]の生の値を使う。
  ({double lat, double lng}) get displayPoint {
    final snapLat = snapLatitude;
    final snapLng = snapLongitude;
    if (snapLat != null && snapLng != null) {
      return (lat: snapLat, lng: snapLng);
    }
    final cell = gridCellOf(latitude, longitude);
    return gridCenterOf(cell.x, cell.y);
  }

  /// uid はパスのキーに現れるため、書き込み対象には含めない。
  Map<String, dynamic> toMap() {
    final json = toJson();
    json.remove('uid');
    return json;
  }
}
