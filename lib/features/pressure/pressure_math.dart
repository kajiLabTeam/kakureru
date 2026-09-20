/// 気圧センサー関連の純粋な計算ロジック。RTDBやプラグインに依存しないため、
/// このファイルの関数・クラスは単体テストしやすい形にしている。

/// 直近 [windowSize] 件の単純移動平均を保持する。
///
/// 気圧センサーは瞬間的なノイズが乗りやすいため、生の値をそのまま使わず
/// 移動平均で平滑化してから使う。
class MovingAverage {
  MovingAverage({this.windowSize = 5}) : assert(windowSize > 0);

  final int windowSize;
  final List<double> _values = [];

  /// 値を1件追加し、追加後の移動平均を返す。
  double add(double value) {
    _values.add(value);
    if (_values.length > windowSize) {
      _values.removeAt(0);
    }
    return _values.reduce((a, b) => a + b) / _values.length;
  }
}

/// 気圧1hPaあたりの高さの目安(m)。設計で決まった換算係数。
const double metersPerHectoPascal = 8.3;

/// 気圧から、targetがselfよりどれだけ高い位置にいるか(m)を計算する。
///
/// 正の値ならtargetが上、負の値なら下。
/// 気圧は個体差があるため、それぞれの補正値(offset)を引いてから比較する
/// (offsetの決め方はキャリブレーション画面側の責務。ホストは0固定、
/// 参加者は「自分の気圧 - ホストの基準気圧」)。
///
/// 高度が上がると気圧は下がるため、
/// (自分の補正後気圧 - 相手の補正後気圧) がそのまま
/// 「相手が自分よりどれだけ上にいるか」の気圧差(hPa)になる
/// (自分の気圧の方が高い = 自分の方が低い所にいる = 相手は上)。
double calculateRelativeHeightMeters({
  required double selfPressureHPa,
  required double selfOffsetHPa,
  required double targetPressureHPa,
  required double targetOffsetHPa,
}) {
  final selfAdjusted = selfPressureHPa - selfOffsetHPa;
  final targetAdjusted = targetPressureHPa - targetOffsetHPa;
  return (selfAdjusted - targetAdjusted) * metersPerHectoPascal;
}

/// 上下バー内でのドット位置を、deltaMetersから0.0(下端)〜1.0(上端)で返す。
///
/// [rangeMeters] を超える差はクランプされる。deltaMetersが正(相手が上)
/// ほど戻り値が大きくなる。
double verticalDotFraction(double deltaMeters, {double rangeMeters = 20}) {
  final clamped = deltaMeters.clamp(-rangeMeters, rangeMeters);
  return (clamped + rangeMeters) / (2 * rangeMeters);
}

/// 「上にいる/下にいる」と言い切らず「同じ高さ」とみなす差の上限(m)。
///
/// 気圧センサーの分解能に加え、気象由来のドリフト(キャリブレーション後に
/// 時間が経つほど基準がずれる)があるため、これ以下の差に方向を付けると
/// 実際には同じフロアにいる相手を「上」「下」と言い続けることになる。
/// 2m は 0.24hPa 相当で、建物の1フロア(3m前後)より小さい。
const double sameHeightThresholdMeters = 2;

/// 相手が自分より上か下か、ほぼ同じ高さか。
///
/// Flutterの`VerticalDirection`(up/down)と名前がぶつかるため別名にしている。
enum RelativeHeight {
  /// 相手の方が高い所にいる(相手の気圧の方が低い)。
  above,

  /// 相手の方が低い所にいる(相手の気圧の方が高い)。
  below,

  /// 方向を言えるほどの差がない。
  same,
}

/// 高さの差(m)から、相手が上か下か・ほぼ同じかを返す。
///
/// [deltaMeters]は[calculateRelativeHeightMeters]の戻り値(正なら相手が上)。
/// 差がちょうど[sameHeightThresholdMeters]なら`same`に倒す(境界では
/// 方向を言わない方が安全なため)。
RelativeHeight relativeHeightOf(
  double deltaMeters, {
  double sameThresholdMeters = sameHeightThresholdMeters,
}) {
  if (deltaMeters.abs() <= sameThresholdMeters) return RelativeHeight.same;
  return deltaMeters > 0 ? RelativeHeight.above : RelativeHeight.below;
}

/// 高さの差(m)を、元の気圧差(hPa)へ割り戻す。表示専用。
///
/// RTDBにもモデルにもhPa差は持っていないが、[deltaMeters]は
/// [calculateRelativeHeightMeters]が「hPa差 × [metersPerHectoPascal]」として
/// 作っているので、割れば復元できる。符号は落として大きさだけを返す
/// (上下の向きは[relativeHeightOf]が持つ)。
double hectoPascalDiffOf(double deltaMeters) =>
    deltaMeters.abs() / metersPerHectoPascal;
