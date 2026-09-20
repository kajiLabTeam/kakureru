/// Wi-Fiの表示まわりの純粋な計算。RTDBやプラグインに依存しないため、
/// このファイルの関数は単体テストしやすい形にしている。
///
/// 「近い/遠い」の**判定**は`repository/proximity_calculator.dart`側の責務。
/// ここにあるのは、判定に使った生のRSSIを**画面に置く位置**へ写すためのもの。
library;

/// 距離感トラックの左端(遠い)に割り当てるRSSI(dBm)。
///
/// -90dBmは`ProximityThresholds.weakSignalCutoffDbm`(-80)よりさらに弱く、
/// 実質「ほぼ届いていない」領域。これより弱い値は左端へ丸める。
const int rssiTrackMinDbm = -90;

/// 距離感トラックの右端(近い)に割り当てるRSSI(dBm)。
///
/// -40dBmはアクセスポイントのすぐ近く。屋内で実測するとこれより強い値は
/// めったに出ないため、右端として扱う。
const int rssiTrackMaxDbm = -40;

/// RSSI(dBm)を、距離感トラック上の位置 0.0(左端=弱い)〜1.0(右端=強い)へ写す。
///
/// [rssiTrackMinDbm]〜[rssiTrackMaxDbm]の外はそれぞれ端に丸める
/// (トラックからはみ出したドットを描かないため)。
double rssiTrackFraction(int rssi) {
  const span = rssiTrackMaxDbm - rssiTrackMinDbm;
  return ((rssi - rssiTrackMinDbm) / span).clamp(0.0, 1.0);
}
