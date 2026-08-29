import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/role_visibility.dart';

void main() {
  group('isRoleVisible', () {
    const releasedAt = 100000;
    const fugitiveInfoDelaySec = 60;

    test('同じ役割同士は常に見える(放出前でも)', () {
      expect(
        isRoleVisible(
          viewerRole: UserRole.fugitive,
          targetRole: UserRole.fugitive,
          releasedAt: releasedAt,
          fugitiveInfoDelaySec: fugitiveInfoDelaySec,
          nowMillis: 0,
        ),
        isTrue,
      );
      expect(
        isRoleVisible(
          viewerRole: UserRole.demon,
          targetRole: UserRole.demon,
          releasedAt: releasedAt,
          fugitiveInfoDelaySec: fugitiveInfoDelaySec,
          nowMillis: 0,
        ),
        isTrue,
      );
    });

    test('鬼→逃走者: releasedAt前は見えない', () {
      expect(
        isRoleVisible(
          viewerRole: UserRole.demon,
          targetRole: UserRole.fugitive,
          releasedAt: releasedAt,
          fugitiveInfoDelaySec: fugitiveInfoDelaySec,
          nowMillis: releasedAt - 1,
        ),
        isFalse,
      );
    });

    test('鬼→逃走者: releasedAtちょうどで見える', () {
      expect(
        isRoleVisible(
          viewerRole: UserRole.demon,
          targetRole: UserRole.fugitive,
          releasedAt: releasedAt,
          fugitiveInfoDelaySec: fugitiveInfoDelaySec,
          nowMillis: releasedAt,
        ),
        isTrue,
      );
    });

    test('逃走者→鬼: releasedAtを過ぎただけではまだ見えない(delay分待つ)', () {
      expect(
        isRoleVisible(
          viewerRole: UserRole.fugitive,
          targetRole: UserRole.demon,
          releasedAt: releasedAt,
          fugitiveInfoDelaySec: fugitiveInfoDelaySec,
          nowMillis: releasedAt + 1000, // 1秒しか経ってない(60秒必要)
        ),
        isFalse,
      );
    });

    test('逃走者→鬼: releasedAt + fugitiveInfoDelaySec ちょうどで見える', () {
      final now = releasedAt + fugitiveInfoDelaySec * 1000;
      expect(
        isRoleVisible(
          viewerRole: UserRole.fugitive,
          targetRole: UserRole.demon,
          releasedAt: releasedAt,
          fugitiveInfoDelaySec: fugitiveInfoDelaySec,
          nowMillis: now,
        ),
        isTrue,
      );
    });

    test('releasedAtが未確定(null)なら異役割間は見えない', () {
      expect(
        isRoleVisible(
          viewerRole: UserRole.demon,
          targetRole: UserRole.fugitive,
          releasedAt: null,
          fugitiveInfoDelaySec: fugitiveInfoDelaySec,
          nowMillis: 999999,
        ),
        isFalse,
      );
    });
  });

  group('determineGamePhase', () {
    test('releasedAt前はbeforeRelease', () {
      expect(
        determineGamePhase(releasedAt: 1000, nowMillis: 500),
        GamePhase.beforeRelease,
      );
    });

    test('releasedAtちょうどでreleased', () {
      expect(
        determineGamePhase(releasedAt: 1000, nowMillis: 1000),
        GamePhase.released,
      );
    });

    test('releasedAtが未確定ならbeforeRelease扱い', () {
      expect(
        determineGamePhase(releasedAt: null, nowMillis: 999999),
        GamePhase.beforeRelease,
      );
    });
  });

  group('calculateCountdownSeconds', () {
    test('beforeRelease中はreleasedAtまでの残りを返す(切り上げ)', () {
      final result = calculateCountdownSeconds(
        phase: GamePhase.beforeRelease,
        releasedAt: 10500,
        endsAt: 999999,
        nowMillis: 9000,
      );
      // (10500 - 9000) / 1000 = 1.5 -> 切り上げで2
      expect(result, 2);
    });

    test('released後はendsAtまでの残りを返す', () {
      final result = calculateCountdownSeconds(
        phase: GamePhase.released,
        releasedAt: 1000,
        endsAt: 60000,
        nowMillis: 55000,
      );
      expect(result, 5);
    });

    test('対象の時刻が未確定ならnull', () {
      final result = calculateCountdownSeconds(
        phase: GamePhase.beforeRelease,
        releasedAt: null,
        endsAt: 60000,
        nowMillis: 0,
      );
      expect(result, isNull);
    });

    test('既に過ぎていれば負の値を返す(0未満へのクランプは呼び出し側の責務)', () {
      final result = calculateCountdownSeconds(
        phase: GamePhase.released,
        releasedAt: 1000,
        endsAt: 60000,
        nowMillis: 61000,
      );
      expect(result, -1);
    });
  });

  group('isGameOver', () {
    test('endsAt前かつWAITING/PLAYINGならまだ終了していない', () {
      expect(
        isGameOver(status: RoomStatus.playing, endsAt: 60000, nowMillis: 59999),
        isFalse,
      );
    });

    test('endsAtちょうどで終了とみなす', () {
      expect(
        isGameOver(status: RoomStatus.playing, endsAt: 60000, nowMillis: 60000),
        isTrue,
      );
    });

    test('endsAtを過ぎたら終了とみなす', () {
      expect(
        isGameOver(status: RoomStatus.playing, endsAt: 60000, nowMillis: 60001),
        isTrue,
      );
    });

    test('endsAt未確定でもstatusがFINISHEDなら終了とみなす', () {
      expect(
        isGameOver(status: RoomStatus.finished, endsAt: null, nowMillis: 0),
        isTrue,
      );
    });

    test('endsAt未確定でstatusもFINISHEDでなければ終了していない', () {
      expect(
        isGameOver(status: RoomStatus.waiting, endsAt: null, nowMillis: 999999),
        isFalse,
      );
    });
  });

  group('canReportCaught', () {
    test('逃走者かつ鬼放出後なら表示する', () {
      expect(
        canReportCaught(role: UserRole.fugitive, phase: GamePhase.released),
        isTrue,
      );
    });

    test('逃走者でも鬼放出前は表示しない', () {
      expect(
        canReportCaught(role: UserRole.fugitive, phase: GamePhase.beforeRelease),
        isFalse,
      );
    });

    test('鬼放出後でも自分が鬼なら表示しない', () {
      expect(
        canReportCaught(role: UserRole.demon, phase: GamePhase.released),
        isFalse,
      );
    });

    test('鬼かつ鬼放出前も表示しない', () {
      expect(
        canReportCaught(role: UserRole.demon, phase: GamePhase.beforeRelease),
        isFalse,
      );
    });
  });
}
