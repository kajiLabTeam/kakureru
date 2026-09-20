import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/pressure/pressure_math.dart';

void main() {
  group('MovingAverage', () {
    test('averages fewer than windowSize values as-is', () {
      final avg = MovingAverage(windowSize: 5);
      expect(avg.add(10), 10);
      expect(avg.add(20), 15);
      expect(avg.add(30), 20);
    });

    test('drops values older than windowSize', () {
      final avg = MovingAverage(windowSize: 3);
      avg.add(10);
      avg.add(10);
      avg.add(10);
      // 4件目を入れたら1件目の10は移動平均から外れる
      final result = avg.add(100);
      expect(result, closeTo((10 + 10 + 100) / 3, 1e-9));
    });

    test('smooths a single noisy spike', () {
      final avg = MovingAverage(windowSize: 5);
      for (var i = 0; i < 4; i++) {
        avg.add(1000);
      }
      // ノイズで1回だけ大きく外れても、移動平均は生値ほど跳ねない
      final result = avg.add(1100);
      expect(result, closeTo(1020, 1e-9));
      expect(result, lessThan(1100));
    });
  });

  group('calculateRelativeHeightMeters', () {
    test('returns 0 when adjusted pressures are equal', () {
      final result = calculateRelativeHeightMeters(
        selfPressureHPa: 1013,
        selfOffsetHPa: 0,
        targetPressureHPa: 1013,
        targetOffsetHPa: 0,
      );
      expect(result, 0);
    });

    test('positive when target pressure is lower (target is above self)', () {
      // 気圧が低い方が高い場所にいる
      final result = calculateRelativeHeightMeters(
        selfPressureHPa: 1013,
        selfOffsetHPa: 0,
        targetPressureHPa: 1012,
        targetOffsetHPa: 0,
      );
      expect(result, closeTo(metersPerHectoPascal, 1e-9));
      expect(result, greaterThan(0));
    });

    test('negative when target pressure is higher (target is below self)', () {
      final result = calculateRelativeHeightMeters(
        selfPressureHPa: 1013,
        selfOffsetHPa: 0,
        targetPressureHPa: 1014,
        targetOffsetHPa: 0,
      );
      expect(result, closeTo(-metersPerHectoPascal, 1e-9));
    });

    test('offsets correct individual sensor bias before comparing', () {
      // 生の気圧は同じでも、targetの機体が+2hPaずれて出る個体差がある場合、
      // offsetで補正すればselfと同じ高さと判定される
      final result = calculateRelativeHeightMeters(
        selfPressureHPa: 1013,
        selfOffsetHPa: 0,
        targetPressureHPa: 1015,
        targetOffsetHPa: 2,
      );
      expect(result, closeTo(0, 1e-9));
    });
  });

  group('verticalDotFraction', () {
    test('returns 0.5 when deltaMeters is 0 (center)', () {
      expect(verticalDotFraction(0), closeTo(0.5, 1e-9));
    });

    test('returns 0 at the lower clamp boundary (-20)', () {
      expect(verticalDotFraction(-20), closeTo(0, 1e-9));
    });

    test('returns 1 at the upper clamp boundary (+20)', () {
      expect(verticalDotFraction(20), closeTo(1, 1e-9));
    });

    test('returns 0.625 at +5 within the default ±20 range', () {
      expect(verticalDotFraction(5), closeTo(0.625, 1e-9));
    });

    test('returns 0.375 at -5 within the default ±20 range', () {
      // 飽和しない負側の中間点。+5の0.625と中心0.5をはさんで対称になることで、
      // オフセット・符号の取り違え（(clamped + range) を (range - clamped) と
      // 書くような誤り）を検出する。
      expect(verticalDotFraction(-5), closeTo(0.375, 1e-9));
    });

    test('clamps values beyond +20 to 1', () {
      expect(verticalDotFraction(100), closeTo(1, 1e-9));
    });

    test('clamps values beyond -20 to 0', () {
      expect(verticalDotFraction(-100), closeTo(0, 1e-9));
    });

    test('respects a custom rangeMeters', () {
      expect(verticalDotFraction(5, rangeMeters: 5), closeTo(1, 1e-9));
      expect(verticalDotFraction(-5, rangeMeters: 5), closeTo(0, 1e-9));
    });
  });

  group('relativeHeightOf', () {
    test('差が閾値を超えて正なら、相手が上', () {
      expect(relativeHeightOf(8), RelativeHeight.above);
    });

    test('差が閾値を超えて負なら、相手が下', () {
      expect(relativeHeightOf(-8), RelativeHeight.below);
    });

    test('差が小さければ「同じ高さ」', () {
      expect(relativeHeightOf(0), RelativeHeight.same);
      expect(relativeHeightOf(1.5), RelativeHeight.same);
      expect(relativeHeightOf(-1.5), RelativeHeight.same);
    });

    test('境界(ちょうど閾値)は「同じ高さ」に倒す', () {
      // 境界で方向を言い切らない、という意図を固定する。
      expect(relativeHeightOf(sameHeightThresholdMeters), RelativeHeight.same);
      expect(relativeHeightOf(-sameHeightThresholdMeters), RelativeHeight.same);
      // わずかでも超えたら方向が付く。
      expect(
        relativeHeightOf(sameHeightThresholdMeters + 0.01),
        RelativeHeight.above,
      );
    });

    test('閾値は呼び出し側で変えられる', () {
      expect(relativeHeightOf(3, sameThresholdMeters: 5), RelativeHeight.same);
      expect(relativeHeightOf(3, sameThresholdMeters: 1), RelativeHeight.above);
    });
  });

  group('hectoPascalDiffOf', () {
    test('calculateRelativeHeightMetersで作った差を、元のhPa差へ割り戻せる', () {
      // 画面に出すhPaの数値はこの往復で作る。データ層にhPa差を持たせずに
      // 済んでいる根拠なので、往復で戻ることをテストで固定しておく。
      const selfPressure = 1013.25;
      const targetPressure = 1012.90;
      final meters = calculateRelativeHeightMeters(
        selfPressureHPa: selfPressure,
        selfOffsetHPa: 0,
        targetPressureHPa: targetPressure,
        targetOffsetHPa: 0,
      );

      expect(
        hectoPascalDiffOf(meters),
        closeTo(selfPressure - targetPressure, 1e-9),
      );
    });

    test('符号は落として大きさだけを返す(向きはrelativeHeightOfが持つ)', () {
      expect(hectoPascalDiffOf(metersPerHectoPascal), closeTo(1, 1e-9));
      expect(hectoPascalDiffOf(-metersPerHectoPascal), closeTo(1, 1e-9));
    });

    test('差が無ければ0', () {
      expect(hectoPascalDiffOf(0), 0);
    });
  });
}
