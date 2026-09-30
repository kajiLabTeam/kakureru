import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';

part 'wifi_scan_result.freezed.dart';
part 'wifi_scan_result.g.dart';

@freezed
abstract class WifiScanResult with _$WifiScanResult {
  const factory WifiScanResult({
    @Default({}) Map<String, int> bssidRssi,
    @Default(0) int scannedAt,

    /// 送信者がテザリングでつないでいる自分のホットスポットのBSSID。
    /// 待機画面で「テザリングで接続している」をONにした人だけが書く
    /// (issue #142)。人と一緒に動くAPなので、全員の近接判定から除く。
    String? hotspotBssid,
  }) = _WifiScanResult;

  const WifiScanResult._();

  factory WifiScanResult.fromJson(Map<String, dynamic> json) =>
      _$WifiScanResultFromJson(json);

  factory WifiScanResult.fromMap(Map<dynamic, dynamic> raw) =>
      WifiScanResult.fromJson(rtdbMapToJson(raw));

  Map<String, dynamic> toMap() => toJson();
}
