import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/pressure/pressure_math.dart';
import 'package:kakureru/features/room/model/clue_floor_math.dart';
import 'package:kakureru/features/room/model/room_user.dart';

/// 手がかりカードの高さ欄(階数・文言)の計算のテスト。
void main() {
  group('floorsOf', () {
    test('0.4hPaで1階ぶん', () {
      expect(floorsOf(0.4), 1);
      expect(floorsOf(-0.4), -1);
    });

    test('半階ぶん未満は0階(同じ高さ)', () {
      expect(floorsOf(0), 0);
      expect(floorsOf(0.19), 0);
      expect(floorsOf(-0.19), 0);
    });

    test('四捨五入で階数に丸める', () {
      expect(floorsOf(0.8), 2);
      expect(floorsOf(0.7), 2);
      expect(floorsOf(-0.9), -2);
    });

    test('相手の気圧が低い(正)なら上=正、高い(負)なら下=負', () {
      expect(floorsOf(0.4), isPositive);
      expect(floorsOf(-0.4), isNegative);
    });

    test('±3階に丸める', () {
      expect(floorsOf(1.2), 3);
      expect(floorsOf(5), 3);
      expect(floorsOf(-5), -3);
    });
  });

  group('opponentLowerPressureHPaOf', () {
    test('相手が上(deltaMetersが正)なら相手の気圧が低い=正', () {
      expect(
        opponentLowerPressureHPaOf(0.4 * metersPerHectoPascal),
        closeTo(0.4, 1e-9),
      );
    });

    test('相手が下なら負', () {
      expect(
        opponentLowerPressureHPaOf(-0.8 * metersPerHectoPascal),
        closeTo(-0.8, 1e-9),
      );
    });
  });

  group('floorDotFraction', () {
    test('同じ高さは中央、+3階は上端、-3階は下端', () {
      expect(floorDotFraction(0), closeTo(0.5, 1e-9));
      expect(floorDotFraction(3), closeTo(1, 1e-9));
      expect(floorDotFraction(-3), closeTo(0, 1e-9));
    });
  });

  group('文言', () {
    test('見出し', () {
      expect(floorHeadline(0), '同じくらいの高さかも');
      expect(floorHeadline(1), '1階ぶんくらい 上かも');
      expect(floorHeadline(-2), '2階ぶんくらい 下かも');
    });

    test('鬼には探すための行動のすすめを出す', () {
      const demon = UserRole.demon;
      expect(floorActionHint(0, viewerRole: demon), 'このフロアを探してみよう');
      expect(floorActionHint(1, viewerRole: demon), '階段をのぼってみよう');
      expect(floorActionHint(-1, viewerRole: demon), '階段をおりてみよう');
    });

    test('役割が分からないときは鬼と同じ文言にする', () {
      expect(floorActionHint(1, viewerRole: null), '階段をのぼってみよう');
    });

    test('逃走者には鬼がどこにいるかだけを出す (issue #135)', () {
      const fugitive = UserRole.fugitive;
      expect(floorActionHint(0, viewerRole: fugitive), '鬼は同じフロアにいるかも');
      expect(floorActionHint(2, viewerRole: fugitive), '鬼は上の階にいるかも');
      expect(floorActionHint(-1, viewerRole: fugitive), '鬼は下の階にいるかも');
    });

    test('気圧の補足は小数1桁', () {
      expect(pressureDetailText('りんや', 0.04), 'りんやの気圧は ほぼ同じ（0.0 hPa）');
      expect(pressureDetailText('たくみ', 0.4), 'たくみの気圧は 0.4 hPa 低い');
      expect(pressureDetailText('ゆい', -0.83), 'ゆいの気圧は 0.8 hPa 高い');
    });

    test('0階に丸まる差は符号があっても「ほぼ同じ」', () {
      expect(pressureDetailText('ゆい', -0.15), 'ゆいの気圧は ほぼ同じ（0.1 hPa）');
    });
  });
}
