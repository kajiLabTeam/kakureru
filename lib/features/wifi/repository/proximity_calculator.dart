import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_ap_comparison.dart';

/// Wi-Fi近接判定に使う閾値。
///
/// 値は愛工大14号館での実測(2026-07-20/22)と、そのRSSIを一律22dB弱めた
/// 屋外想定のシミュレーションから決めた。経緯は
/// docs/wifi-proximity-investigation.md 9章を参照。
class ProximityThresholds {
  const ProximityThresholds._();

  /// これ未満のRSSI(dBm)のAPは弱すぎるとみなし、判定対象から除外する。
  /// 屋外では建物内のAPが壁越しに弱く見えるため、屋内向けだった-80から
  /// 下げている(-80のままだと屋外で共通APがほぼ残らない)。
  static const weakSignalCutoffDbm = -90;

  /// 共通AP(物理AP単位)がこれ未満なら判定に使えるデータが足りないとみなす。
  static const minCommonApCount = 3;

  /// 「近い」と判定するための、共通APのRSSI差の中央値(dB)の上限(この値を含む)。
  static const rssiDiffCloseThresholdDbm = 7;

  /// 「近い」と判定するための、上位AP一致率([calculateTopOverlap])の下限
  /// (この値を含む)。
  static const topOverlapCloseThreshold = 0.6;

  /// [calculateTopOverlap]で比べる上位APの件数。
  static const topOverlapCount = 5;
}

/// BSSIDを物理APごとにまとめ、各物理APのRSSIはその中の最大値にする。
///
/// 愛工大のAPは1台でeduroam / ait-wnet1x / ait-jimu / ステルスなど複数の
/// SSIDを出しており、それぞれのBSSIDは末尾1文字(16進1桁)だけが違う。
/// BSSIDのままだと1台のAPが4〜5件に水増しされ、スキャンごとにどのSSIDが
/// 拾えたかの揺らぎで共通AP数や上位APの顔ぶれが大きく変わってしまうため、
/// 末尾1文字を落とした文字列を物理APのキーとして集約する。
Map<String, int> groupByPhysicalAp(Map<String, int> bssidRssi) {
  final grouped = <String, int>{};
  for (final e in bssidRssi.entries) {
    final key = e.key.isEmpty ? e.key : e.key.substring(0, e.key.length - 1);
    final current = grouped[key];
    if (current == null || e.value > current) grouped[key] = e.value;
  }
  return grouped;
}

/// [ProximityThresholds.weakSignalCutoffDbm]未満のAPを除外したマップを返す。
Map<String, int> filterWeakSignals(Map<String, int> bssidRssi) {
  return Map.fromEntries(
    bssidRssi.entries.where(
      (e) => e.value >= ProximityThresholds.weakSignalCutoffDbm,
    ),
  );
}

/// 判定の前処理: 物理AP単位への集約([groupByPhysicalAp]) → 足切り
/// ([filterWeakSignals])。集約を先にするのは、同じAPの中で1つでも
/// 足切りを超えるSSIDがあればそのAPを残すため。
Map<String, int> prepareForProximity(Map<String, int> bssidRssi) =>
    filterWeakSignals(groupByPhysicalAp(bssidRssi));

/// 共通APにおけるRSSI差(絶対値)の中央値(dB)。共通APが無ければnull。
///
/// 以前は「20dBを超える差を外れ値として除いた平均」を使っていたが、
/// 離れているときに出る大きな差こそ「遠い」の証拠であり、それを捨てると
/// 遠い組が近く見えてしまっていた。中央値なら揺らぎによる単発の外れ値には
/// 強いまま、差が大きいAPが多数派なら素直に値が大きくなる。
double? calculateMedianRssiDiff(Map<String, int> a, Map<String, int> b) {
  final diffs = [
    for (final key in a.keys)
      if (b.containsKey(key)) (a[key]! - b[key]!).abs(),
  ]..sort();
  if (diffs.isEmpty) return null;
  final mid = diffs.length ~/ 2;
  if (diffs.length.isOdd) return diffs[mid].toDouble();
  return (diffs[mid - 1] + diffs[mid]) / 2;
}

/// 上位AP一致率: 双方のRSSI上位k件(k = min([count], |a|, |b|))のうち、
/// 両方の上位k件に入っているAPの割合(0〜1)。
///
/// 一番強く見えるAPの顔ぶれは、その場所の近くにあるAPでほぼ決まる。
/// Jaccard係数(全体の集合の重なり)はスキャンで拾えるAP数が20〜130件と
/// 大きく揺らぐと下がってしまうが、上位数件の一致は拾えた件数に左右
/// されにくい。また「APを挟んで対称な位置にいるとRSSI差だけは小さく
/// 見える」ケースも、最寄りのAPが違えばここで弾ける。
double calculateTopOverlap(
  Map<String, int> a,
  Map<String, int> b, {
  int count = ProximityThresholds.topOverlapCount,
}) {
  final k = [count, a.length, b.length].reduce((x, y) => x < y ? x : y);
  if (k <= 0) return 0;
  final topA = selectTopAccessPoints(a, count: k).keys.toSet();
  final topB = selectTopAccessPoints(b, count: k).keys.toSet();
  return topA.intersection(topB).length / k;
}

