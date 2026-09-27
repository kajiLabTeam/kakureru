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
      await tester.pump();
      // 動き始めた直後はまだ元の位置にいる。
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
}
