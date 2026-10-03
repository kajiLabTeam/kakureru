import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/repository/mission_repository.dart';
import 'package:kakureru/features/room/model/room_setting.dart';

import '../../helpers/fake_rtdb.dart';

const _roomId = 'room1';
const _missionPath = 'rooms/$_roomId/missions/m1';
const _spotPath = '$_missionPath/spots/s0';
const _effectPath = 'rooms/$_roomId/effects/m1_s0';

MissionRepository _repo(FakeRtdb db, String uid, {int now = 5000}) =>
    MissionRepository(
      db: db,
      auth: FakeAuth(uid),
      random: math.Random(1),
      serverNow: () async => now,
    );

FakeRtdb _dbWithMission({int expiresAt = 301000}) => FakeRtdb({
  'rooms': {
    _roomId: {
      'missions': {
        'm1': {
          'round': 1,
          'createdAt': 1000,
          'expiresAt': expiresAt,
          'spots': {
            's0': {'lat': 35.0, 'lng': 137.0, 'radiusM': 15.0},
            's1': {'lat': 35.001, 'lng': 137.0, 'radiusM': 15.0},
          },
        },
      },
    },
  },
});

Map<dynamic, dynamic> _effects(FakeRtdb db) =>
    db.read('rooms/$_roomId/effects') as Map<dynamic, dynamic>? ?? const {};

