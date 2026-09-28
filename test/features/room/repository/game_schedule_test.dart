import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';

void main() {
  group('computeGameSchedule (issue #119)', () {
    const startedAt = 1000000;

    test('放出は開始から放出待ちの時間後', () {
      final schedule = computeGameSchedule(
        startedAt: startedAt,
        setting: const RoomSetting(releaseWaitSec: 300),
      );
      expect(schedule.releasedAt, startedAt + 5 * 60 * 1000);
    });

    test('鬼ごっこの時間は放出後から数える(放出待ち5分・30分なら開始から35分後に終わる)', () {
      final schedule = computeGameSchedule(
        startedAt: startedAt,
        // 既定値に頼らず、テストの前提(30分)をここに明示する。
        // ignore: avoid_redundant_argument_values
        setting: const RoomSetting(releaseWaitSec: 300, gameDurationSec: 1800),
      );
      // 9/24のプレイテストでは開始から30分で終わり、放出後の残り時間が
      // 25分から始まっていた。
      expect(schedule.endsAt, startedAt + 35 * 60 * 1000);
      expect(schedule.endsAt - schedule.releasedAt, 30 * 60 * 1000);
    });
  });
}
