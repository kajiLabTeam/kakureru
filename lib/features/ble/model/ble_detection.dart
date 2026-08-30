import 'package:freezed_annotation/freezed_annotation.dart';

part 'ble_detection.freezed.dart';

/// BLEスキャンで検知した相手1台分の直近の状態。
///
/// RTDBへは送らない(Wi-Fiと違い、相手の広告を直接受信できるため参加者間の
/// 共有が不要)。端末内だけで完結する一時的な検知結果。
@freezed
abstract class BleDetection with _$BleDetection {
  const factory BleDetection({
    required String shortUid,
    required int rssiDbm,
    required int detectedAtMillis,
  }) = _BleDetection;
}
