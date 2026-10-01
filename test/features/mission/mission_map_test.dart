import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/mission/view/mission_palette.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_location_map.dart';

const _myUid = 'me';
const _demonUid = 'demon';
const _otherUid = 'other';

Future<void> _pumpMap(
  WidgetTester tester, {
  List<MissionMapPoint> missionPoints = const [],
  bool enlargeDemonIcon = false,
  Set<String> enlargedUserUids = const {},
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
            RoomUser(id: _otherUid, displayName: 'みお'),
          ],
          locations: const [
            UserLocation(uid: _myUid, latitude: 35, longitude: 137),
            UserLocation(uid: _demonUid, latitude: 35.001, longitude: 137),
            UserLocation(uid: _otherUid, latitude: 35.002, longitude: 137),
          ],
          missionPoints: missionPoints,
          enlargeDemonIcon: enlargeDemonIcon,
          enlargedUserUids: enlargedUserUids,
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
  testWidgets('アクセスポイントの点と、判定範囲の破線の円を地点の数だけ描く', (tester) async {
    await _pumpMap(
      tester,
      missionPoints: const [
        (lat: 35.0005, lng: 137.0, radiusM: 15),
        (lat: 35.0010, lng: 137.0, radiusM: 15),
      ],
    );
    expect(find.text('アクセスポイント'), findsNWidgets(2));
    final polygons = tester
        .widgetList<PolygonLayer>(find.byType(PolygonLayer))
        .expand((layer) => layer.polygons)
        .toList();
    expect(
      polygons.where((p) => p.borderColor == missionAccent),
      hasLength(2),
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

  testWidgets('拡大しても鬼のアイコンの中心は動かない(実際の位置のまま)', (tester) async {
    // 鬼のピン(ラベル「おに（鬼）」と同じ列にあるアイコン)の中心。
    Offset demonIconCenter() => tester.getCenter(
      find.descendant(
        of: find
            .ancestor(of: find.text('おに（鬼）'), matching: find.byType(Column))
            .first,
        matching: find.byType(MarkerIcon),
      ),
    );

    await _pumpMap(tester);
    final normal = demonIconCenter();
    await _pumpMap(tester, enlargeDemonIcon: true);
    final enlarged = demonIconCenter();

    expect(enlarged.dx, closeTo(normal.dx, 0.5));
    expect(enlarged.dy, closeTo(normal.dy, 0.5));
  });

  testWidgets('効果が無ければ鬼のピンは元の大きさ', (tester) async {
    await _pumpMap(tester);
    expect(_scaleOf(tester, 'おに（鬼）'), 1);
  });

  testWidgets('ハズレ(enlarge_self_icon)を引いた逃走者は、鬼の地図でピンが2倍', (
    tester,
  ) async {
    await _pumpMap(tester, enlargedUserUids: {_otherUid});
    expect(_scaleOf(tester, 'みお（逃走者）'), enlargedDemonIconScale);
    // 引いていない自分・鬼は元の大きさのまま。
    expect(_scaleOf(tester, '自分（逃走者）'), 1);
    expect(_scaleOf(tester, 'おに（鬼）'), 1);
  });

  testWidgets('enlargedUserUidsに無ければ逃走者のピンは元の大きさ', (tester) async {
    await _pumpMap(tester);
    expect(_scaleOf(tester, 'みお（逃走者）'), 1);
  });
}
