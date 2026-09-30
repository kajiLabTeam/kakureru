import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/repository/mission_repository.dart';
import 'package:kakureru/features/room/model/room_setting.dart';

import '../../helpers/fake_rtdb.dart';

const _roomId = 'room1';
const _missionPath = 'rooms/$_roomId/missions/m1';

MissionRepository _repo(FakeRtdb db, String uid, {int now = 5000}) =>
    MissionRepository(
      db: db,
      auth: FakeAuth(uid),
      random: math.Random(1),
      serverNow: () async => now,
    );

FakeRtdb _dbWithMission({int expiresAt = 181000}) => FakeRtdb({
  'rooms': {
    _roomId: {
      'missions': {
        'm1': {
          'type': 'access_point',
          'createdAt': 1000,
          'expiresAt': expiresAt,
          'lat': 35.0,
          'lng': 137.0,
          'radiusM': 15.0,
        },
      },
    },
  },
});

Map<dynamic, dynamic> _effects(FakeRtdb db) =>
    db.read('rooms/$_roomId/effects') as Map<dynamic, dynamic>? ?? const {};

void main() {
  group('claimMission(先着1名)', () {
    test('2人が同時に押したら、1人だけが取れる', () async {
      final db = _dbWithMission();
      final results = await Future.wait([
        _repo(db, 'alice').claimMission(_roomId, 'm1'),
        _repo(db, 'bob').claimMission(_roomId, 'm1'),
      ]);

      final outcomes = results.map((r) => r.outcome).toList();
      expect(
        outcomes.where((o) => o == ClaimOutcome.claimed),
        hasLength(1),
      );
      expect(outcomes, contains(ClaimOutcome.takenByOther));

      // 書かれたのは取れた人のuidだけ。効果も1件だけ足される。
      final winner = results.first.outcome == ClaimOutcome.claimed
          ? 'alice'
          : 'bob';
      expect(db.read('$_missionPath/claimedBy'), winner);
      expect(_effects(db), hasLength(1));
      final effect = _effects(db).values.single as Map<dynamic, dynamic>;
      expect(effect['byUid'], winner);
    });

    test('取れたら特典をmissionsとeffectsの両方に書く', () async {
      final db = _dbWithMission();
      final result = await _repo(db, 'alice').claimMission(_roomId, 'm1');

      expect(result.outcome, ClaimOutcome.claimed);
      final reward = result.reward!;
      expect(db.read('$_missionPath/reward'), reward.raw);
      expect(db.read('$_missionPath/claimedAt'), 5000);
      final effect = _effects(db).values.single as Map<dynamic, dynamic>;
      expect(effect['type'], reward.raw);
      expect(effect['durationMs'], reward.duration.inMilliseconds);
    });

    test('もう取られていたら「ほかの人に取られた」で、何も書かない', () async {
      final db = _dbWithMission();
      await _repo(db, 'alice').claimMission(_roomId, 'm1');
      final effectsBefore = _effects(db).length;

      final result = await _repo(db, 'bob').claimMission(_roomId, 'm1');

      expect(result.outcome, ClaimOutcome.takenByOther);
      expect(db.read('$_missionPath/claimedBy'), 'alice');
      expect(_effects(db), hasLength(effectsBefore));
    });

    test('期限が切れていたら取れない', () async {
      final db = _dbWithMission(expiresAt: 5000);
      final result = await _repo(db, 'alice').claimMission(_roomId, 'm1');
      expect(result.outcome, ClaimOutcome.unavailable);
      expect(db.read('$_missionPath/claimedBy'), isNull);
      expect(_effects(db), isEmpty);
    });

    test('ミッションが無ければ取れない', () async {
      final db = FakeRtdb();
      final result = await _repo(db, 'alice').claimMission(_roomId, 'm1');
      expect(result.outcome, ClaimOutcome.unavailable);
    });

    test('サーバー時刻が取れなければ投げて、何も書かない', () async {
      final db = _dbWithMission();
      final repo = MissionRepository(
        db: db,
        auth: FakeAuth('alice'),
        serverNow: () async => null,
      );
      await expectLater(
        repo.claimMission(_roomId, 'm1'),
        throwsA(isA<MissionClaimUnavailableException>()),
      );
      expect(db.read('$_missionPath/claimedBy'), isNull);
    });
  });

  group('createMission', () {
    final area = [
      const LatLng(lat: 35.1830, lng: 137.1130),
      const LatLng(lat: 35.1830, lng: 137.1154),
      const LatLng(lat: 35.1850, lng: 137.1154),
      const LatLng(lat: 35.1850, lng: 137.1130),
    ];

    test('期限は渡したサーバー時刻 + 種類ごとの制限時間', () async {
      final db = FakeRtdb();
      await _repo(db, 'host').createMission(
        _roomId,
        area: area,
        previousPoint: null,
        nowMillis: 100000,
      );
      final missions =
          db.read('rooms/$_roomId/missions')! as Map<dynamic, dynamic>;
      final mission = missions.values.single as Map<dynamic, dynamic>;
      final type = mission['type'];
      final limit = type == 'access_point' ? 180000 : 120000;
      expect(mission['expiresAt'], 100000 + limit);
      if (type == 'access_point') {
        expect(mission['radiusM'], 15);
        expect(mission['lat'], isNotNull);
      }
    });

    test('エリアが無ければ「鬼に近づけ」を書く(地点を置けない)', () async {
      final db = FakeRtdb();
      await _repo(db, 'host').createMission(
        _roomId,
        area: const [],
        previousPoint: null,
        nowMillis: 100000,
      );
      final missions =
          db.read('rooms/$_roomId/missions')! as Map<dynamic, dynamic>;
      final mission = missions.values.single as Map<dynamic, dynamic>;
      expect(mission['type'], 'approach_demon');
      expect(mission.containsKey('lat'), isFalse);
    });
  });

  test('drawRewardはハズレを出さず、3種類すべてが出うる', () {
    final random = math.Random(3);
    final drawn = {for (var i = 0; i < 100; i++) drawReward(random)};
    expect(drawn, RewardType.values.toSet());
  });
}
