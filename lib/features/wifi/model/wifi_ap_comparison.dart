import 'package:freezed_annotation/freezed_annotation.dart';

part 'wifi_ap_comparison.freezed.dart';

/// 表示方式B(生のRSSIバー比較)用の、1AP分の自分/相手のRSSI。
@freezed
abstract class WifiApComparison with _$WifiApComparison {
  const factory WifiApComparison({
    required String bssid,
    required int selfRssi,
    required int targetRssi,
  }) = _WifiApComparison;
}
