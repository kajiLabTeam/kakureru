import 'dart:math' as math;

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
  int count = 40,
}) {
  final sorted = bssidRssi.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value)); // RSSIが強い順
  return Map.fromEntries(sorted.take(count));
}

/// 判定直前に適用する「固有APのみの対称クランプ」。[bssidRssi]のうち
/// [common](両者に共通するAP)は常に残し、片側にしかないAP(固有AP)だけを
/// RSSIの強い順の上位min(自分の固有件数, [otherPrivateCount])件に絞って返す。
/// 自分・相手それぞれについて呼ぶことで、固有APの件数が揃う
/// (共通APはどちらの呼び出しでも削られない)。
///
/// なぜ必要か: [filterWeakSignals]の足切りは-80dBmという**絶対値**で行うため、
/// アンテナ利得の差・ポケットか手持ちか、といった端末差で一律に数dB弱く
/// 見える側だけが大きく削られ、足切り後の集合サイズが非対称になる。
/// サイズが非対称なままJaccard係数を取ると、共通APは増えないのに和集合だけが
/// 膨らむため係数が不当に下がる(例: |A|=40・|B|=14でBがAに完全に含まれる
/// ときJ=14/40=0.35。実際には同じ場所にいるのにfar/検知なしになる)。
///
/// 以前は件数M=min(|A|,|B|)だけで揃える`clampToSymmetricTop`相当の実装
/// だったが、実測RTDBデータで**共通APまでクランプに巻き込まれて削られ、
/// 逆にJaccard係数が悪化する**ケースが見つかった(A=5件/B=6件で、Bの
/// 最弱の共通AP1件が「Bの上位5件」から漏れて削られ、共通4件→3件、
/// Jaccard 0.571→0.429と悪化。docs/wifi-proximity-investigation.md 8章
/// 参照)。共通APは集合サイズの非対称と無関係にどちらの集合にも既に
/// 存在しているため、クランプで削る理由が無い。固有APだけをクランプ対象に
/// することで、和集合の膨らみ(=片方だけが一律に弱く見えて生まれる固有APの
/// 偏り)だけを是正し、共通APは触らない。
///
/// RSSIの強い順の上位N件という選び方は、端末ごとの**一律な**利得オフセットに
/// 対して不変(オフセットを足しても順位は変わらない)なので、利得差の正規化と
/// して機能する。判定側だけの変更であり、送信するデータ形は変えない。
Map<String, int> clampPrivateAccessPoints(
  Map<String, int> bssidRssi, {
  required Set<String> common,
  required int otherPrivateCount,
}) {
  final private = Map.fromEntries(
    bssidRssi.entries.where((e) => !common.contains(e.key)),
  );
  final clampedPrivate = selectTopAccessPoints(
    private,
    count: math.min(private.length, otherPrivateCount),
  );
  return Map.fromEntries(
    bssidRssi.entries.where(
      (e) => common.contains(e.key) || clampedPrivate.containsKey(e.key),
    ),
  );
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
///
/// 共通APが少ない環境ではJaccard係数が(AP1件の増減で)不安定になりうるが、
/// 「共通AP数が少なければRSSI差だけで判定する」という分岐は**意図的に
/// 入れていない**。APを挟んで対称な位置にいる(=離れているのにRSSI差だけ
/// 小さく見える)ケースをJaccard係数と組み合わせて弾く設計のため、RSSI差
/// 単独の判定に切り替えるとこの防御が外れる。また共通AP数はスキャンごとに
/// 揺らぐため、分岐の閾値をまたぐたびに判定ロジックそのものが切り替わり、
/// 別種のバタつきを生む。検討の経緯はdocs/wifi-proximity-investigation.md
/// 8章(8-4)を参照。
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
///
/// 手順は 足切り([filterWeakSignals]) → 固有APのみの対称クランプ
/// ([clampPrivateAccessPoints]) → 各指標の計算 → [classifyProximity]。
/// クランプを足切りの**後**に置くのが重要で、逆順(top-N絞り込みの後に
/// 絶対値の足切り)にすると足切り後のサイズが端末間で非対称になる。
ProximityLevel calculateProximity(
  Map<String, int> selfBssidRssi,
  Map<String, int> targetBssidRssi,
) {
  final selfFiltered = filterWeakSignals(selfBssidRssi);
  final targetFiltered = filterWeakSignals(targetBssidRssi);

  final common = selfFiltered.keys.toSet().intersection(
    targetFiltered.keys.toSet(),
  );
  final selfPrivateCount = selfFiltered.length - common.length;
  final targetPrivateCount = targetFiltered.length - common.length;

  final selfClamped = clampPrivateAccessPoints(
    selfFiltered,
    common: common,
    otherPrivateCount: targetPrivateCount,
  );
  final targetClamped = clampPrivateAccessPoints(
    targetFiltered,
    common: common,
    otherPrivateCount: selfPrivateCount,
  );

  final commonCount = selfClamped.keys
      .toSet()
      .intersection(targetClamped.keys.toSet())
      .length;
  final jaccard = calculateJaccardIndex(selfClamped, targetClamped);
  final avgRssiDiff = calculateAverageRssiDiff(selfClamped, targetClamped);

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
/// 「最も近い」= 共通APのRSSI差平均が最小。共通APが
/// [ProximityThresholds.minCommonApCount]未満の候補は除外する。
/// 該当者がいなければnull。
///
/// [calculateProximity]と違い[clampPrivateAccessPoints]は適用しない。ここで
/// 使う指標は共通AP(積集合)のRSSI差だけで和集合を使わないため、集合サイズの
/// 非対称でJaccard係数が下がる問題([clampPrivateAccessPoints]参照)が
/// 起きず、むしろクランプすると比較に使える共通APを減らしてしまうため。
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