/// RSSIが強い順に上位[count]件を選ぶ(RTDBへの送信データを絞るため)。
/// 同じRSSIのものはキーの辞書順で並べ、結果が実行ごとに変わらないようにする。
Map<String, int> selectTopAccessPoints(
  Map<String, int> bssidRssi, {
  int count = 40,
}) {
  final sorted = bssidRssi.entries.toList()
    ..sort((a, b) {
      final byRssi = b.value.compareTo(a.value); // RSSIが強い順
      return byRssi != 0 ? byRssi : a.key.compareTo(b.key);
    });
  return Map.fromEntries(sorted.take(count));
}

/// 既に計算済みの指標から近接度を判定する。[calculateProximity]の中身を
/// 切り出したもの(実測値をそのままテストしやすくするため)。
///
/// 判定順序(いずれかに該当したら確定):
/// 1. 共通AP数 < [ProximityThresholds.minCommonApCount] → notDetected
/// 2. RSSI差の中央値 <= [ProximityThresholds.rssiDiffCloseThresholdDbm] かつ
///    上位AP一致率 >= [ProximityThresholds.topOverlapCloseThreshold] → close
/// 3. それ以外 → far
///
/// 2つの指標をANDで組み合わせるのは、片方だけだと誤判定が増えるため
/// (RSSI差だけ: APを挟んだ対称位置で誤って近い / 一致率だけ: 同じAPが
/// 最寄りの10〜20m圏で誤って近い)。
ProximityLevel classifyProximity({
  required int commonApCount,
  required double? medianRssiDiffDbm,
  required double topOverlap,
}) {
  if (commonApCount < ProximityThresholds.minCommonApCount) {
    return ProximityLevel.notDetected;
  }
  if (medianRssiDiffDbm != null &&
      medianRssiDiffDbm <= ProximityThresholds.rssiDiffCloseThresholdDbm &&
      topOverlap >= ProximityThresholds.topOverlapCloseThreshold) {
    return ProximityLevel.close;
  }
  return ProximityLevel.far;
}

/// 2人分のWi-Fiスキャン結果(BSSID→RSSI)から近接度を判定する。
///
/// 手順は 前処理([prepareForProximity]) → 各指標の計算 → [classifyProximity]。
ProximityLevel calculateProximity(
  Map<String, int> selfBssidRssi,
  Map<String, int> targetBssidRssi,
) {
  final self = prepareForProximity(selfBssidRssi);
  final target = prepareForProximity(targetBssidRssi);

  final commonCount = self.keys.where(target.containsKey).length;
  return classifyProximity(
    commonApCount: commonCount,
    medianRssiDiffDbm: calculateMedianRssiDiff(self, target),
    topOverlap: calculateTopOverlap(self, target),
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
/// Wi-Fiスキャンは端末ごとに非同期・約10秒間隔(`WifiScanRepository._scanInterval`。
/// issue #8対応でそれまでの約25秒間隔から短縮済み)で行われRSSIも揺らぐため、
/// 1回分のノイズを吸収できるよう間隔よりやや長めに取っている(issue #8)。
/// Androidのスキャンスロットリングで実際の更新間隔がさらに開くケースが
/// あっても、猶予はスロットリングの発生を隠す目的では設計していない点に注意
/// (issue #45調査。スロットリングでの取りこぼしはログで検知する方針)。
const proximityHysteresisGraceDuration = Duration(seconds: 45);

/// 今回の生の判定がnotDetectedだった場合に、実際に表示する判定を決める。
///
/// Wi-Fiスキャンは端末間で非同期・約10秒間隔(issue #45調査で「約25秒間隔」との
/// 記述の古さを確認し修正)のため、RSSIの揺らぎで境界付近のAPが出入りするだけで
/// 一瞬notDetectedへ振れることがある(issue #8 追加調査:「近いのに検知なしに
/// なる」)。直近[graceDuration]以内に近接検知できていた場合は、今回notDetected
/// でも直前の判定をそのまま返す。
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
/// 「最も近い」= 共通AP(物理AP単位)のRSSI差の中央値が最小。前処理は
/// [calculateProximity]と同じ[prepareForProximity]で、共通APが
/// [ProximityThresholds.minCommonApCount]未満の候補は除外する。
/// 該当者がいなければnull。
String? findNearestUid(
  Map<String, int> selfBssidRssi,
  Map<String, Map<String, int>> candidateBssidRssiByUid,
) {
  final self = prepareForProximity(selfBssidRssi);
  String? bestUid;
  double? bestDiff;

  for (final entry in candidateBssidRssiByUid.entries) {
    final target = prepareForProximity(entry.value);
    final commonCount = self.keys.where(target.containsKey).length;
    if (commonCount < ProximityThresholds.minCommonApCount) continue;

    final diff = calculateMedianRssiDiff(self, target);
    if (diff == null) continue;

    if (bestDiff == null || diff < bestDiff) {
      bestDiff = diff;
      bestUid = entry.key;
    }
  }
  return bestUid;
}
