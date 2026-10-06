import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/cluster_marker.dart';
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

  group('近い人のクラスタ表示', () {
    const same = latlong.LatLng(35.681, 139.767);
    const users = [
      RoomUser(id: _myUid, displayName: 'わたし'),
      RoomUser(id: 'a', displayName: 'あきら', role: UserRole.demon),
      RoomUser(id: 'b', displayName: 'ばんび'),
      RoomUser(id: 'c', displayName: 'ちか'),
    ];

    Future<void> pumpAll(
      WidgetTester tester, {
      List<RoomUser> roomUsers = users,
      Set<String> selectable = const {},
      ValueChanged<String>? onSelect,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameLocationMap(
              locations: [
                for (final u in roomUsers)
                  UserLocation(
                    uid: u.id,
                    latitude: same.latitude,
                    longitude: same.longitude,
                  ),
              ],
              users: roomUsers,
              myUid: _myUid,
              cachedPosition: null,
              gameArea: const [],
              selectableUids: selectable,
              onSelectOpponent: onSelect,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('同じ場所の他人はまとめて1つの四角になり、自分は単独のまま', (tester) async {
      await pumpAll(tester);

      expect(find.byType(ClusterMarkerView), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('鬼 1 ・ 逃走者 2'), findsOneWidget);
      // 名前は出さない。自分のピンだけ名前付きで残る。
      expect(find.textContaining('あきら'), findsNothing);
      expect(find.textContaining('自分'), findsOneWidget);
      // 黒い点・引き出し線は出さない。
      expect(find.byType(PolylineLayer), findsNothing);
      expect(find.byType(CircleLayer), findsNothing);
    });

    testWidgets('鬼がいなければ「逃走者 2」だけ出す', (tester) async {
      await pumpAll(
        tester,
        roomUsers: const [
          RoomUser(id: _myUid, displayName: 'わたし'),
          RoomUser(id: 'b', displayName: 'ばんび'),
          RoomUser(id: 'c', displayName: 'ちか'),
        ],
      );
      expect(find.text('逃走者 2'), findsOneWidget);
    });

    testWidgets('捕まって鬼になると、内訳がその場で変わる', (tester) async {
      await pumpAll(tester);
      expect(find.text('鬼 1 ・ 逃走者 2'), findsOneWidget);

      await pumpAll(
        tester,
        roomUsers: [
          for (final u in users)
            if (u.id == 'b') u.copyWith(role: UserRole.demon) else u,
        ],
      );
      expect(find.text('鬼 2 ・ 逃走者 1'), findsOneWidget);
    });

    testWidgets('タップで一覧が開き、選べる人をタップすると通知される', (tester) async {
      String? picked;
      await pumpAll(
        tester,
        selectable: {'a', 'b'},
        onSelect: (uid) => picked = uid,
      );

      await tester.tap(find.byType(ClusterMarkerView));
      await tester.pumpAndSettle();
      expect(find.byType(ClusterSheet), findsOneWidget);
      expect(find.text('あきら'), findsOneWidget);
      expect(find.text('鬼'), findsOneWidget);

      await tester.tap(find.text('あきら'));
      await tester.pumpAndSettle();
      expect(find.byType(ClusterSheet), findsNothing);
      expect(picked, 'a');
    });

    testWidgets('選べない人(自分と同じ役割)をタップしても何も起きない', (tester) async {
      String? picked;
      await pumpAll(tester, selectable: {'a'}, onSelect: (uid) => picked = uid);

      await tester.tap(find.byType(ClusterMarkerView));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ちか'));
      await tester.pumpAndSettle();
      expect(find.byType(ClusterSheet), findsOneWidget);
      expect(picked, isNull);
    });
  });

  group('ピンの位置(issue #42)', () {
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

    testWidgets('まとめていないピンは、アイコンの中心がちょうど実座標に来る', (tester) async {
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

    testWidgets('離れているピンは、まとめず単独のまま描く', (tester) async {
      await pumpTwoAt(
        tester,
        const latlong.LatLng(35.681, 139.767),
        const latlong.LatLng(35.691, 139.777),
      );

      expect(find.byType(ClusterMarkerView), findsNothing);
      expect(find.byType(PolylineLayer), findsNothing);
      expect(find.byType(CircleLayer), findsNothing);
    });
  });
}
