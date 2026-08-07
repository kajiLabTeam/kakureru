import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/core/utils/rtdb_map.dart';

part 'wifi_scan_result.freezed.dart';
part 'wifi_scan_result.g.dart';

@freezed
abstract class WifiScanResult with _$WifiScanResult {
  const factory WifiScanResult({
    @Default({}) Map<String, int> bssidRssi,
    @Default(0) int scannedAt,
  }) = _WifiScanResult;

  const WifiScanResult._();

  factory WifiScanResult.fromJson(Map<String, dynamic> json) => _$WifiScanResultFromJson(json);

  /// RTDBの `Map<dynamic, dynamic>` から組み立てる。
  factory WifiScanResult.fromMap(Map<dynamic, dynamic> raw) =>
      WifiScanResult.fromJson(rtdbMapToJson(raw));

  Map<String, dynamic> toMap() => toJson();
}
