import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/core/utils/duration_format.dart';

void main() {
  group('formatCountdown', () {
    test('分:秒(2桁ゼロ埋め)の形式にする', () {
      expect(formatCountdown(310), '5:10');
    });

    test('秒が1桁のときは0埋めする', () {
      expect(formatCountdown(65), '1:05');
    });

    test('1分未満は0:SS', () {
      expect(formatCountdown(9), '0:09');
    });

    test('0はそのまま0:00', () {
      expect(formatCountdown(0), '0:00');
    });

    test('負の値は0:00にクランプする(既に過ぎている場合の表示用)', () {
      expect(formatCountdown(-5), '0:00');
    });

    test('10分を超えても分側はそのまま桁数が伸びる', () {
      expect(formatCountdown(892), '14:52');
    });
  });
}
