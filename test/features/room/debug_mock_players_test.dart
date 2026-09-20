import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/debug_mock_players.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';

/// デバッグ用の偽プレイヤー(issue #67)のテスト。
///
/// `flutter test` はデバッグビルド相当(`kDebugMode`がtrue)で走るため、
/// ここでは実際に偽データが生成される側の挙動を確かめる。リリース
/// ビルドで空になることは、各関数の`if (!kDebugMode) return const []`と
/// 呼び出し側の`if (kDebugMode)`で担保している(テストからは検証できない)。
void main() {
  /// 東京駅付近。実際に遊ぶ緯度の代表として使う。
  const centerLatitude = 35.681236;
  const centerLongitude = 139.767125;

  /// 緯度1度あたりの距離(メートル)。
  const metersPerDegreeLatitude = 111320.0;

  double distanceFromCenterMeters(double latitude, double longitude) {
    final northMeters = (latitude - centerLatitude) * metersPerDegreeLatitude;
    final eastMeters =
        (longitude - centerLongitude) *
        metersPerDegreeLatitude *
        cos(centerLatitude * pi / 180);
    return sqrt(northMeters * northMeters + eastMeters * eastMeters);
  }

  List<RoomUser> usersFor(UserRole myRole) => debugMockUsers(myRole: myRole);

  group('debugMockUsers', () {
    test('5人ぶん生成される', () {
      expect(usersFor(UserRole.demon).length, debugMockPlayerCount);
      expect(debugMockPlayerCount, 5);
    });

    test('役割は自分の逆になる', () {
      expect(
        usersFor(UserRole.demon).map((u) => u.role),
        everyElement(UserRole.fugitive),
      );
      expect(
        usersFor(UserRole.fugitive).map((u) => u.role),
        everyElement(UserRole.demon),
      );
    });

    test('名前は空でなく、uidは実在のuidと紛れない接頭辞を持つ', () {
      for (final user in usersFor(UserRole.demon)) {
        expect(user.displayName, isNotEmpty);
        expect(user.id, startsWith('debug-mock-'));
      }
    });
  });

  test('4種類の偽データが同じ5人ぶん揃っている', () {
    final uids = usersFor(UserRole.demon).map((u) => u.id).toList();

    expect(uids, debugMockPlayerUids);
    expect(debugMockWifiEntries().map((e) => e.uid).toList(), uids);
    expect(debugMockVerticalPositions().map((p) => p.uid).toList(), uids);
    expect(
      debugMockLocations(
        centerLatitude: centerLatitude,
        centerLongitude: centerLongitude,
      ).map((l) => l.uid).toList(),
      uids,
    );
  });

  test('Wi-Fi判定は「近い/遠い/検知なし」が混ざる', () {
    final levels = debugMockWifiEntries().map((e) => e.level).toSet();

    expect(levels, containsAll(ProximityLevel.values));
  });

  test('上下は「上・下・ほぼ同じ高さ」が混ざる', () {
    final deltas = debugMockVerticalPositions()
        .map((p) => p.deltaMeters)
        .toList();

    expect(deltas.any((d) => d > 1), isTrue, reason: '自分より上の相手が要る');
    expect(deltas.any((d) => d < -1), isTrue, reason: '自分より下の相手が要る');
    expect(deltas.any((d) => d.abs() <= 1), isTrue, reason: 'ほぼ同じ高さの相手が要る');
    // 上下バーの表示範囲(±20m)を振り切らない値にしてある。
    expect(deltas.every((d) => d.abs() < 20), isTrue);
  });

  test('位置は自分の周りに散らばる', () {
    final locations = debugMockLocations(
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
    );

    for (final location in locations) {
      final distance = distanceFromCenterMeters(
        location.latitude,
        location.longitude,
      );
      expect(distance, greaterThanOrEqualTo(30.0));
      expect(distance, lessThanOrEqualTo(120.0));
    }
    // 全員が同じ場所に重なっていない。
    final points = locations.map((l) => '${l.latitude},${l.longitude}').toSet();
    expect(points.length, debugMockPlayerCount);
  });

  test('中心は自分の現在地を優先し、無ければフォールバックを使う', () {
    final locations = debugMockLocations(
      centerLatitude: centerLatitude,
      centerLongitude: centerLongitude,
    );
    final center = debugMockCenterOf(
      locations: locations,
      myUid: debugMockPlayerUids.first,
      fallbackLatitude: 0,
      fallbackLongitude: 0,
    );
    expect(center.latitude, locations.first.latitude);
    expect(center.longitude, locations.first.longitude);

    final fallback = debugMockCenterOf(
      locations: locations,
      myUid: 'not-in-the-list',
      fallbackLatitude: centerLatitude,
      fallbackLongitude: centerLongitude,
    );
    expect(fallback.latitude, centerLatitude);
    expect(fallback.longitude, centerLongitude);
  });

  group('固定シード', () {
    test('同じシードなら何度呼んでも同じ値になる(毎秒のリビルドでちらつかない)', () {
      expect(debugMockUsers(myRole: UserRole.demon), usersFor(UserRole.demon));
      expect(debugMockWifiEntries(), debugMockWifiEntries());
      expect(debugMockVerticalPositions(), debugMockVerticalPositions());
      expect(
        debugMockLocations(
          centerLatitude: centerLatitude,
          centerLongitude: centerLongitude,
        ),
        debugMockLocations(
          centerLatitude: centerLatitude,
          centerLongitude: centerLongitude,
        ),
      );
    });

    test('シードを変えれば別の並びになる(乱数が効いている)', () {
      expect(
        debugMockVerticalPositions(seed: debugMockPlayerSeed + 1),
        isNot(debugMockVerticalPositions()),
      );
      expect(
        debugMockLocations(
          centerLatitude: centerLatitude,
          centerLongitude: centerLongitude,
          seed: debugMockPlayerSeed + 1,
        ),
        isNot(
          debugMockLocations(
            centerLatitude: centerLatitude,
            centerLongitude: centerLongitude,
          ),
        ),
      );
    });
  });
}
