import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/core/utils/duration_format.dart';

void main() {
  group('formatCountdown', () {
    test('分:秒(2桁ゼロ埋め)の形式にする', () {
      expect(formatCountdown(310), '05:10');
    });

    test('秒が1桁のときは0埋めする', () {
      expect(formatCountdown(65), '01:05');
    });

    test('1分未満は00:SS', () {
      expect(formatCountdown(9), '00:09');
    });

    test('0は00:00', () {
      expect(formatCountdown(0), '00:00');
    });

    test('負の値は0:00(00:00)にクランプする(既に過ぎている場合の表示用)', () {
      expect(formatCountdown(-5), '00:00');
    });

    test('10分以上はそのまま2桁', () {
      expect(formatCountdown(892), '14:52');
    });
  });
}
