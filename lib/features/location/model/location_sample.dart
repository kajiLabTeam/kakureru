import 'package:freezed_annotation/freezed_annotation.dart';

part 'location_sample.freezed.dart';

/// 端末で得た1回分の測位結果。RTDBへ書く前の、採用判定に使う値。
///
/// Foreground Service側のisolateからメインisolateへ渡ってきたMapを
/// `LocationUpdateFilter`に渡すための入れ物(RTDBには直接書かない)。
@freezed
abstract class LocationSample with _$LocationSample {
  /// 1回分の測位結果を作る。
  const factory LocationSample({
    required double latitude,
    required double longitude,
    double? altitude,

    /// 測位の誤差(m)。大きいほど信頼できない。
    double? accuracy,

    /// 端末が測位した時刻(エポックミリ秒)。順序の逆転を検出するのに使う。
    int? timestampMs,
  }) = _LocationSample;
}
