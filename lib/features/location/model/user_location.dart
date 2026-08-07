import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';

part 'user_location.freezed.dart';
part 'user_location.g.dart';

@freezed
abstract class UserLocation with _$UserLocation {
  const factory UserLocation({
    required String uid,
    // RTDB側のキー名(lat/lng)はdocs/rtdb-schema.mdのスキーマに合わせ、
    // Dart側は geolocator の Position に合わせて latitude/longitude にしている。
    @JsonKey(name: 'lat') required double latitude,
    @JsonKey(name: 'lng') required double longitude,
    double? altitude,
    // 気圧センサー用に予約。現時点ではどこからも書き込まない。
    double? pressure,
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
