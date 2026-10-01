import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/mission/mission_rules.dart';
import 'package:kakureru/features/mission/mission_timing.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/room/model/room_setting.dart';

/// 名古屋あたりの基準点。緯度1度 ≒ 111km、経度1度 ≒ 91km(北緯35度)。
const _baseLat = 35.1830;
const _baseLng = 137.1130;

/// 北へ[meters]進んだ緯度。
double _north(double meters) => _baseLat + meters / 111320;

MissionSpot _spot({
  String id = 's0',
  double northM = 0,
  String? claimedBy,
  int? claimedAt,
}) => MissionSpot(
  id: id,
  lat: _north(northM),
  lng: _baseLng,
  radiusM: accessPointRadiusM,
  claimedBy: claimedBy,
  claimedAt: claimedAt,
);

Mission _mission({
  String id = 'm1',
  int round = 1,
  int createdAt = 100000,
  int? expiresAt,
  int? finishedAt,
  List<MissionSpot>? spots,
}) => Mission(
  id: id,
  round: round,
  createdAt: createdAt,
  expiresAt: expiresAt ?? createdAt + missionTimeLimit.inMilliseconds,
  finishedAt: finishedAt,
  spots: spots ?? [_spot(), _spot(id: 's1', northM: 100)],
);

UserLocation _at(double lat, {double? accuracy = 5, int updatedAt = 1}) =>
    UserLocation(
      uid: 'me',
      latitude: lat,
      longitude: _baseLng,
      accuracy: accuracy,
      updatedAt: updatedAt,
    );

