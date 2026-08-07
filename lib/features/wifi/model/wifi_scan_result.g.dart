// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wifi_scan_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WifiScanResult _$WifiScanResultFromJson(Map<String, dynamic> json) =>
    _WifiScanResult(
      bssidRssi:
          (json['bssidRssi'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
      scannedAt: (json['scannedAt'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$WifiScanResultToJson(_WifiScanResult instance) =>
    <String, dynamic>{
      'bssidRssi': instance.bssidRssi,
      'scannedAt': instance.scannedAt,
    };
