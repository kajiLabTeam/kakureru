import 'package:flutter_test/flutter_test.dart';
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
      expect(compassLabel(result.bearingDegrees), '西');
    });

    test('北へはみ出したら、南向き・北辺までの距離を返す', () {
      final result = describeReturnToArea(
        area: area,
        point: const LatLng(lat: 35.003, lng: 135.001),
      )!;
      // 緯度0.001度は約111m。
      expect(result.meters, closeTo(111, 3));
      expect(result.bearingDegrees, closeTo(180, 0.5));
      expect(compassLabel(result.bearingDegrees), '南');
    });

    test('角の外側では、最も近い頂点へ戻る向きになる', () {
      final result = describeReturnToArea(
        area: area,
        point: const LatLng(lat: 35.003, lng: 135.003),
      )!;
      // 北東の頂点(35.002, 135.002)へ戻るので、南西向き・約144m。
      expect(result.meters, closeTo(144, 4));
      expect(compassLabel(result.bearingDegrees), '南西');
    });

    test('遠ざかるほど距離が伸びる', () {
      double metersAt(double lng) => describeReturnToArea(
        area: area,
        point: LatLng(lat: 35.001, lng: lng),
      )!.meters;
      expect(metersAt(135.005), greaterThan(metersAt(135.003)));
    });
  });

  group('compassLabel', () {
    test('8方位の代表値', () {
      expect(compassLabel(0), '北');
      expect(compassLabel(45), '北東');
      expect(compassLabel(90), '東');
      expect(compassLabel(135), '南東');
      expect(compassLabel(180), '南');
      expect(compassLabel(225), '南西');
      expect(compassLabel(270), '西');
      expect(compassLabel(315), '北西');
    });

    test('45度の境目は四捨五入で決まる', () {
      expect(compassLabel(22.4), '北');
      expect(compassLabel(22.5), '北東');
      expect(compassLabel(67.4), '北東');
      expect(compassLabel(67.5), '東');
    });

    test('360度付近は「北」に回り込む', () {
      expect(compassLabel(337.5), '北');
      expect(compassLabel(359.9), '北');
      expect(compassLabel(360), '北');
    });

    test('0〜360の範囲外でも正規化して扱う', () {
      expect(compassLabel(-45), '北西');
      expect(compassLabel(-90), '西');
    });
  });

  group('formatReturnDistance', () {
    test('1km未満はm表記で小数を出さない', () {
      expect(formatReturnDistance(40), '40m');
      expect(formatReturnDistance(40.4), '40m');
      expect(formatReturnDistance(40.6), '41m');
      expect(formatReturnDistance(999.4), '999m');
    });

    test('1km以上はkm表記に切り替わる', () {
      expect(formatReturnDistance(1000), '1.0km');
      expect(formatReturnDistance(1540), '1.5km');
    });
  });

  group('applyOutsideAreaHysteresis', () {
    final t0 = DateTime.utc(2026, 9, 20, 12);

    test('エリア内(null)なら警告せず、経過時間の計測もリセットする', () {
      final result = applyOutsideAreaHysteresis(
        outsideMeters: null,
        wasWarning: false,
        outsideSince: t0,
        now: t0.add(const Duration(minutes: 1)),
      );
      expect(result.isWarning, isFalse);
      expect(result.outsideSince, isNull);
    });

    test('警告中でもエリア内に戻ったら即座に解除する', () {
      final result = applyOutsideAreaHysteresis(
        outsideMeters: null,
        wasWarning: true,
        outsideSince: t0,
        now: t0.add(const Duration(minutes: 5)),
      );
      expect(result.isWarning, isFalse);
      expect(result.outsideSince, isNull);
    });

    test('猶予距離未満のはみ出しは、どれだけ続いても警告しない', () {
      DateTime? since;
      var isWarning = false;
      for (var i = 0; i < 60; i++) {
        final result = applyOutsideAreaHysteresis(
          outsideMeters: outsideAreaGraceDistanceMeters - 0.1,
          wasWarning: isWarning,
          outsideSince: since,
          now: t0.add(Duration(seconds: i)),
        );
        since = result.outsideSince;
        isWarning = result.isWarning;
      }
      expect(isWarning, isFalse);
      expect(since, isNull);
    });

    test('猶予距離ちょうどは「外」として計測を始める', () {
      final result = applyOutsideAreaHysteresis(
        outsideMeters: outsideAreaGraceDistanceMeters,
        wasWarning: false,
        outsideSince: null,
        now: t0,
      );
      expect(result.isWarning, isFalse);
      expect(result.outsideSince, t0);
    });

    test('猶予時間の直前は警告せず、ちょうど経過したら警告する', () {
      final justBefore = applyOutsideAreaHysteresis(
        outsideMeters: 50,
        wasWarning: false,
        outsideSince: t0,
        now: t0.add(outsideAreaGraceDuration - const Duration(milliseconds: 1)),
      );
      expect(justBefore.isWarning, isFalse);
      expect(justBefore.outsideSince, t0);

      final exactly = applyOutsideAreaHysteresis(
        outsideMeters: 50,
        wasWarning: false,
        outsideSince: t0,
        now: t0.add(outsideAreaGraceDuration),
      );
      expect(exactly.isWarning, isTrue);
    });

    test('途中で猶予距離の内側に戻ると、経過時間の計測をやり直す', () {
      final started = applyOutsideAreaHysteresis(
        outsideMeters: 50,
        wasWarning: false,
        outsideSince: null,
        now: t0,
      );
      expect(started.outsideSince, t0);

      // 猶予時間が経つ前に、いったん猶予距離の内側へ戻る。
      final interrupted = applyOutsideAreaHysteresis(
        outsideMeters: 1,
        wasWarning: false,
        outsideSince: started.outsideSince,
        now: t0.add(const Duration(seconds: 5)),
      );
      expect(interrupted.isWarning, isFalse);
      expect(interrupted.outsideSince, isNull);

      // 再び外へ出た時点から数え直すので、最初の t0 から猶予時間が
      // 経っていても、まだ警告にはならない。
      final restarted = applyOutsideAreaHysteresis(
        outsideMeters: 50,
        wasWarning: false,
        outsideSince: interrupted.outsideSince,
        now: t0.add(const Duration(seconds: 6)),
      );
      expect(restarted.isWarning, isFalse);
      expect(restarted.outsideSince, t0.add(const Duration(seconds: 6)));
    });

    test('一度警告に入ったら、猶予距離の内側に戻っただけでは解除しない', () {
      final result = applyOutsideAreaHysteresis(
        outsideMeters: 1,
        wasWarning: true,
        outsideSince: t0,
        now: t0.add(const Duration(seconds: 30)),
      );
      expect(result.isWarning, isTrue);
    });

    test('猶予距離を超えたまま毎秒呼ばれると、猶予時間ちょうどで警告に変わる', () {
      DateTime? since;
      var isWarning = false;
      final switchedAt = <int>[];
      for (var i = 0; i <= outsideAreaGraceDuration.inSeconds + 2; i++) {
        final result = applyOutsideAreaHysteresis(
          outsideMeters: 30,
          wasWarning: isWarning,
          outsideSince: since,
          now: t0.add(Duration(seconds: i)),
        );
        if (!isWarning && result.isWarning) switchedAt.add(i);
        since = result.outsideSince;
        isWarning = result.isWarning;
      }
      expect(switchedAt, [outsideAreaGraceDuration.inSeconds]);
    });
  });
}
