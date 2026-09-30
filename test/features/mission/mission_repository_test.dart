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
      // 効果のキーはミッションID(やり直しても重ならないように)。
      expect(_effects(db).keys.single, 'm1');
      expect(effect['startedAt'], 5000);
    });

    test('足元写真の特典なら、押した瞬間に決めた飛ばすスロットを書く', () async {
      // skip_foot_photo を引く乱数の種を探す。
      for (var seed = 0; seed < 50; seed++) {
        if (drawReward(math.Random(seed)) != RewardType.skipFootPhoto) {
          continue;
        }
        final db = _dbWithMission();
        await MissionRepository(
          db: db,
          auth: FakeAuth('alice'),
          random: math.Random(seed),
          serverNow: () async => 5000,
        ).claimMission(_roomId, 'm1', footPhotoSkipSlot: 3);
        expect(db.read('rooms/$_roomId/effects/m1/skipSlot'), 3);
        return;
      }
      fail('skip_foot_photo を引く種が見つからない');
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

  group('completeClaim(取った後の特典の受け取り直し)', () {
    test('取ったまま特典が書かれていなければ、受け取り直して効果を足す', () async {
      // 取り合いには勝ったが、特典を書く前に通信が切れた状態。
      final db = _dbWithMission();
      db
        ..write('$_missionPath/claimedBy', 'alice')
        ..write('$_missionPath/claimedAt', 4000);

      final reward = await _repo(db, 'alice').completeClaim(_roomId, 'm1');

      expect(db.read('$_missionPath/reward'), reward.raw);
      expect(_effects(db).keys.single, 'm1');
    });

    test('何度受け取り直しても、特典は変わらず効果も1件のまま', () async {
      final db = _dbWithMission();
      final first = await _repo(db, 'alice').claimMission(_roomId, 'm1');
      final startedAt = db.read('rooms/$_roomId/effects/m1/startedAt');

      final again = await MissionRepository(
        db: db,
        auth: FakeAuth('alice'),
        random: math.Random(99),
        serverNow: () async => 20000,
      ).completeClaim(_roomId, 'm1');

      expect(again, first.reward);
      expect(_effects(db), hasLength(1));
      // 残り時間も延びない(効果を書き直さない)。
      expect(db.read('rooms/$_roomId/effects/m1/startedAt'), startedAt);
    });

    test('特典だけ書けて効果が書けていなければ、同じ特典で効果を足す', () async {
      final db = _dbWithMission();
      db
        ..write('$_missionPath/claimedBy', 'alice')
        ..write('$_missionPath/reward', 'big_demon_icon');

      final reward = await _repo(db, 'alice').completeClaim(_roomId, 'm1');

      expect(reward, RewardType.bigDemonIcon);
      expect(db.read('rooms/$_roomId/effects/m1/type'), 'big_demon_icon');
    });

    test('ほかの人が取ったミッションは受け取れない', () async {
      final db = _dbWithMission();
      db.write('$_missionPath/claimedBy', 'bob');
      await expectLater(
        _repo(db, 'alice').completeClaim(_roomId, 'm1'),
        throwsA(isA<MissionClaimUnavailableException>()),
      );
      expect(_effects(db), isEmpty);
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
