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
