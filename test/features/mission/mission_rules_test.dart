import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/mission/mission_rules.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';

/// 名古屋あたりの基準点。緯度1度 ≒ 111km、経度1度 ≒ 91km(北緯35度)。
const _baseLat = 35.1830;
const _baseLng = 137.1130;

/// 北へ[meters]進んだ緯度。
double _north(double meters) => _baseLat + meters / 111320;

Mission _accessPoint({
  String id = 'm1',
  int createdAt = 100000,
  int? expiresAt,
  String? claimedBy,
  int? claimedAt,
}) => Mission(
  id: id,
  type: MissionType.accessPoint,
  createdAt: createdAt,
  expiresAt: expiresAt ?? createdAt + 180000,
  lat: _baseLat,
  lng: _baseLng,
  radiusM: accessPointRadiusM,
  claimedBy: claimedBy,
  claimedAt: claimedAt,
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
  group('missionsOfCurrentGame', () {
    test('開始前のミッション(前のゲームの残り)を除き、古い順に並べる', () {
      final result = missionsOfCurrentGame(
        [
          _accessPoint(id: 'new', createdAt: 5000),
          _accessPoint(id: 'old', createdAt: 500),
          _accessPoint(id: 'mid', createdAt: 2000),
        ],
        startedAt: 1000,
      );
      expect(result.map((m) => m.id), ['mid', 'new']);
    });

    test('開始前(startedAtがnull)なら空', () {
      expect(
        missionsOfCurrentGame([_accessPoint()], startedAt: null),
        isEmpty,
      );
    });
  });

  group('期限切れの判定', () {
    test('expiresAtの直前は切れていない、ちょうどから切れている', () {
      final mission = _accessPoint(expiresAt: 10000);
      expect(isMissionExpired(mission, nowMillis: 9999), isFalse);
      expect(isMissionExpired(mission, nowMillis: 10000), isTrue);
    });

    test('アクセスポイントは取られたら受けられない', () {
      expect(
        isMissionActive(
          _accessPoint(claimedBy: 'a', claimedAt: 110000),
          nowMillis: 120000,
        ),
        isFalse,
      );
    });

    test('「鬼に近づけ」は期限まで受けられる', () {
      const mission = Mission(
        id: 'a',
        type: MissionType.approachDemon,
        createdAt: 0,
        expiresAt: 120000,
      );
      expect(isMissionActive(mission, nowMillis: 119999), isTrue);
      expect(isMissionActive(mission, nowMillis: 120000), isFalse);
    });

    test('currentMissionは期限切れならnull、取られて15秒たったらnull', () {
      final expired = _accessPoint(createdAt: 1000, expiresAt: 5000);
      expect(
        currentMission([expired], startedAt: 0, nowMillis: 5000),
        isNull,
      );
      final claimed = _accessPoint(
        createdAt: 1000,
        claimedBy: 'a',
        claimedAt: 2000,
      );
      expect(
        currentMission([claimed], startedAt: 0, nowMillis: 16999),
        isNotNull,
      );
      expect(
        currentMission([claimed], startedAt: 0, nowMillis: 17000),
        isNull,
      );
    });
  });

  group('shouldCreateMission', () {
    const releasedAt = 100000;

    bool should(List<Mission> missions, int now, {int? endsAt}) =>
        shouldCreateMission(
          missions: missions,
          startedAt: 0,
          releasedAt: releasedAt,
          endsAt: endsAt,
          nowMillis: now,
        );

    test('放出前・放出から30秒未満は書かない、30秒で1件目を書く', () {
      expect(
        shouldCreateMission(
          missions: const [],
          startedAt: 0,
          releasedAt: null,
          endsAt: null,
          nowMillis: 999999,
        ),
        isFalse,
      );
      expect(should(const [], releasedAt + 29999), isFalse);
      expect(should(const [], releasedAt + 30000), isTrue);
    });

    test('受けられるミッションがあれば書かない(同時に1件だけ)', () {
      final active = _accessPoint(createdAt: 130000);
      expect(should([active], 200000), isFalse);
    });

    test('期限が切れてから60秒あけて次を書く', () {
      final mission = _accessPoint(createdAt: 130000, expiresAt: 310000);
      expect(should([mission], 369999), isFalse);
      expect(should([mission], 370000), isTrue);
    });

    test('取られたら、取られた時刻から60秒あけて次を書く', () {
      final mission = _accessPoint(
        createdAt: 130000,
        claimedBy: 'a',
        claimedAt: 150000,
      );
      expect(should([mission], 209999), isFalse);
      expect(should([mission], 210000), isTrue);
    });

    test('ゲームが終わっていたら書かない', () {
      expect(should(const [], 200000, endsAt: 200000), isFalse);
    });
  });

  group('pickMissionPoint', () {
    // 約220m四方のエリア。
    final area = [
      const LatLng(lat: _baseLat, lng: _baseLng),
      const LatLng(lat: _baseLat, lng: _baseLng + 0.0024),
      const LatLng(lat: _baseLat + 0.002, lng: _baseLng + 0.0024),
      const LatLng(lat: _baseLat + 0.002, lng: _baseLng),
    ];

    test('エリアの中で、前回から50m以上離れた点を選ぶ', () {
      final random = math.Random(1);
      const previous = LatLng(lat: _baseLat + 0.001, lng: _baseLng + 0.0012);
      for (var i = 0; i < 50; i++) {
        final point = pickMissionPoint(
          area: area,
          previous: previous,
          random: random,
        )!;
        expect(point.lat, inInclusiveRange(_baseLat, _baseLat + 0.002));
        expect(point.lng, inInclusiveRange(_baseLng, _baseLng + 0.0024));
        expect(
          distanceMeters(previous.lat, previous.lng, point.lat, point.lng),
          greaterThanOrEqualTo(minMissionPointSeparationM),
        );
      }
    });

    test('エリアが3点未満ならnull(地点を置けない)', () {
      expect(
        pickMissionPoint(
          area: area.take(2).toList(),
          previous: null,
          random: math.Random(1),
        ),
        isNull,
      );
    });

    test('エリアが無ければ種類は「鬼に近づけ」だけ', () {
      for (var seed = 0; seed < 10; seed++) {
        expect(
          chooseMissionType(area: const [], random: math.Random(seed)),
          MissionType.approachDemon,
        );
      }
    });
  });

  group('GPSの到着判定', () {
    final mission = _accessPoint();

    test('半径15m以内は範囲内、外は範囲外。距離と精度も返す', () {
      final inside = readAccessPoint(
        mission: mission,
        location: _at(_north(10)),
      );
      expect(inside.fix, AccessPointFix.inside);
      expect(inside.distanceM, closeTo(10, 0.5));
      expect(inside.accuracyM, 5);

      final outside = readAccessPoint(
        mission: mission,
        location: _at(_north(20)),
      );
      expect(outside.fix, AccessPointFix.outside);
    });

    test('精度が30mより悪い・不明なときは判定しない(距離は出す)', () {
      final weak = readAccessPoint(
        mission: mission,
        location: _at(_north(5), accuracy: 31),
      );
      expect(weak.fix, AccessPointFix.weakGps);
      expect(weak.distanceM, isNotNull);
      expect(
        readAccessPoint(
          mission: mission,
          location: _at(_north(5), accuracy: 30),
        ).fix,
        AccessPointFix.inside,
      );
      expect(
        readAccessPoint(
          mission: mission,
          location: _at(_north(5), accuracy: null),
        ).fix,
        AccessPointFix.weakGps,
      );
    });

    test('位置が無ければnoFix', () {
      expect(
        readAccessPoint(mission: mission, location: null).fix,
        AccessPointFix.noFix,
      );
    });

    AccessPointReading reading(double meters, int at, {double accuracy = 5}) =>
        readAccessPoint(
          mission: mission,
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
          reading: readAccessPoint(mission: mission, location: null),
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

  group('先着1名のトランザクション(claimMissionUpdate)', () {
    Map<String, Object?> unclaimed() => {
      'type': 'access_point',
      'createdAt': 1000,
      'expiresAt': 181000,
    };

    test('未取得なら自分のuidと時刻を入れる', () {
      final tx = claimMissionUpdate(unclaimed(), uid: 'a', nowMillis: 5000);
      expect(tx.aborted, isFalse);
      expect(tx.value, containsPair('claimedBy', 'a'));
      expect(tx.value, containsPair('claimedAt', 5000));
    });

    test('2人が同じ値から取り合っても、確定するのは先に通った1人だけ', () {
      // サーバーはトランザクションを1件ずつ適用する。Aが確定した後、
      // Bのハンドラはサーバーの最新値(Aが取った後)で呼び直される。
      final afterA = claimMissionUpdate(unclaimed(), uid: 'a', nowMillis: 5000);
      expect(afterA.aborted, isFalse);
      final b = claimMissionUpdate(afterA.value, uid: 'b', nowMillis: 5001);
      expect(b.aborted, isTrue);
    });

    test('期限が切れていたら中止', () {
      expect(
        claimMissionUpdate(unclaimed(), uid: 'a', nowMillis: 181000).aborted,
        isTrue,
      );
    });

    test('手元にキャッシュが無い(null)ときは、nullのまま成功を返して呼び直しを待つ', () {
      final tx = claimMissionUpdate(null, uid: 'a', nowMillis: 5000);
      expect(tx.aborted, isFalse);
      expect(tx.value, isNull);
    });
  });

  group('「鬼に近づけ」の達成', () {
    test('反応なし → 反応あり で達成', () {
      var progress = advanceApproach(initialApproach, anyDemonClose: false);
      expect(progress.achieved, isFalse);
      progress = advanceApproach(progress, anyDemonClose: true);
      expect(progress.achieved, isTrue);
    });

    test('最初から反応ありのときは、一度なしを経るまで達成しない', () {
      var progress = advanceApproach(initialApproach, anyDemonClose: true);
      expect(progress.achieved, isFalse);
      progress = advanceApproach(progress, anyDemonClose: true);
      expect(progress.achieved, isFalse);
      progress = advanceApproach(progress, anyDemonClose: false);
      progress = advanceApproach(progress, anyDemonClose: true);
      expect(progress.achieved, isTrue);
    });

    test('達成した後に反応がなくなっても達成のまま', () {
      var progress = advanceApproach(initialApproach, anyDemonClose: false);
      progress = advanceApproach(progress, anyDemonClose: true);
      progress = advanceApproach(progress, anyDemonClose: false);
      expect(progress.achieved, isTrue);
    });
  });

  test('wifiOverlapMetrics: 判定と同じ前処理(集約・弱い電波の除外)で数える', () {
    final metrics = wifiOverlapMetrics(
      {
        'aa:aa:aa:aa:aa:a1': -50,
        'aa:aa:aa:aa:aa:a2': -55, // 同じ物理AP(末尾だけ違う)
        'bb:bb:bb:bb:bb:b1': -60,
        'cc:cc:cc:cc:cc:c1': -95, // 弱すぎるので除外
      },
      {'aa:aa:aa:aa:aa:a1': -54, 'dd:dd:dd:dd:dd:d1': -70},
    );
    expect(metrics.selfCount, 2);
    expect(metrics.commonCount, 1);
    expect(metrics.medianDiffDbm, 4);
  });

  test('firstCloseUid: 候補の順に見て、最初に「反応あり」の相手を返す', () {
    const entries = [
      WifiProximityEntry(uid: 'a', level: ProximityLevel.far),
      WifiProximityEntry(uid: 'b', level: ProximityLevel.close),
      WifiProximityEntry(uid: 'c', level: ProximityLevel.close),
    ];
    expect(firstCloseUid(entries, ['a', 'c', 'b']), 'c');
    expect(firstCloseUid(entries, ['a']), isNull);
  });
}
