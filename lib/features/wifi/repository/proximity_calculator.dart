import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_ap_comparison.dart';

/// Wi-Fi近接判定に使う閾値。
class ProximityThresholds {
  const ProximityThresholds._();

  /// これ未満のRSSI(dBm)のAPは弱すぎるとみなし、判定対象から除外する。
  static const weakSignalCutoffDbm = -80;

  /// RSSI差の計算時、これを超える差(dBm)は外れ値として除外する。
  static const rssiDiffOutlierThresholdDbm = 20;

  /// 共通APがこれ未満なら判定に使えるデータが足りないとみなす。
  static const minCommonApCount = 3;

  /// Jaccard係数がこれ未満なら「検知なし」。
  static const jaccardNotDetectedThreshold = 0.35;

  /// Jaccard係数がこれ以上、かつRSSI差平均が[rssiDiffCloseThresholdDbm]未満
  /// なら「近い」。
  static const jaccardCloseThreshold = 0.50;

  /// 「近い」と判定するためのRSSI差平均(dBm)の上限。
  static const rssiDiffCloseThresholdDbm = 8;
}

/// [ProximityThresholds.weakSignalCutoffDbm]未満のAPを除外したマップを返す。
Map<String, int> filterWeakSignals(Map<String, int> bssidRssi) {
  return Map.fromEntries(
    bssidRssi.entries.where(
      (e) => e.value >= ProximityThresholds.weakSignalCutoffDbm,
    ),
  );
}

/// Jaccard係数(共通BSSID数 / 2人合わせた全BSSID数)を計算する。
double calculateJaccardIndex(Map<String, int> a, Map<String, int> b) {
  final setA = a.keys.toSet();
  final setB = b.keys.toSet();
  final union = setA.union(setB);
  if (union.isEmpty) return 0;
  final intersection = setA.intersection(setB);
  return intersection.length / union.length;
}

/// 共通BSSIDにおけるRSSI差の平均(dBm)を計算する。
/// [ProximityThresholds.rssiDiffOutlierThresholdDbm]を超える差は外れ値として除外する。
double? calculateAverageRssiDiff(Map<String, int> a, Map<String, int> b) {
  final common = a.keys.toSet().intersection(b.keys.toSet());
  final diffs = <int>[];
  for (final bssid in common) {
    final diff = (a[bssid]! - b[bssid]!).abs();
    if (diff > ProximityThresholds.rssiDiffOutlierThresholdDbm) continue;
    diffs.add(diff);
  }
  if (diffs.isEmpty) return null;
  return diffs.reduce((x, y) => x + y) / diffs.length;
}

/// RSSIが強い順に上位[count]件を選ぶ(RTDBへの送信データを絞るため)。
Map<String, int> selectTopAccessPoints(
  Map<String, int> bssidRssi, {
  int count = 20,
}) {
  final sorted = bssidRssi.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value)); // RSSIが強い順
  return Map.fromEntries(sorted.take(count));
}

/// 既に計算済みの指標から近接度を判定する。[calculateProximity]の中身を
/// 切り出したもの(実測値をそのままテストしやすくするため)。
///
/// 判定順序(いずれかに該当したら確定):
/// 1. 共通AP数 < [ProximityThresholds.minCommonApCount] → notDetected
/// 2. Jaccard係数 < [ProximityThresholds.jaccardNotDetectedThreshold] → notDetected
/// 3. Jaccard係数 >= [ProximityThresholds.jaccardCloseThreshold] かつ
///    RSSI差平均 < [ProximityThresholds.rssiDiffCloseThresholdDbm] → close
/// 4. それ以外 → far
ProximityLevel classifyProximity({
  required int commonApCount,
  required double jaccardIndex,
  required double? averageRssiDiffDbm,
}) {
  if (commonApCount < ProximityThresholds.minCommonApCount) {
    return ProximityLevel.notDetected;
  }
  if (jaccardIndex < ProximityThresholds.jaccardNotDetectedThreshold) {
    return ProximityLevel.notDetected;
  }
  if (jaccardIndex >= ProximityThresholds.jaccardCloseThreshold &&
      averageRssiDiffDbm != null &&
      averageRssiDiffDbm < ProximityThresholds.rssiDiffCloseThresholdDbm) {
    return ProximityLevel.close;
  }
  return ProximityLevel.far;
}

/// 2人分のWi-Fiスキャン結果(BSSID→RSSI)から近接度を判定する。
ProximityLevel calculateProximity(
  Map<String, int> selfBssidRssi,
  Map<String, int> targetBssidRssi,
) {
  final selfFiltered = filterWeakSignals(selfBssidRssi);
  final targetFiltered = filterWeakSignals(targetBssidRssi);

  final commonCount = selfFiltered.keys
      .toSet()
      .intersection(targetFiltered.keys.toSet())
      .length;
  final jaccard = calculateJaccardIndex(selfFiltered, targetFiltered);
  final avgRssiDiff = calculateAverageRssiDiff(selfFiltered, targetFiltered);

  return classifyProximity(
    commonApCount: commonCount,
    jaccardIndex: jaccard,
    averageRssiDiffDbm: avgRssiDiff,
  );
}