void main() {
  group('claimMission(1地点に先着1人)', () {
    test('2人が同じ地点を同時に押したら、1人だけが取れる', () async {
      final db = _dbWithMission();
      final results = await Future.wait([
        _repo(db, 'alice').claimMission(_roomId, 'm1', 's0'),
        _repo(db, 'bob').claimMission(_roomId, 'm1', 's0'),
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
      expect(db.read('$_spotPath/claimedBy'), winner);
      expect(db.read('$_missionPath/spots/s1/claimedBy'), isNull);
      expect(db.read('$_missionPath/finishedAt'), isNull);
      expect(_effects(db), hasLength(1));
      final effect = _effects(db).values.single as Map<dynamic, dynamic>;
      expect(effect['byUid'], winner);
    });

    test('ちがう地点なら2人とも取れて、全部埋まったらその場で終わる', () async {
      final db = _dbWithMission();
      final results = await Future.wait([
        _repo(db, 'alice').claimMission(_roomId, 'm1', 's0'),
        _repo(db, 'bob', now: 6000).claimMission(_roomId, 'm1', 's1'),
      ]);
      expect(
        results.map((r) => r.outcome),
        everyElement(ClaimOutcome.claimed),
      );
      expect(db.read('$_missionPath/finishedAt'), isNotNull);
      expect(_effects(db).keys, unorderedEquals(['m1_s0', 'm1_s1']));
    });

    test('鬼の手がかりを止めるは持っておくので、地点にだけ書いて効果は書かない', () async {
      final db = _dbWithMission();
      // seed=2は block_clues を引く種。
      expect(drawReward(math.Random(2)), RewardType.blockClues);
      final result = await MissionRepository(
        db: db,
        auth: FakeAuth('alice'),
        random: math.Random(2),
        serverNow: () async => 5000,
      ).claimMission(_roomId, 'm1', 's0');

      expect(result.outcome, ClaimOutcome.claimed);
      expect(result.reward, RewardType.blockClues);
      expect(db.read('$_spotPath/reward'), 'block_clues');
      expect(db.read('$_spotPath/claimedAt'), 5000);
      expect(_effects(db), isEmpty);
    });

    test('持っておかないごほうびは、取れたら地点とeffectsの両方に書く', () async {
      for (var seed = 0; seed < 50; seed++) {
        final drawn = drawReward(math.Random(seed));
        if (drawn != RewardType.enlargeSelfIcon) continue;
        final db = _dbWithMission();
        final result = await MissionRepository(
          db: db,
          auth: FakeAuth('alice'),
          random: math.Random(seed),
          serverNow: () async => 5000,
        ).claimMission(_roomId, 'm1', 's0');

        expect(result.reward, RewardType.enlargeSelfIcon);
        expect(db.read('$_spotPath/reward'), 'enlarge_self_icon');
        final effect = _effects(db).values.single as Map<dynamic, dynamic>;
        expect(effect['type'], 'enlarge_self_icon');
        // 効果のキーはミッションIDと地点ID(やり直しても重ならないように)。
        expect(_effects(db).keys.single, 'm1_s0');
        expect(effect['startedAt'], 5000);
        expect(effect['durationMs'], 120000);
        return;
      }
      fail('enlarge_self_icon を引く種が見つからない');
    });

    test('足元写真のごほうびなら、押した瞬間に決めた飛ばすスロットを書く', () async {
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
        ).claimMission(_roomId, 'm1', 's0', footPhotoSkipSlot: 3);
        expect(db.read('$_effectPath/skipSlot'), 3);
        expect(db.read('$_effectPath/durationMs'), 0);
        return;
      }
      fail('skip_foot_photo を引く種が見つからない');
    });

    test('もう取られていたら「ほかの人に取られた」で、何も書かない', () async {
      final db = _dbWithMission();
      await _repo(db, 'alice').claimMission(_roomId, 'm1', 's0');
      final effectsBefore = _effects(db).length;

      final result = await _repo(db, 'bob').claimMission(_roomId, 'm1', 's0');

      expect(result.outcome, ClaimOutcome.takenByOther);
      expect(db.read('$_spotPath/claimedBy'), 'alice');
      expect(_effects(db), hasLength(effectsBefore));
    });

    test('1人で2つ目の地点は取れない', () async {
      final db = _dbWithMission();
      await _repo(db, 'alice').claimMission(_roomId, 'm1', 's0');
      final result = await _repo(
        db,
        'alice',
      ).claimMission(_roomId, 'm1', 's1');
      expect(result.outcome, ClaimOutcome.unavailable);
      expect(db.read('$_missionPath/spots/s1/claimedBy'), isNull);
    });

    test('期限が切れていたら取れない', () async {
      final db = _dbWithMission(expiresAt: 5000);
      final result = await _repo(
        db,
        'alice',
      ).claimMission(_roomId, 'm1', 's0');
      expect(result.outcome, ClaimOutcome.unavailable);
      expect(db.read('$_spotPath/claimedBy'), isNull);
      expect(_effects(db), isEmpty);
    });

    test('ミッションが無ければ取れない', () async {
      final db = FakeRtdb();
      final result = await _repo(
        db,
        'alice',
      ).claimMission(_roomId, 'm1', 's0');
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
        repo.claimMission(_roomId, 'm1', 's0'),
        throwsA(isA<MissionClaimUnavailableException>()),
      );
      expect(db.read('$_spotPath/claimedBy'), isNull);
    });
  });

  group('completeClaim(取った後のごほうびの受け取り直し)', () {
    test('取ったままごほうびが書かれていなければ、受け取り直して効果を足す', () async {
      // 取り合いには勝ったが、ごほうびを書く前に通信が切れた状態。
      final db = _dbWithMission();
      db
        ..write('$_spotPath/claimedBy', 'alice')
        ..write('$_spotPath/claimedAt', 4000);

      final reward = await _repo(
        db,
        'alice',
      ).completeClaim(_roomId, 'm1', 's0');

      expect(db.read('$_spotPath/reward'), reward.raw);
      expect(_effects(db).keys.single, 'm1_s0');
    });

    test('何度受け取り直しても、ごほうびは変わらず効果も1件のまま', () async {
      final db = _dbWithMission();
      final first = await _repo(
        db,
        'alice',
      ).claimMission(_roomId, 'm1', 's0');
      final startedAt = db.read('$_effectPath/startedAt');

      final again = await MissionRepository(
        db: db,
        auth: FakeAuth('alice'),
        random: math.Random(99),
        serverNow: () async => 20000,
      ).completeClaim(_roomId, 'm1', 's0');

      expect(again, first.reward);
      expect(_effects(db), hasLength(1));
      // 残り時間も延びない(効果を書き直さない)。
      expect(db.read('$_effectPath/startedAt'), startedAt);
    });

    test('ごほうびだけ書けて効果が書けていなければ、同じごほうびで効果を足す', () async {
      final db = _dbWithMission();
      db
        ..write('$_spotPath/claimedBy', 'alice')
        ..write('$_spotPath/reward', 'enlarge_self_icon');

      final reward = await _repo(
        db,
        'alice',
      ).completeClaim(_roomId, 'm1', 's0');

      expect(reward, RewardType.enlargeSelfIcon);
      expect(db.read('$_effectPath/type'), 'enlarge_self_icon');
      expect(db.read('$_effectPath/durationMs'), 120000);
    });

    test('ほかの人が取った地点は受け取れない', () async {
      final db = _dbWithMission();
      db.write('$_spotPath/claimedBy', 'bob');
      await expectLater(
        _repo(db, 'alice').completeClaim(_roomId, 'm1', 's0'),
        throwsA(isA<MissionClaimUnavailableException>()),
      );
      expect(_effects(db), isEmpty);
    });
  });

  group('useHeldReward(持っているごほうびを好きなときに使う)', () {
    FakeRtdb dbWithHeld({String by = 'alice', String reward = 'block_clues'}) {
      final db = _dbWithMission();
      db
        ..write('$_spotPath/claimedBy', by)
        ..write('$_spotPath/claimedAt', 5000)
        ..write('$_spotPath/reward', reward);
      return db;
    }

    test('使った時刻から3分の効果を書く', () async {
      final db = dbWithHeld();
      final used = await _repo(
        db,
        'alice',
        now: 90000,
      ).useHeldReward(_roomId, 'm1', 's0');

      expect(used, isTrue);
      expect(db.read('$_effectPath/type'), 'block_clues');
      expect(db.read('$_effectPath/byUid'), 'alice');
      expect(db.read('$_effectPath/startedAt'), 90000);
      expect(db.read('$_effectPath/durationMs'), 180000);
    });

    test('2回押しても1回しか使えない(2回目はfalseで、時刻も変えない)', () async {
      final db = dbWithHeld();
      expect(
        await _repo(db, 'alice', now: 90000).useHeldReward(_roomId, 'm1', 's0'),
        isTrue,
      );
      expect(
        await _repo(
          db,
          'alice',
          now: 120000,
        ).useHeldReward(_roomId, 'm1', 's0'),
        isFalse,
      );
      expect(_effects(db), hasLength(1));
      expect(db.read('$_effectPath/startedAt'), 90000);
    });

    test('ほかの人が引いたごほうびは使えない', () async {
      final db = dbWithHeld(by: 'bob');
      await expectLater(
        _repo(db, 'alice').useHeldReward(_roomId, 'm1', 's0'),
        throwsA(isA<MissionClaimUnavailableException>()),
      );
      expect(_effects(db), isEmpty);
    });

    test('持っておかないごほうびは使えない', () async {
      final db = dbWithHeld(reward: 'skip_foot_photo');
      await expectLater(
        _repo(db, 'alice').useHeldReward(_roomId, 'm1', 's0'),
        throwsA(isA<MissionClaimUnavailableException>()),
      );
      expect(_effects(db), isEmpty);
    });

    test('サーバー時刻が取れなければ使えない', () async {
      final db = dbWithHeld();
      await expectLater(
        MissionRepository(
          db: db,
          auth: FakeAuth('alice'),
          random: math.Random(1),
          serverNow: () async => null,
        ).useHeldReward(_roomId, 'm1', 's0'),
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

    test('期限は渡したサーバー時刻 + 5分。地点を指定の数だけ書く', () async {
      final db = FakeRtdb();
      await _repo(db, 'host').createMission(
        _roomId,
        area: area,
        spotCount: 3,
        round: 2,
        nowMillis: 100000,
      );
      final missions =
          db.read('rooms/$_roomId/missions')! as Map<dynamic, dynamic>;
      final mission = missions.values.single as Map<dynamic, dynamic>;
      expect(mission['round'], 2);
      expect(mission['expiresAt'], 100000 + 5 * 60 * 1000);
      final spots = mission['spots'] as Map<dynamic, dynamic>;
      expect(spots.keys, unorderedEquals(['s0', 's1', 's2']));
      for (final spot in spots.values.cast<Map<dynamic, dynamic>>()) {
        expect(spot['radiusM'], 15);
        expect(spot['lat'], isNotNull);
        expect(spot['claimedBy'], isNull);
      }
    });

    test('エリアが無ければ何も書かない(地点を置けない)', () async {
      final db = FakeRtdb();
      await _repo(db, 'host').createMission(
        _roomId,
        area: const [],
        spotCount: 2,
        round: 1,
        nowMillis: 100000,
      );
      expect(db.read('rooms/$_roomId/missions'), isNull);
    });
  });

  test('drawRewardはハズレを出さず、3種類すべてが出うる', () {
    final random = math.Random(3);
    final drawn = {for (var i = 0; i < 100; i++) drawReward(random)};
    expect(drawn, RewardType.values.toSet());
  });
}
