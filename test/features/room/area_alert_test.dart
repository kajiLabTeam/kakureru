import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/repository/location_smoothing.dart';
import 'package:kakureru/features/room/area_alert.dart';
import 'package:kakureru/features/room/model/room_setting.dart';

/// エリア外アラートの判定ロジック(issue #61)のテスト。
///
/// 距離・方位の計算にlatlong2の`Distance`(純粋Dart)を使っているため、
/// 端末もプラグインも無しにここで直接検証できる。
void main() {
  // 北緯35度・東経135度付近の矩形(約182m × 222m)。
  // 頂点は左下→右下→右上→左上(rectangle_area.dartが作る順序と同じ)。
  const area = [
    LatLng(lat: 35, lng: 135),
    LatLng(lat: 35, lng: 135.002),
    LatLng(lat: 35.002, lng: 135.002),
    LatLng(lat: 35.002, lng: 135),
  ];

  group('isInsideArea', () {
    test('矩形の内側ならtrue', () {
      expect(
        isInsideArea(
          area: area,
          point: const LatLng(lat: 35.001, lng: 135.001),
        ),
        isTrue,
      );
    });

    test('矩形の外側(東・西・北・南)ならfalse', () {
      const outside = [
        LatLng(lat: 35.001, lng: 135.003), // 東
        LatLng(lat: 35.001, lng: 134.999), // 西
        LatLng(lat: 35.003, lng: 135.001), // 北
        LatLng(lat: 34.999, lng: 135.001), // 南
      ];
      for (final point in outside) {
        expect(
          isInsideArea(area: area, point: point),
          isFalse,
          reason: '$point は矩形の外',
        );
      }
    });

    test('頂点の上は内側として扱う', () {
      for (final vertex in area) {
        expect(
          isInsideArea(area: area, point: vertex),
          isTrue,
          reason: '$vertex は頂点',
        );
      }
    });

    test('辺の上は内側として扱う', () {
      const onEdges = [
        LatLng(lat: 35, lng: 135.001), // 南辺
        LatLng(lat: 35.002, lng: 135.001), // 北辺
        LatLng(lat: 35.001, lng: 135), // 西辺
        LatLng(lat: 35.001, lng: 135.002), // 東辺
      ];
      for (final point in onEdges) {
        expect(
          isInsideArea(area: area, point: point),
          isTrue,
          reason: '$point は辺の上',
        );
      }
    });

    test('エリア未設定(空・2点)なら常に内側として扱う', () {
      const faraway = LatLng(lat: 0, lng: 0);
      expect(isInsideArea(area: const [], point: faraway), isTrue);
      expect(
        isInsideArea(
          area: const [
            LatLng(lat: 35, lng: 135),
            LatLng(lat: 35.002, lng: 135),
          ],
          point: faraway,
        ),
        isTrue,
      );
    });

    test('凹多角形のへこみ部分は外側と判定する(ray castingの確認)', () {
      // 「コ」の字型。右側の中央がへこんでいる。
      const concave = [
        LatLng(lat: 35, lng: 135),
        LatLng(lat: 35, lng: 135.004),
        LatLng(lat: 35.001, lng: 135.004),
        LatLng(lat: 35.001, lng: 135.002),
        LatLng(lat: 35.003, lng: 135.002),
        LatLng(lat: 35.003, lng: 135.004),
        LatLng(lat: 35.004, lng: 135.004),
        LatLng(lat: 35.004, lng: 135),
      ];
      expect(
        isInsideArea(
          area: concave,
          point: const LatLng(lat: 35.002, lng: 135.003),
        ),
        isFalse,
      );
      expect(
        isInsideArea(
          area: concave,
          point: const LatLng(lat: 35.002, lng: 135.001),
        ),
        isTrue,
      );
    });
  });

  group('describeReturnToArea', () {
    test('内側ならnull', () {
      expect(
        describeReturnToArea(
          area: area,
          point: const LatLng(lat: 35.001, lng: 135.001),
        ),
        isNull,
      );
    });

    test('エリア未設定ならnull(警告を出さない)', () {
      expect(
        describeReturnToArea(
          area: const [],
          point: const LatLng(lat: 0, lng: 0),
        ),
        isNull,
      );
    });

    test('東へはみ出したら、西向き・東辺までの距離を返す', () {
      final result = describeReturnToArea(
        area: area,
        point: const LatLng(lat: 35.001, lng: 135.003),
      )!;
      // 北緯35度で経度0.001度は約91m。
      expect(result.meters, closeTo(91, 3));
      expect(result.bearingDegrees, closeTo(270, 0.5));
    });

    test('北へはみ出したら、南向き・北辺までの距離を返す', () {
      final result = describeReturnToArea(
        area: area,
        point: const LatLng(lat: 35.003, lng: 135.001),
      )!;
      // 緯度0.001度は約111m。
      expect(result.meters, closeTo(111, 3));
      expect(result.bearingDegrees, closeTo(180, 0.5));
    });

    test('角の外側では、最も近い頂点へ戻る向きになる', () {
      final result = describeReturnToArea(
        area: area,
        point: const LatLng(lat: 35.003, lng: 135.003),
      )!;
      // 北東の頂点(35.002, 135.002)へ戻るので、南西向き・約144m。
      expect(result.meters, closeTo(144, 4));
      // 南西の方角(202.5〜247.5度)。北緯35度では経度1度の方が短いので、
      // 対角はちょうど225度にはならない。
      expect(result.bearingDegrees, inInclusiveRange(202.5, 247.5));
    });

    test('遠ざかるほど距離が伸びる', () {
      double metersAt(double lng) => describeReturnToArea(
        area: area,
        point: LatLng(lat: 35.001, lng: lng),
      )!.meters;
      expect(metersAt(135.005), greaterThan(metersAt(135.003)));
    });
  });

  group('observeOutsideArea', () {
    // サーバー時刻のつもりの固定値(実際の値に意味は無い)。
    const nowMillis = 1800000000000;

    UserLocation locationAt({
      required double lat,
      required double lng,
      double? accuracy,
      int? updatedAt,
    }) => UserLocation(
      uid: 'me',
      latitude: lat,
      longitude: lng,
      accuracy: accuracy,
      updatedAt: updatedAt ?? nowMillis,
    );

    test('新しい位置がエリア内ならinside', () {
      final observation = observeOutsideArea(
        area: area,
        location: locationAt(lat: 35.001, lng: 135.001),
        nowMillis: nowMillis,
      );
      expect(observation.status, OutsideAreaStatus.inside);
    });

    test('新しい位置がエリア外なら、距離・方位・精度を載せてoutside', () {
      final observation = observeOutsideArea(
        area: area,
        // 北へ約111mはみ出した位置。南へ戻る。
        location: locationAt(lat: 35.003, lng: 135.001, accuracy: 7),
        nowMillis: nowMillis,
      );
      expect(observation.status, OutsideAreaStatus.outside);
      expect(observation.outsideMeters, closeTo(111, 1));
      expect(observation.bearingDegrees, closeTo(180, 0.5));
      expect(observation.accuracyMeters, 7);
      expect(observation.updatedAt, nowMillis);
    });

    test('自分の位置がまだ届いていなければunknown(エリア内と同一視しない)', () {
      final observation = observeOutsideArea(
        area: area,
        location: null,
        nowMillis: nowMillis,
      );
      expect(observation.status, OutsideAreaStatus.unknown);
    });

    test('ルーム情報が取れていなければunknown', () {
      final observation = observeOutsideArea(
        area: null,
        location: locationAt(lat: 35.003, lng: 135.001),
        nowMillis: nowMillis,
      );
      expect(observation.status, OutsideAreaStatus.unknown);
    });

    test('古い位置は判定に使わずunknown(送信が止まった端末の座標で固定されない)', () {
      final justFresh = observeOutsideArea(
        area: area,
        location: locationAt(
          lat: 35.003,
          lng: 135.001,
          updatedAt: nowMillis - outsideAreaLocationStaleAfter.inMilliseconds,
        ),
        nowMillis: nowMillis,
      );
      expect(justFresh.status, OutsideAreaStatus.outside);

      final stale = observeOutsideArea(
        area: area,
        location: locationAt(
          lat: 35.003,
          lng: 135.001,
          updatedAt:
              nowMillis - outsideAreaLocationStaleAfter.inMilliseconds - 1,
        ),
        nowMillis: nowMillis,
      );
      expect(stale.status, OutsideAreaStatus.unknown);
    });

    test('updatedAtが入っていない位置はunknown', () {
      final observation = observeOutsideArea(
        area: area,
        location: locationAt(lat: 35.003, lng: 135.001, updatedAt: 0),
        nowMillis: nowMillis,
      );
      expect(observation.status, OutsideAreaStatus.unknown);
    });

    test('エリア未設定のルームでは、どこにいてもinside', () {
      final observation = observeOutsideArea(
        area: const [],
        location: locationAt(lat: 0, lng: 0),
        nowMillis: nowMillis,
      );
      expect(observation.status, OutsideAreaStatus.inside);
    });
  });

  group('outsideAreaAccuracyAllowanceMeters', () {
    test('報告された精度ぶん猶予を広げる', () {
      expect(outsideAreaAccuracyAllowanceMeters(12), 12);
    });

    test('精度不明(0.0)は足切りの上限を最悪値として使う', () {
      expect(
        outsideAreaAccuracyAllowanceMeters(0),
        LocationFilterThresholds.maxAcceptableAccuracyM,
      );
    });

    test('強制採用で通った極端な精度は上限でクランプする', () {
      expect(
        outsideAreaAccuracyAllowanceMeters(2000),
        LocationFilterThresholds.maxAcceptableAccuracyM,
      );
    });
  });

  group('applyOutsideAreaHysteresis', () {
    final t0 = DateTime.utc(2026, 9, 20, 12);

    // 観測の組み立て。updatedAtは「何番目の測位か」が分かればよいので
    // 小さい連番で表す(判定は大小関係しか見ない)。
    OutsideAreaObservation outside({
      required double meters,
      double accuracy = 5,
      int fix = 1,
    }) => (
      status: OutsideAreaStatus.outside,
      outsideMeters: meters,
      bearingDegrees: 180,
      accuracyMeters: accuracy,
      updatedAt: fix,
    );
    OutsideAreaObservation inside({int fix = 1}) => (
      status: OutsideAreaStatus.inside,
      outsideMeters: 0,
      bearingDegrees: 0,
      accuracyMeters: 0,
      updatedAt: fix,
    );

    // 猶予距離(15m)に精度5m分を足した実効の猶予距離。
    const grace = outsideAreaGraceDistanceMeters + 5;

    test('エリア内なら警告せず、経過時間の計測もリセットする', () {
      final result = applyOutsideAreaHysteresis(
        observation: inside(),
        previous: (
          isWarning: false,
          outsideSince: t0,
          outsideSinceUpdatedAt: 1,
          lastKnownAt: t0,
        ),
        now: t0.add(const Duration(minutes: 1)),
      );
      expect(result.isWarning, isFalse);
      expect(result.outsideSince, isNull);
    });

    test('警告中でもエリア内に戻ったら即座に解除する', () {
      final result = applyOutsideAreaHysteresis(
        observation: inside(),
        previous: (
          isWarning: true,
          outsideSince: t0,
          outsideSinceUpdatedAt: 1,
          lastKnownAt: t0,
        ),
        now: t0.add(const Duration(minutes: 5)),
      );
      expect(result.isWarning, isFalse);
      expect(result.outsideSince, isNull);
    });

    test('猶予距離未満のはみ出しは、どれだけ続いても警告しない', () {
      var state = initialOutsideAreaWarningState;
      for (var i = 0; i < 60; i++) {
        state = applyOutsideAreaHysteresis(
          observation: outside(meters: grace - 0.1, fix: i),
          previous: state,
          now: t0.add(Duration(seconds: i)),
        );
      }
      expect(state.isWarning, isFalse);
      expect(state.outsideSince, isNull);
    });

    test('猶予距離ちょうどは「外」として計測を始める', () {
      final result = applyOutsideAreaHysteresis(
        observation: outside(meters: grace),
        previous: initialOutsideAreaWarningState,
        now: t0,
      );
      expect(result.isWarning, isFalse);
      expect(result.outsideSince, t0);
    });

    test('報告された精度のぶん猶予距離が広がる(誤差25mでエリア内10mの人を警告しない)', () {
      // 精度25mの測位で、境界から30mはみ出して見えている状態。
      // 15m + 25m = 40m に届かないので、計測すら始めない。
      final blurred = applyOutsideAreaHysteresis(
        observation: outside(meters: 30, accuracy: 25),
        previous: initialOutsideAreaWarningState,
        now: t0,
      );
      expect(blurred.outsideSince, isNull);

      // 同じ30mでも、精度が良ければ(誤差5m)計測を始める。
      final sharp = applyOutsideAreaHysteresis(
        observation: outside(meters: 30),
        previous: initialOutsideAreaWarningState,
        now: t0,
      );
      expect(sharp.outsideSince, t0);
    });

    test('精度不明(0.0)は最悪値として扱い、猶予距離を上限ぶん広げる', () {
      final justUnder = applyOutsideAreaHysteresis(
        observation: outside(
          meters:
              outsideAreaGraceDistanceMeters +
              LocationFilterThresholds.maxAcceptableAccuracyM -
              0.1,
          accuracy: 0,
        ),
        previous: initialOutsideAreaWarningState,
        now: t0,
      );
      expect(justUnder.outsideSince, isNull);

      final over = applyOutsideAreaHysteresis(
        observation: outside(
          meters:
              outsideAreaGraceDistanceMeters +
              LocationFilterThresholds.maxAcceptableAccuracyM,
          accuracy: 0,
        ),
        previous: initialOutsideAreaWarningState,
        now: t0,
      );
      expect(over.outsideSince, t0);
    });

    test('猶予時間の直前は警告せず、新しい測位つきでちょうど経過したら警告する', () {
      final started = applyOutsideAreaHysteresis(
        observation: outside(meters: 50),
        previous: initialOutsideAreaWarningState,
        now: t0,
      );

      final justBefore = applyOutsideAreaHysteresis(
        observation: outside(meters: 50, fix: 2),
        previous: started,
        now: t0.add(outsideAreaGraceDuration - const Duration(milliseconds: 1)),
      );
      expect(justBefore.isWarning, isFalse);
      expect(justBefore.outsideSince, t0);

      final exactly = applyOutsideAreaHysteresis(
        observation: outside(meters: 50, fix: 2),
        previous: started,
        now: t0.add(outsideAreaGraceDuration),
      );
      expect(exactly.isWarning, isTrue);
    });

    test('猶予のあいだ新しい測位が来ていなければ、時間が経っても警告しない', () {
      // マルチパスで飛んだ1点(fix: 1)が採用されたあと、後続が精度足切りで
      // 棄却され続けてRTDBのupdatedAtが進まないケース。
      var state = applyOutsideAreaHysteresis(
        observation: outside(meters: 50),
        previous: initialOutsideAreaWarningState,
        now: t0,
      );
      for (var i = 1; i <= 30; i++) {
        state = applyOutsideAreaHysteresis(
          observation: outside(meters: 50),
          previous: state,
          now: t0.add(Duration(seconds: i)),
        );
      }
      expect(state.isWarning, isFalse);
      expect(state.outsideSince, t0);

      // 新しい測位が届いた時点で、初めて警告になる。
      final withNewFix = applyOutsideAreaHysteresis(
        observation: outside(meters: 50, fix: 2),
        previous: state,
        now: t0.add(const Duration(seconds: 31)),
      );
      expect(withNewFix.isWarning, isTrue);
    });

    test('途中で猶予距離の内側に戻ると、経過時間の計測をやり直す', () {
      final started = applyOutsideAreaHysteresis(
        observation: outside(meters: 50),
        previous: initialOutsideAreaWarningState,
        now: t0,
      );
      expect(started.outsideSince, t0);

      final interrupted = applyOutsideAreaHysteresis(
        observation: outside(meters: 1, fix: 2),
        previous: started,
        now: t0.add(const Duration(seconds: 5)),
      );
      expect(interrupted.isWarning, isFalse);
      expect(interrupted.outsideSince, isNull);

      // 再び外へ出た時点から数え直すので、最初の t0 から猶予時間が
      // 経っていても、まだ警告にはならない。
      final restarted = applyOutsideAreaHysteresis(
        observation: outside(meters: 50, fix: 3),
        previous: interrupted,
        now: t0.add(const Duration(seconds: 6)),
      );
      expect(restarted.isWarning, isFalse);
      expect(restarted.outsideSince, t0.add(const Duration(seconds: 6)));
    });

    test('一度警告に入ったら、猶予距離の内側に戻っただけでは解除しない', () {
      final result = applyOutsideAreaHysteresis(
        observation: outside(meters: 1, fix: 9),
        previous: (
          isWarning: true,
          outsideSince: t0,
          outsideSinceUpdatedAt: 1,
          lastKnownAt: t0,
        ),
        now: t0.add(const Duration(seconds: 30)),
      );
      expect(result.isWarning, isTrue);
    });

    test('測位が毎秒届いていれば、猶予時間ちょうどで警告に変わる', () {
      var state = initialOutsideAreaWarningState;
      final switchedAt = <int>[];
      for (var i = 0; i <= outsideAreaGraceDuration.inSeconds + 2; i++) {
        final next = applyOutsideAreaHysteresis(
          observation: outside(meters: 30, fix: i + 1),
          previous: state,
          now: t0.add(Duration(seconds: i)),
        );
        if (!state.isWarning && next.isWarning) switchedAt.add(i);
        state = next;
      }
      expect(switchedAt, [outsideAreaGraceDuration.inSeconds]);
    });

    test('判定に使える位置が無い間は、警告も猶予の計測もそのまま保つ', () {
      // 猶予の計測中にデータが一瞬欠けても、0から数え直さない。
      final started = applyOutsideAreaHysteresis(
        observation: outside(meters: 50),
        previous: initialOutsideAreaWarningState,
        now: t0,
      );
      final gapped = applyOutsideAreaHysteresis(
        observation: unknownOutsideAreaObservation,
        previous: started,
        now: t0.add(const Duration(seconds: 3)),
      );
      expect(gapped.outsideSince, t0);

      // 警告中に欠けても、警告は消えない(機内モードで逃げられない)。
      final warning = applyOutsideAreaHysteresis(
        observation: unknownOutsideAreaObservation,
        previous: (
          isWarning: true,
          outsideSince: t0,
          outsideSinceUpdatedAt: 1,
          lastKnownAt: t0,
        ),
        now: t0.add(const Duration(seconds: 3)),
      );
      expect(warning.isWarning, isTrue);
    });

    test('欠けが続いて保持時間を超えたら、警告を解除する(永久に振動させない)', () {
      final previous = (
        isWarning: true,
        outsideSince: t0,
        outsideSinceUpdatedAt: 1,
        lastKnownAt: t0,
      );

      final held = applyOutsideAreaHysteresis(
        observation: unknownOutsideAreaObservation,
        previous: previous,
        now: t0.add(
          outsideAreaUnknownHoldDuration - const Duration(seconds: 1),
        ),
      );
      expect(held.isWarning, isTrue);

      final released = applyOutsideAreaHysteresis(
        observation: unknownOutsideAreaObservation,
        previous: previous,
        now: t0.add(outsideAreaUnknownHoldDuration),
      );
      expect(released.isWarning, isFalse);
      expect(released.outsideSince, isNull);
    });

    test('一度も判定できていなければ、欠けが続いても警告しない', () {
      var state = initialOutsideAreaWarningState;
      for (var i = 0; i < 120; i++) {
        state = applyOutsideAreaHysteresis(
          observation: unknownOutsideAreaObservation,
          previous: state,
          now: t0.add(Duration(seconds: i)),
        );
      }
      expect(state.isWarning, isFalse);
    });
  });
}
