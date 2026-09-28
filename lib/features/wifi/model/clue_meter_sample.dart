import 'package:freezed_annotation/freezed_annotation.dart';

part 'clue_meter_sample.freezed.dart';

/// 手がかりメーターの値を、測った時刻とともに1件ぶん記録したもの。
///
/// 「近づいた/離れた」の傾向を出すための履歴に使う。端末内だけで持ち、
/// RTDBへは送らない。
@freezed
abstract class ClueMeterSample with _$ClueMeterSample {
  /// [at]に測った[meter]の値を1件ぶん作る。
  const factory ClueMeterSample({
    /// 測った時刻(端末の時計)。
    required DateTime at,

    /// 0〜100。`calculateClueMeter`の戻り値。
    required double meter,
  }) = _ClueMeterSample;
}
