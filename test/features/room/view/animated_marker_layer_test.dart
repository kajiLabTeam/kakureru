import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_location_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

const _myUid = 'me';
const _otherUid = 'other';

/// 相手の位置だけを差し替えて地図を描く(逃走者視点で鬼を見るので、
/// グリッド丸めがかからず実座標がそのままマーカーの移動先になる)。
Future<void> _pumpMapWithOtherAt(
  WidgetTester tester,
  latlong.LatLng other,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: buildLocationMapForTest(
          myUid: _myUid,
          users: const [
            // roleの既定は逃走者。
            RoomUser(id: _myUid, displayName: 'わたし'),
            RoomUser(id: _otherUid, displayName: 'あいて', role: UserRole.demon),
          ],
          locations: [
            const UserLocation(uid: _myUid, latitude: 35.6, longitude: 139.7),
            UserLocation(
              uid: _otherUid,
              latitude: other.latitude,
              longitude: other.longitude,
            ),
          ],
        ),
      ),
    ),
  );
}

latlong.LatLng _otherPoint(WidgetTester tester) =>
    tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last.point;

void main() {
  group('lerpLatLng', () {
    const from = latlong.LatLng(35, 139);
    const to = latlong.LatLng(35.001, 139.002);

    test('t=0で始点、t=1で終点、t=0.5で中点', () {
      expect(lerpLatLng(from, to, 0), from);
      expect(lerpLatLng(from, to, 1), to);
      final mid = lerpLatLng(from, to, 0.5);
      expect(mid.latitude, closeTo(35.0005, 1e-9));
      expect(mid.longitude, closeTo(139.001, 1e-9));
    });

    test('範囲外のtはクランプする', () {
      expect(lerpLatLng(from, to, -1), from);
      expect(lerpLatLng(from, to, 2), to);
    });
  });

  group('AnimatedMarkerLayer (issue #117)', () {
    const a = latlong.LatLng(35.681, 139.767);
    const b = latlong.LatLng(35.682, 139.768);

    testWidgets('初めて表示するマーカーは、動かさず最初から移動先に置く', (tester) async {
      await _pumpMapWithOtherAt(tester, a);
      await tester.pump();
      expect(_otherPoint(tester), a);
    });

    testWidgets('位置が変わったら瞬間移動せず、時間をかけて移動先へ動く', (tester) async {
      await _pumpMapWithOtherAt(tester, a);
      await tester.pumpAndSettle();

      await _pumpMapWithOtherAt(tester, b);
      // 位置が変わった最初のフレームで、移動先へ一瞬飛んではいけない。
      expect(_otherPoint(tester), a);
      await tester.pump();
      // 動き始めた直後もまだ元の位置にいる。
      expect(_otherPoint(tester), a);

      await tester.pump(markerMoveDuration ~/ 2);
      final halfway = _otherPoint(tester);
      expect(halfway.latitude, greaterThan(a.latitude));
      expect(halfway.latitude, lessThan(b.latitude));

      await tester.pumpAndSettle();
      expect(_otherPoint(tester), b);
    });

    testWidgets('移動中に次の位置が来たら、その時点の表示位置から動き直す', (tester) async {
      const c = latlong.LatLng(35.680, 139.766);
      await _pumpMapWithOtherAt(tester, a);
      await tester.pumpAndSettle();

      await _pumpMapWithOtherAt(tester, b);
      await tester.pump();
      await tester.pump(markerMoveDuration ~/ 2);
      final halfway = _otherPoint(tester);

      await _pumpMapWithOtherAt(tester, c);
      await tester.pump();
      // 途中の位置から動き直す(元の位置aへ戻ってから動くことはしない)。
      expect(_otherPoint(tester).latitude, closeTo(halfway.latitude, 1e-5));

      await tester.pumpAndSettle();
      expect(_otherPoint(tester), c);
    });
  });

  group('spreadOverlappingMarkers (issue #123)', () {
    test('離れているピンは動かさない', () {
      final shifts = spreadOverlappingMarkers(const [
        Offset.zero,
        Offset(200, 0),
      ]);
      expect(shifts, [Offset.zero, Offset.zero]);
    });

    test('同じ点の2人は、左右に間隔ぶん離して並べる', () {
      const p = Offset(100, 100);
      final shifts = spreadOverlappingMarkers(
        const [p, p],
      );
      final a = p + shifts[0];
      final b = p + shifts[1];
      expect((a - b).distance, closeTo(72, 1e-9));
      // 1人目が左、2人目が右。
      expect(a.dx, lessThan(b.dx));
      expect(a.dy, closeTo(b.dy, 1e-9));
    });

    test('同じ点の3人は、互いに間隔以上離れる', () {
      const p = Offset(50, 50);
      final shifts = spreadOverlappingMarkers(
        const [p, p, p],
      );
      final placed = [for (final s in shifts) p + s];
      for (var i = 0; i < 3; i++) {
        for (var j = i + 1; j < 3; j++) {
          expect(
            (placed[i] - placed[j]).distance,
            greaterThanOrEqualTo(72 - 1e-9),
          );
        }
      }
    });

    test('重なっている組と離れているピンが混ざっても、離れているピンは動かない', () {
      final shifts = spreadOverlappingMarkers(const [
        Offset.zero,
        Offset(500, 500),
        Offset(5, 0),
      ]);
      expect(shifts[1], Offset.zero);
      expect(shifts[0], isNot(Offset.zero));
      expect(shifts[2], isNot(Offset.zero));
    });

    // Copilotのレビュー指摘(PR #127)。組ごとに独立して並べると、動かした
    // 先で別の組のピンと重なることがあった。
    test('ずらした先で別のピンと重なるなら、まとめて並べ直す', () {
      const points = [Offset.zero, Offset.zero, Offset(40, 0)];
      final shifts = spreadOverlappingMarkers(points);
      final placed = [for (var i = 0; i < 3; i++) points[i] + shifts[i]];
      for (var i = 0; i < 3; i++) {
        for (var j = i + 1; j < 3; j++) {
          expect(
            (placed[i] - placed[j]).distance,
            greaterThanOrEqualTo(markerOverlapDistance),
          );
        }
      }
    });

    test('密集していても、最後には全員が重ならない位置に並ぶ', () {
      // 一列に少しずつずれて並んだ8人(隣同士だけが重なっている)。
      final points = [for (var i = 0; i < 8; i++) Offset(i * 30.0, i * 5.0)];
      final shifts = spreadOverlappingMarkers(points);
      final placed = [
        for (var i = 0; i < points.length; i++) points[i] + shifts[i],
      ];
      for (var i = 0; i < placed.length; i++) {
        for (var j = i + 1; j < placed.length; j++) {
          expect(
            (placed[i] - placed[j]).distance,
            greaterThanOrEqualTo(markerOverlapDistance - 1e-9),
          );
        }
      }
    });

    test('組の中心は変えない(全体として元の場所のまわりに並ぶ)', () {
      const points = [Offset(10, 10), Offset(12, 14), Offset(8, 9)];
      final shifts = spreadOverlappingMarkers(points);
      var before = Offset.zero;
      var after = Offset.zero;
      for (var i = 0; i < points.length; i++) {
        before += points[i];
        after += points[i] + shifts[i];
      }
      expect((before - after).distance, lessThan(1e-9));
    });
  });

  testWidgets('同じ座標にいる2人のピンは、重ならずに両方見える位置に描かれる (issue #123)', (
    tester,
  ) async {
    const same = latlong.LatLng(35.681, 139.767);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: buildLocationMapForTest(
            myUid: _myUid,
            users: const [
              RoomUser(id: _myUid, displayName: 'わたし'),
              RoomUser(id: _otherUid, displayName: 'あいて'),
            ],
            locations: [
              UserLocation(
                uid: _myUid,
                latitude: same.latitude,
                longitude: same.longitude,
              ),
              UserLocation(
                uid: _otherUid,
                latitude: same.latitude,
                longitude: same.longitude,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final self = tester.getCenter(find.textContaining('自分'));
    final other = tester.getCenter(find.textContaining('あいて'));
    // ラベル同士が重ならない程度に離れている。
    expect(
      (self - other).distance,
      greaterThanOrEqualTo(markerSpreadSpacing - 1),
    );
    // 座標そのものは変えていない(見た目だけずらしている)。
    final points = tester
        .widget<MarkerLayer>(find.byType(MarkerLayer))
        .markers
        .map((m) => m.point);
    expect(points, everyElement(same));
    // 2人なので左右に並ぶ。
    expect((self.dy - other.dy).abs(), lessThan(1));
  });

  group('ずらしたピンの本当の位置', () {
    Future<void> pumpTwoAt(
      WidgetTester tester,
      latlong.LatLng mine,
      latlong.LatLng others,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildLocationMapForTest(
              myUid: _myUid,
              users: const [
                RoomUser(id: _myUid, displayName: 'わたし'),
                RoomUser(id: _otherUid, displayName: 'あいて'),
              ],
              locations: [
                UserLocation(
                  uid: _myUid,
                  latitude: mine.latitude,
                  longitude: mine.longitude,
                ),
                UserLocation(
                  uid: _otherUid,
                  latitude: others.latitude,
                  longitude: others.longitude,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('ずらしたピンごとに、本当の位置の点とそこからピンへの線を描く', (
      tester,
    ) async {
      const same = latlong.LatLng(35.681, 139.767);
      await pumpTwoAt(tester, same, same);

      final lines = tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines;
      expect(lines, hasLength(2));
      for (final line in lines) {
        expect(line.points.first, same);
        expect(line.points.last, isNot(same));
      }

      final dots = tester.widget<CircleLayer>(find.byType(CircleLayer)).circles;
      expect(dots.map((c) => c.point), [same, same]);
    });

    testWidgets('線の先はずらしたピンのアイコンの中心に届く', (tester) async {
      const same = latlong.LatLng(35.681, 139.767);
      await pumpTwoAt(tester, same, same);

      final camera = MapCamera.of(
        tester.element(find.byType(PolylineLayer)),
      );
      final mapOrigin = tester.getTopLeft(find.byType(FlutterMap));
      final lineEnds = tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .map((l) => mapOrigin + camera.latLngToScreenOffset(l.points.last))
          .toList();
      final icons = find.byType(MarkerIcon);
      final iconCenters = [
        for (var i = 0; i < icons.evaluate().length; i++)
          tester.getCenter(icons.at(i)),
      ];

      for (final center in iconCenters) {
        final nearest = lineEnds
            .map((end) => (end - center).distance)
            .reduce((a, b) => a < b ? a : b);
        expect(nearest, lessThan(1));
      }
    });

    testWidgets('ずらしていないピンは、アイコンの中心がちょうど実座標に来る', (tester) async {
      const mine = latlong.LatLng(35.681, 139.767);
      await pumpTwoAt(tester, mine, const latlong.LatLng(35.691, 139.777));

      final camera = MapCamera.of(tester.element(find.byType(MarkerLayer)));
      final mapOrigin = tester.getTopLeft(find.byType(FlutterMap));
      final expected = mapOrigin + camera.latLngToScreenOffset(mine);
      final selfIcon = find.descendant(
        of: find.ancestor(
          of: find.textContaining('自分'),
          matching: find.byType(Column),
        ),
        matching: find.byType(MarkerIcon),
      );
      expect((tester.getCenter(selfIcon) - expected).distance, lessThan(1));
    });

    testWidgets('役割が分からない人のlocation_pinは、下端の先端が実座標に来る', (tester) async {
      const unknown = latlong.LatLng(35.691, 139.777);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildLocationMapForTest(
              myUid: _myUid,
              // 相手がusersにまだ居ないので役割が分からない。自分の位置を
              // 渡さないと、地図は相手の位置を中心に表示する。
              users: const [RoomUser(id: _myUid, displayName: 'わたし')],
              locations: [
                UserLocation(
                  uid: _otherUid,
                  latitude: unknown.latitude,
                  longitude: unknown.longitude,
                ),
              ],
            ),
          ),
        ),
      );
      // 自分の位置が無い間は「現在地を取得中」のスピナーが回り続けるので、
      // pumpAndSettleではなくマーカーの移動時間ぶん進める。
      await tester.pump();
      await tester.pump(markerMoveDuration);

      final camera = MapCamera.of(tester.element(find.byType(MarkerLayer)));
      final mapOrigin = tester.getTopLeft(find.byType(FlutterMap));
      final expected = mapOrigin + camera.latLngToScreenOffset(unknown);
      final pin = find.ancestor(
        of: find.byIcon(Icons.location_pin).first,
        matching: find.byType(MarkerIcon),
      );
      expect(
        (tester.getBottomLeft(pin) + tester.getBottomRight(pin)) / 2 - expected,
        within(distance: 1, from: Offset.zero),
      );
    });

    testWidgets('離れているピンには点も線も描かない', (tester) async {
      await pumpTwoAt(
        tester,
        const latlong.LatLng(35.681, 139.767),
        const latlong.LatLng(35.691, 139.777),
      );

      expect(find.byType(PolylineLayer), findsNothing);
      expect(find.byType(CircleLayer), findsNothing);
    });
  });
}