/// 共通して見えているAPのうち、自分と相手のRSSI平均が強い順に上位[count]件を選ぶ
List<WifiApComparison> selectTopCommonAccessPoints(
  Map<String, int> selfBssidRssi,
  Map<String, int> targetBssidRssi, {
  int count = 3,
}) {
  final selfFiltered = filterWeakSignals(selfBssidRssi);
  final targetFiltered = filterWeakSignals(targetBssidRssi);
  final common = selfFiltered.keys.toSet().intersection(
    targetFiltered.keys.toSet(),
  );

  final comparisons = common
      .map(
        (bssid) => WifiApComparison(
          bssid: bssid,
          selfRssi: selfFiltered[bssid]!,
          targetRssi: targetFiltered[bssid]!,
        ),
      )
      .toList();

  comparisons.sort((a, b) {
    final avgA = (a.selfRssi + a.targetRssi) / 2;
    final avgB = (b.selfRssi + b.targetRssi) / 2;
    return avgB.compareTo(avgA); // 平均RSSIが強い順
  });

  return comparisons.take(count).toList();
}

/// ヒステリシスの猶予時間。この時間内に一度でも近接検知(close/far)できて
/// いれば、直後の1回が閾値割れでnotDetectedになっても直前の判定を保持する。
/// Wi-Fiスキャンは端末ごとに非同期・約25秒間隔で行われRSSIも揺らぐため、
/// 1回分のノイズを吸収できるよう間隔よりやや長めに取っている(issue #8)。
const proximityHysteresisGraceDuration = Duration(seconds: 45);

/// 今回の生の判定がnotDetectedだった場合に、実際に表示する判定を決める。
///
/// Wi-Fiスキャンは端末間で非同期・約25秒間隔のため、RSSIの揺らぎで境界付近の
/// APが出入りするだけで一瞬notDetectedへ振れることがある(issue #8 追加調査:
/// 「近いのに検知なしになる」)。直近[graceDuration]以内に近接検知できていた
/// 場合は、今回notDetectedでも直前の判定をそのまま返す。
///
/// 呼び出し側は「生の判定がnotDetectedのときだけ」この関数を呼ぶ想定
/// (生の判定がclose/farならそのまま使い、[lastGoodAt]をその時刻で更新する)。
ProximityLevel applyProximityHysteresis({
  required ProximityLevel? lastDisplayedLevel,
  required DateTime? lastGoodAt,
  required DateTime now,
  Duration graceDuration = proximityHysteresisGraceDuration,
}) {
  if (lastDisplayedLevel == null ||
      lastDisplayedLevel == ProximityLevel.notDetected) {
    return ProximityLevel.notDetected;
  }
  if (lastGoodAt == null) return ProximityLevel.notDetected;
  if (now.difference(lastGoodAt) <= graceDuration) return lastDisplayedLevel;
  return ProximityLevel.notDetected;
}

/// [findNearestUid]の今回の結果がnullだった場合に、実際に表示するuidを決める。
/// 考え方は[applyProximityHysteresis]と同じ。
///
/// 呼び出し側は「今回の[findNearestUid]がnullのときだけ」この関数を呼ぶ想定。
String? applyNearestUidHysteresis({
  required String? lastUid,
  required DateTime? lastFoundAt,
  required DateTime now,
  Duration graceDuration = proximityHysteresisGraceDuration,
}) {
  if (lastUid == null || lastFoundAt == null) return null;
  if (now.difference(lastFoundAt) <= graceDuration) return lastUid;
  return null;
}

/// 複数の候補の中から、自分に最も近い1人のuidを選ぶ。
///
/// 「最も近い」= 共通APのRSSI差平均が最小。共通APが
/// [ProximityThresholds.minCommonApCount]未満の候補は除外する。
/// 該当者がいなければnull。
String? findNearestUid(
  Map<String, int> selfBssidRssi,
  Map<String, Map<String, int>> candidateBssidRssiByUid,
) {
  final selfFiltered = filterWeakSignals(selfBssidRssi);
  String? bestUid;
  double? bestDiff;

  for (final entry in candidateBssidRssiByUid.entries) {
    final targetFiltered = filterWeakSignals(entry.value);
    final commonCount = selfFiltered.keys
        .toSet()
        .intersection(targetFiltered.keys.toSet())
        .length;
    if (commonCount < ProximityThresholds.minCommonApCount) continue;

    final diff = calculateAverageRssiDiff(selfFiltered, targetFiltered);
    if (diff == null) continue;

    if (bestDiff == null || diff < bestDiff) {
      bestDiff = diff;
      bestUid = entry.key;
    }
  }
  return bestUid;
}
