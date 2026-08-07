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
}
