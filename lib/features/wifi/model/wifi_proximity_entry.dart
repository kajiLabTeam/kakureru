import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';

part 'wifi_proximity_entry.freezed.dart';

/// 表示方式A(3段階判定)用の、参加者1人分の近接度。
@freezed
abstract class WifiProximityEntry with _$WifiProximityEntry {
  const factory WifiProximityEntry({required String uid, required ProximityLevel level}) =
      _WifiProximityEntry;
}