void main() {
  test('地点の数は鬼の人数 + 1', () {
    expect(missionSpotCount(demonCount: 1), 2);
    expect(missionSpotCount(demonCount: 3), 4);
  });

  group('missionsOfCurrentGame', () {
    test('開始前のミッション(前のゲームの残り)を除き、古い順に並べる', () {
      final result = missionsOfCurrentGame(
        [
          _mission(id: 'new', createdAt: 5000),
          _mission(id: 'old', createdAt: 500),
          _mission(id: 'mid', createdAt: 2000),
        ],
        startedAt: 1000,
      );
      expect(result.map((m) => m.id), ['mid', 'new']);
    });

    test('開始前(startedAtがnull)なら空', () {
      expect(missionsOfCurrentGame([_mission()], startedAt: null), isEmpty);
    });
  });

  group('期限と終わり', () {
    test('制限時間は5分。expiresAtの直前は切れていない、ちょうどから切れている', () {
      final mission = _mission(createdAt: 0);
      expect(mission.expiresAt, 5 * 60 * 1000);
      expect(isMissionExpired(mission, nowMillis: 299999), isFalse);
      expect(isMissionExpired(mission, nowMillis: 300000), isTrue);
      expect(isMissionActive(mission, nowMillis: 300000), isFalse);
    });

    test('地点がすべて取られたら、期限前でもその場で終わる', () {
      final partly = _mission(
        spots: [
          _spot(claimedBy: 'a', claimedAt: 110000),
          _spot(id: 's1'),
        ],
      );
      expect(isMissionActive(partly, nowMillis: 120000), isTrue);
      expect(openSpots(partly).map((s) => s.id), ['s1']);

      final all = _mission(
        finishedAt: 130000,
        spots: [
          _spot(claimedBy: 'a', claimedAt: 110000),
          _spot(id: 's1', claimedBy: 'b', claimedAt: 130000),
        ],
      );
      expect(areAllSpotsClaimed(all), isTrue);
      expect(isMissionFinishedEarly(all), isTrue);
      expect(isMissionActive(all, nowMillis: 130001), isFalse);
      expect(missionEndedAt(all), 130000);
    });

    test('currentMissionは期限切れならnull、全部取られて15秒たったらnull', () {
      final expired = _mission(createdAt: 1000, expiresAt: 5000);
      expect(currentMission([expired], startedAt: 0, nowMillis: 5000), isNull);
      final finished = _mission(
        createdAt: 1000,
        finishedAt: 2000,
        spots: [_spot(claimedBy: 'a', claimedAt: 2000)],
      );
      expect(
        currentMission([finished], startedAt: 0, nowMillis: 16999),
        isNotNull,
      );
      expect(
        currentMission([finished], startedAt: 0, nowMillis: 17000),
        isNull,
      );
    });

    test('spotClaimedByは自分が取った地点を返す', () {
      final mission = _mission(
        spots: [
          _spot(),
          _spot(id: 's1', claimedBy: 'me'),
        ],
      );
      expect(spotClaimedBy(mission, 'me')?.id, 's1');
      expect(spotClaimedBy(mission, 'other'), isNull);
      expect(spotClaimedBy(mission, null), isNull);
    });

    test('visibleMissionSpotsは自分が取った地点を除き、ほかの地点は取られていても残す', () {
      final mission = _mission(
        spots: [
          _spot(id: 's0', claimedBy: 'me', claimedAt: 1000),
          _spot(id: 's1', claimedBy: 'other', claimedAt: 2000),
          _spot(id: 's2'),
        ],
      );
      expect(
        visibleMissionSpots(mission, myUid: 'me').map((s) => s.id),
        ['s1', 's2'],
      );
    });

    test('visibleMissionSpotsはmyUidが無ければ全地点を除外せず返す', () {
      final mission = _mission(
        spots: [
          _spot(id: 's0', claimedBy: 'other', claimedAt: 1000),
          _spot(id: 's1'),
        ],
      );
      expect(
        visibleMissionSpots(mission).map((s) => s.id),
        ['s0', 's1'],
      );
    });

    test('visibleMissionSpotsはミッションが早期終了したら空(カード猶予中も含む)', () {
      final finishedEarly = _mission(
        spots: [
          _spot(id: 's0', claimedBy: 'other', claimedAt: 1000),
          _spot(id: 's1', claimedBy: 'another', claimedAt: 1000),
        ],
      );
      expect(areAllSpotsClaimed(finishedEarly), isTrue);
      expect(visibleMissionSpots(finishedEarly, myUid: 'me'), isEmpty);

      final cancelled = _mission(finishedAt: 5000);
      expect(visibleMissionSpots(cancelled, myUid: 'me'), isEmpty);
    });
  });

  group('missionRoundToCreate(出すタイミング)', () {
    const releasedAt = 1000000;
    const min = 60 * 1000;

    int? round(List<Mission> missions, int now, {int? endsAt}) =>
        missionRoundToCreate(
          missions: missions,
          startedAt: 0,
          releasedAt: releasedAt,
          endsAt: endsAt,
          nowMillis: now,
        );

    test('放出前・放出から5分未満は書かない、5分で1回目', () {
      expect(
        missionRoundToCreate(
          missions: const [],
          startedAt: 0,
          releasedAt: null,
          endsAt: null,
          nowMillis: 99999999,
        ),
        isNull,
      );
      expect(round(const [], releasedAt + 5 * min - 1), isNull);
      expect(round(const [], releasedAt + 5 * min), 1);
    });

    test('1回目が終わっていれば、15分で2回目', () {
      final first = _mission(createdAt: releasedAt + 5 * min);
      expect(round([first], releasedAt + 15 * min - 1), isNull);
      expect(round([first], releasedAt + 15 * min), 2);
    });

    test('3回目は無い', () {
      final first = _mission(createdAt: releasedAt + 5 * min);
      final second = _mission(
        id: 'm2',
        round: 2,
        createdAt: releasedAt + 15 * min,
      );
      expect(round([first, second], releasedAt + 60 * min), isNull);
    });

    test('受けられるミッションが残っていれば書かない(同時に1件だけ)', () {
      final active = _mission(createdAt: releasedAt + 14 * min);
      expect(round([active], releasedAt + 15 * min), isNull);
    });

    test('2回目の前にゲームが終われば2回目は出ない', () {
      final first = _mission(createdAt: releasedAt + 5 * min);
      expect(
        round(
          [first],
          releasedAt + 15 * min,
          endsAt: releasedAt + 12 * min,
        ),
        isNull,
      );
    });

    test('1回目が遅れて書かれたら、2回目はその期限が切れるまで待つ', () {
      // 放出から14:59に1回目。期限は19:59なので15分では2回目を書かない。
      final late = _mission(createdAt: releasedAt + 14 * min + 59 * 1000);
      expect(round([late], releasedAt + 15 * min), isNull);
      expect(round([late], late.expiresAt), 2);
    });

    test('書きそびれた1回目は飛ばし、2回目だけを書く', () {
      expect(round(const [], releasedAt + 16 * min), 2);
    });
  });

  group('pickAccessPoints', () {
    // 約220m四方のエリア。
    final area = [
      const LatLng(lat: _baseLat, lng: _baseLng),
      const LatLng(lat: _baseLat, lng: _baseLng + 0.0024),
      const LatLng(lat: _baseLat + 0.002, lng: _baseLng + 0.0024),
      const LatLng(lat: _baseLat + 0.002, lng: _baseLng),
    ];

    test('エリアの中に、互いに50m以上離れた地点を指定の数だけ選ぶ', () {
      for (var seed = 0; seed < 20; seed++) {
        final points = pickAccessPoints(
          area: area,
          count: 3,
          random: math.Random(seed),
        );
        expect(points, hasLength(3));
        for (final p in points) {
          expect(p.lat, inInclusiveRange(_baseLat, _baseLat + 0.002));
          expect(p.lng, inInclusiveRange(_baseLng, _baseLng + 0.0024));
        }
        for (var i = 0; i < points.length; i++) {
          for (var j = i + 1; j < points.length; j++) {
            expect(
              distanceMeters(
                points[i].lat,
                points[i].lng,
                points[j].lat,
                points[j].lng,
              ),
              greaterThanOrEqualTo(minSpotSeparationM),
            );
          }
        }
      }
    });

    test('エリアが3点未満なら空(ミッションは出ない)', () {
      expect(
        pickAccessPoints(
          area: area.take(2).toList(),
          count: 2,
          random: math.Random(1),
        ),
        isEmpty,
      );
    });
  });

  group('nearestOpenSpot', () {
    final mission = _mission(
      spots: [
        _spot(),
        _spot(id: 's1', northM: 100),
        _spot(id: 's2', northM: 200, claimedBy: 'x'),
      ],
    );

    test('空いている地点のうち一番近いもの(取られた地点は除く)', () {
      expect(nearestOpenSpot(mission, _at(_north(90)))?.id, 's1');
      expect(nearestOpenSpot(mission, _at(_north(190)))?.id, 's1');
      expect(nearestOpenSpot(mission, _at(_north(-10)))?.id, 's0');
    });

    test('位置が無ければ最初の空き、空きが無ければnull', () {
      expect(nearestOpenSpot(mission, null)?.id, 's0');
      expect(
        nearestOpenSpot(
          _mission(spots: [_spot(claimedBy: 'a')]),
          _at(_baseLat),
        ),
        isNull,
      );
    });
  });

  group('GPSの到着判定', () {
    final spot = _spot();

    test('半径15m以内は範囲内、外は範囲外。距離と精度も返す', () {
      final inside = readAccessPoint(
        spot: spot,
        location: _at(_north(10)),
      );
      expect(inside.fix, AccessPointFix.inside);
      expect(inside.distanceM, closeTo(10, 0.5));
      expect(inside.accuracyM, 5);

      final outside = readAccessPoint(
        spot: spot,
        location: _at(_north(20)),
      );
      expect(outside.fix, AccessPointFix.outside);
    });

    test('精度が30mより悪い・不明なときは判定しない(距離は出す)', () {
      final weak = readAccessPoint(
        spot: spot,
        location: _at(_north(5), accuracy: 31),
      );
      expect(weak.fix, AccessPointFix.weakGps);
      expect(weak.distanceM, isNotNull);
      expect(
        readAccessPoint(
          spot: spot,
          location: _at(_north(5), accuracy: 30),
        ).fix,
        AccessPointFix.inside,
      );
      expect(
        readAccessPoint(
          spot: spot,
          location: _at(_north(5), accuracy: null),
        ).fix,
        AccessPointFix.weakGps,
      );
    });

    test('位置が無ければnoFix', () {
      expect(
        readAccessPoint(spot: spot, location: null).fix,
        AccessPointFix.noFix,
      );
    });

    AccessPointReading reading(double meters, int at, {double accuracy = 5}) =>
        readAccessPoint(
          spot: spot,
          location: _at(_north(meters), accuracy: accuracy, updatedAt: at),
        );

    test('2回続けて範囲内になったら到着', () {
      var progress = advanceArrival(initialArrival, reading(5, 1));
      expect(progress.arrived, isFalse);
      progress = advanceArrival(progress, reading(6, 2));
      expect(progress.arrived, isTrue);
    });

    test('範囲外を挟むと数え直し', () {
      var progress = advanceArrival(initialArrival, reading(5, 1));
      progress = advanceArrival(progress, reading(40, 2));
      progress = advanceArrival(progress, reading(5, 3));
      expect(progress.arrived, isFalse);
      progress = advanceArrival(progress, reading(5, 4));
      expect(progress.arrived, isTrue);
    });

    test('精度が悪い読み取りを挟むと数え直し', () {
      var progress = advanceArrival(initialArrival, reading(5, 1));
      progress = advanceArrival(progress, reading(5, 2, accuracy: 50));
      progress = advanceArrival(progress, reading(5, 3));
      expect(progress.arrived, isFalse);
    });

    test('同じ読み取り(位置が更新されていない)は二重に数えない', () {
      var progress = advanceArrival(initialArrival, reading(5, 1));
      progress = advanceArrival(progress, reading(5, 1));
      expect(progress.arrived, isFalse);
      expect(progress.streak, 1);
    });

    test('到着した後に範囲の外へ出たら引けない。戻れば引ける(押す瞬間に確かめる)', () {
      var progress = advanceArrival(initialArrival, reading(5, 1));
      progress = advanceArrival(progress, reading(5, 2));
      expect(
        canClaimAccessPoint(arrival: progress, reading: reading(5, 3)),
        isTrue,
      );

      // 300m離れて隠れた。一度通っただけでは、離れた場所から引けない。
      expect(
        canClaimAccessPoint(arrival: progress, reading: reading(300, 4)),
        isFalse,
      );
      // 戻ってきたら、2回待たずにすぐ引ける。
      expect(
        canClaimAccessPoint(arrival: progress, reading: reading(8, 5)),
        isTrue,
      );
    });

    test('到着した後にGPSが弱くなっただけなら引ける(ブレでボタンを消さない)', () {
      var progress = advanceArrival(initialArrival, reading(5, 1));
      progress = advanceArrival(progress, reading(5, 2));
      expect(
        canClaimAccessPoint(
          arrival: progress,
          reading: reading(5, 3, accuracy: 45),
        ),
        isTrue,
      );
    });

    test('まだ到着していない・位置が無いときは引けない', () {
      final once = advanceArrival(initialArrival, reading(5, 1));
      expect(
        canClaimAccessPoint(arrival: once, reading: reading(5, 2)),
        isFalse,
      );
      var arrived = advanceArrival(once, reading(5, 2));
      arrived = advanceArrival(arrived, reading(5, 3));
      expect(
        canClaimAccessPoint(
          arrival: arrived,
          reading: readAccessPoint(spot: spot, location: null),
        ),
        isFalse,
      );
    });

    test('一度到着したら、範囲外になっても到着の記録は残る', () {
      var progress = advanceArrival(initialArrival, reading(5, 1));
      progress = advanceArrival(progress, reading(5, 2));
      progress = advanceArrival(progress, reading(80, 3));
      expect(progress.arrived, isTrue);
    });
  });

  group('先着のトランザクション(claimSpotUpdate)', () {
    Map<String, Object?> fresh() => {
      'round': 1,
      'createdAt': 1000,
      'expiresAt': 301000,
      'spots': {
        's0': {'lat': 1.0, 'lng': 1.0, 'radiusM': 15.0},
        's1': {'lat': 2.0, 'lng': 2.0, 'radiusM': 15.0},
      },
    };

    Map<dynamic, dynamic> spotOf(Object? mission, String id) =>
        ((mission! as Map)['spots'] as Map)[id] as Map;

    test('空いていれば自分のuidと時刻を入れる', () {
      final tx = claimSpotUpdate(
        fresh(),
        spotId: 's0',
        uid: 'a',
        nowMillis: 5000,
      );
      expect(tx.aborted, isFalse);
      expect(spotOf(tx.value, 's0'), containsPair('claimedBy', 'a'));
      expect(spotOf(tx.value, 's0'), containsPair('claimedAt', 5000));
      expect((tx.value! as Map)['finishedAt'], isNull);
    });

    test('2人が同じ地点を取り合っても、確定するのは先に通った1人だけ', () {
      // サーバーはトランザクションを1件ずつ適用する。Aが確定した後、
      // Bのハンドラはサーバーの最新値(Aが取った後)で呼び直される。
      final afterA = claimSpotUpdate(
        fresh(),
        spotId: 's0',
        uid: 'a',
        nowMillis: 5000,
      );
      final b = claimSpotUpdate(
        afterA.value,
        spotId: 's0',
        uid: 'b',
        nowMillis: 5001,
      );
      expect(b.aborted, isTrue);
    });

    test('ちがう地点なら2人とも取れて、埋まったらfinishedAtが入る', () {
      final afterA = claimSpotUpdate(
        fresh(),
        spotId: 's0',
        uid: 'a',
        nowMillis: 5000,
      );
      final afterB = claimSpotUpdate(
        afterA.value,
        spotId: 's1',
        uid: 'b',
        nowMillis: 6000,
      );
      expect(afterB.aborted, isFalse);
      expect((afterB.value! as Map)['finishedAt'], 6000);
    });

    test('1人で2つの地点は取れない', () {
      final afterA = claimSpotUpdate(
        fresh(),
        spotId: 's0',
        uid: 'a',
        nowMillis: 5000,
      );
      expect(
        claimSpotUpdate(
          afterA.value,
          spotId: 's1',
          uid: 'a',
          nowMillis: 6000,
        ).aborted,
        isTrue,
      );
    });

    test('期限が切れていたら中止', () {
      expect(
        claimSpotUpdate(
          fresh(),
          spotId: 's0',
          uid: 'a',
          nowMillis: 301000,
        ).aborted,
        isTrue,
      );
    });

    test('無い地点は中止', () {
      expect(
        claimSpotUpdate(
          fresh(),
          spotId: 's9',
          uid: 'a',
          nowMillis: 5000,
        ).aborted,
        isTrue,
      );
    });

    test('手元にキャッシュが無い(null)ときは、nullのまま成功を返して呼び直しを待つ', () {
      final tx = claimSpotUpdate(
        null,
        spotId: 's0',
        uid: 'a',
        nowMillis: 5000,
      );
      expect(tx.aborted, isFalse);
      expect(tx.value, isNull);
    });
  });
}
