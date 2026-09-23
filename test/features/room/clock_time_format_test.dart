import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/clock_time_format.dart';

void main() {
  test('時・分をそれぞれ0埋め2桁のHH:MMにする', () {
    final epochMillis = DateTime(2026, 9, 22, 9, 5).millisecondsSinceEpoch;
    expect(formatClockTime(epochMillis), '09:05');
  });

  test('午後の時刻も24時間表記になる', () {
    final epochMillis = DateTime(2026, 9, 22, 17, 30).millisecondsSinceEpoch;
    expect(formatClockTime(epochMillis), '17:30');
  });

  test('0時0分も0埋めされる', () {
    final epochMillis = DateTime(2026, 9, 22).millisecondsSinceEpoch;
    expect(formatClockTime(epochMillis), '00:00');
  });
}
