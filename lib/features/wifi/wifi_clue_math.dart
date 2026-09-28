/// 手がかりカード(メーター・電波の一致・近づいた/離れた)の純粋な計算。
/// RTDBやプラグインに依存しないため、実機なしで単体テストできる。
///
/// 「近い/遠い」の**判定**は`repository/proximity_calculator.dart`の責務で、
/// ここでは変更しない。ここにあるのは、同じ指標(RSSI差の中央値・上位AP
/// 一致率)を画面用の連続値に写すためのもの。
///
/// **このファイルの係数・閾値はすべて暫定**。実機のプレイテストで
/// メーターの揺れ方・傾向の反応速度を見て調整する前提の値である。
library;

import 'package:kakureru/features/wifi/model/clue_meter_sample.dart';
import 'package:kakureru/features/wifi/model/wifi_ap_comparison.dart';
import 'package:kakureru/features/wifi/repository/proximity_calculator.dart';

/// メーターにおける距離スコア(RSSI差)の重み。暫定。
const double clueMeterDistanceWeight = 0.7;

/// メーターにおける上位AP一致率の重み。暫定。
const double clueMeterShareWeight = 0.3;

/// RSSI差の中央値がこれ以下なら距離スコアを満点(1)にする(dB)。暫定。
const double clueMeterNearDbm = 2;

/// RSSI差の中央値がこれ以上なら距離スコアを0にする(dB)。暫定。
const double clueMeterFarDbm = 14;

/// 「電波の一致」で、1つのAPを一致とみなすRSSI差の上限(dB)。暫定。
///
/// `ProximityThresholds.rssiDiffCloseThresholdDbm`(7)と同じ値に揃えている。
const int signalMatchToleranceDbm = 7;

/// 「電波の一致」で数える、共通APの上位件数。
const int signalMatchCount = 3;

/// 傾向(近づいた/離れた)を出すとき、どれだけ前の値と比べるか。暫定。
const Duration clueTrendLookback = Duration(seconds: 6);

/// 傾向を「変わらない」以外にする、メーター差の最小値(0〜100の目盛りで)。暫定。
const double clueTrendThreshold = 5;

/// 傾向の履歴を保持する期間。[clueTrendLookback]より十分長ければよい。
const Duration clueHistoryKeep = Duration(seconds: 60);

/// 既に計算済みの指標から、メーターの値(0〜100)を求める。暫定の式:
///
/// - distanceScore = clamp((14 − d) / 12, 0, 1)
///   (d = [medianRssiDiffDbm]。2dB以下で1、14dB以上で0)
/// - meter = (0.7 × distanceScore + 0.3 × [topOverlap]) × 100
double clueMeterFromMetrics({
  required double medianRssiDiffDbm,
  required double topOverlap,
}) {
  final distanceScore =
      ((clueMeterFarDbm - medianRssiDiffDbm) /
              (clueMeterFarDbm - clueMeterNearDbm))
          .clamp(0.0, 1.0);
  final shareScore = topOverlap.clamp(0.0, 1.0);
  return (clueMeterDistanceWeight * distanceScore +
          clueMeterShareWeight * shareScore) *
      100;
}

/// 自分と相手のスキャン結果からメーターの値(0〜100)を求める。
///
/// 前処理は近い/遠いの判定と同じ[prepareForProximity](物理APへの集約→
/// 弱い電波の除外)を使い、判定とメーターが別々のデータを見ないようにする。
/// 共通APが1つも無ければnull(「まだ分からない」を出す)。
double? calculateClueMeter(
  Map<String, int> selfBssidRssi,
  Map<String, int> targetBssidRssi,
) {
  final self = prepareForProximity(selfBssidRssi);
  final target = prepareForProximity(targetBssidRssi);
  final median = calculateMedianRssiDiff(self, target);
  if (median == null) return null;
  return clueMeterFromMetrics(
    medianRssiDiffDbm: median,
    topOverlap: calculateTopOverlap(self, target),
  );
}

/// 共通APの上位[count]件のうち、RSSI差が[toleranceDbm]以下のものの数。
///
/// [comparisons]は`selectTopCommonAccessPoints`の戻り値(平均RSSIが強い順)を
/// 想定している。[count]件より多く渡されても先頭[count]件だけを見る。
int countMatchingSignals(
  List<WifiApComparison> comparisons, {
  int count = signalMatchCount,
  int toleranceDbm = signalMatchToleranceDbm,
}) {
  return comparisons
      .take(count)
      .where((c) => (c.selfRssi - c.targetRssi).abs() <= toleranceDbm)
      .length;
}

/// メーターの傾向。
enum ClueTrend {
  /// メーターが上がった(相手に近づいた)。
  closer,

  /// メーターが下がった(相手から離れた)。
  farther,

  /// 変化が小さい、または比べる履歴がまだ無い。
  unchanged,
}

/// 履歴[samples](古い順)から、最新の値の傾向を求める。
///
/// 最新の値と、その値を測った時刻より[lookback]以上前の値のうち最も新しい
/// ものを比べ、[threshold]以上上がっていれば[ClueTrend.closer]、下がって
/// いれば[ClueTrend.farther]。比べる値が無いときは[ClueTrend.unchanged]。
///
/// 基準を「いま」ではなく最新の値の時刻に取るのは、スキャンが約10秒間隔で
/// しか届かないため。「いま」基準だと次のスキャンが届くまでの間に基準が
/// 最新の値自身へ移り、傾向が数秒で「変わらない」に戻ってしまう。
ClueTrend clueTrendOf(
  List<ClueMeterSample> samples, {
  Duration lookback = clueTrendLookback,
  double threshold = clueTrendThreshold,
}) {
  if (samples.isEmpty) return ClueTrend.unchanged;
  final current = samples.last;
  final cutoff = current.at.subtract(lookback);
  ClueMeterSample? reference;
  for (final sample in samples.reversed) {
    if (!sample.at.isAfter(cutoff)) {
      reference = sample;
      break;
    }
  }
  if (reference == null) return ClueTrend.unchanged;
  final delta = current.meter - reference.meter;
  if (delta >= threshold) return ClueTrend.closer;
  if (delta <= -threshold) return ClueTrend.farther;
  return ClueTrend.unchanged;
}

/// 履歴[samples](古い順)の末尾に[sample]を足し、[keep]より古いものを捨てる。
///
/// 捨てた結果`lookback`より前の値が1件も残らないと傾向が出せなくなるため、
/// [keep]より古いものでも、残る中で最も新しい1件だけは基準として残す。
List<ClueMeterSample> appendClueSample(
  List<ClueMeterSample> samples,
  ClueMeterSample sample, {
  Duration keep = clueHistoryKeep,
}) {
  final cutoff = sample.at.subtract(keep);
  final all = [...samples, sample];
  final firstKept = all.indexWhere((s) => !s.at.isBefore(cutoff));
  // firstKeptは末尾(sample自身)で必ず見つかる。その直前の1件は基準用に残す。
  final start = firstKept > 0 ? firstKept - 1 : 0;
  return all.sublist(start);
}
