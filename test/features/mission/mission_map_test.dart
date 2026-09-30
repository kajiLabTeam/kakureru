import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_location_map.dart';

const _myUid = 'me';
const _demonUid = 'demon';

Future<void> _pumpMap(
  WidgetTester tester, {
  MissionMapPoint? missionPoint,
  bool enlargeDemonIcon = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(360, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: buildLocationMapForTest(
          myUid: _myUid,
          users: const [
            RoomUser(id: _myUid, displayName: 'わたし'),
            RoomUser(id: _demonUid, displayName: 'おに', role: UserRole.demon),
          ],
          locations: const [
            UserLocation(uid: _myUid, latitude: 35, longitude: 137),
            UserLocation(uid: _demonUid, latitude: 35.001, longitude: 137),
          ],
          missionPoint: missionPoint,
          enlargeDemonIcon: enlargeDemonIcon,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// ラベル[label]のピンにかかっている拡大率。
double _scaleOf(WidgetTester tester, String label) {
  final transform = tester.widget<Transform>(
    find.ancestor(of: find.text(label), matching: find.byType(Transform)).first,
  );
  return transform.transform.getMaxScaleOnAxis();
}

void main() {
  testWidgets('アクセスポイントの点と、判定範囲の破線の円を描く', (tester) async {
    await _pumpMap(
      tester,
      missionPoint: (lat: 35.0005, lng: 137.0, radiusM: 15),
    );
    expect(find.text('アクセスポイント'), findsOneWidget);
    final polygons = tester
        .widgetList<PolygonLayer>(find.byType(PolygonLayer))
        .expand((layer) => layer.polygons)
        .toList();
    expect(
      polygons.where((p) => p.borderColor == missionPointColor),
      hasLength(1),
    );
  });

  testWidgets('ミッションが無ければアクセスポイントは描かない', (tester) async {
    await _pumpMap(tester);
    expect(find.text('アクセスポイント'), findsNothing);
  });

  testWidgets('「鬼のアイコンを大きくする」の間は、鬼のピンだけ2倍にする', (tester) async {
    await _pumpMap(tester, enlargeDemonIcon: true);
    expect(_scaleOf(tester, 'おに（鬼）'), enlargedDemonIconScale);
    expect(_scaleOf(tester, '自分（逃走者）'), 1);
  });

  testWidgets('効果が無ければ鬼のピンは元の大きさ', (tester) async {
    await _pumpMap(tester);
    expect(_scaleOf(tester, 'おに（鬼）'), 1);
  });
}
