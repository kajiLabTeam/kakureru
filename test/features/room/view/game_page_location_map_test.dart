import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/room/location_grid.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_location_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

const _myUid = 'me';
const _otherUid = 'other';

/// 相手(他プレイヤー)の実座標。丸め結果と突き合わせるために固定する。
const _otherLat = 35.681236;
const _otherLng = 139.767125;
const _otherExactPoint = latlong.LatLng(_otherLat, _otherLng);

/// 自分の実座標。相手と別セルになるよう離しておく。
const _myLat = 35.6;
const _myLng = 139.7;

/// 地図(GamePage内の_LocationMap)を単体で立ち上げる。
///
/// [includeSelfLocation] をfalseにすると自分の位置が未取得の状態になり、
/// 「現在地を取得中...」バナーが出る。
Future<void> _pumpMap(
  WidgetTester tester, {
  required UserRole myRole,
  UserRole otherRole = UserRole.fugitive,
  bool includeSelfLocation = true,
}) async {
  // 実機に近い幅で確認する。
  await tester.binding.setSurfaceSize(const Size(360, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: buildLocationMapForTest(
          myUid: _myUid,
          users: [
            RoomUser(id: _myUid, displayName: 'わたし', role: myRole),
            RoomUser(id: _otherUid, displayName: 'あいて', role: otherRole),
          ],
          locations: [
            if (includeSelfLocation)
              const UserLocation(
                uid: _myUid,
                latitude: _myLat,
                longitude: _myLng,
              ),
            const UserLocation(
              uid: _otherUid,
              latitude: _otherLat,
              longitude: _otherLng,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 地図に渡されたマーカーのうち、相手([_otherUid])のもの。
///
/// マーカーはlocationsと同じ順で組み立てられるため、相手は常に末尾。
Marker _otherMarker(WidgetTester tester) =>
    tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.last;

/// 地図に描かれているグリッドセルの矩形。無ければ空。
List<Polygon<Object>> _gridPolygons(WidgetTester tester) {
  final finder = find.byType(PolygonLayer<Object>);
  if (finder.evaluate().isEmpty) return const [];
  return tester.widget<PolygonLayer<Object>>(finder).polygons;
}

void main() {
  // 純粋関数(gridCellFor / resolveMarkerPosition)のテストは揃っているが、
  // それらを呼ぶ側の配線には一切テストが無かった。viewerRole/targetRoleを
  // 取り違える、グリッドサイズの定数を変える、といった壊れ方は
  // 純粋関数のテストでは全て素通りするため、ここで押さえる。
  group('_LocationMap のグリッド曖昧化まわりの配線 (issue #39)', () {
    testWidgets('鬼視点では逃走者のピンがセル中心へ丸められ、セルの矩形が描かれる', (tester) async {
      await _pumpMap(tester, myRole: UserRole.demon);

      final expectedCell = gridCellFor(
        latitude: _otherLat,
        longitude: _otherLng,
        gridSizeMeters: 100,
      );
      final marker = _otherMarker(tester);

      expect(marker.point, isNot(_otherExactPoint));
      expect(marker.point.latitude, expectedCell.centerLat);
      expect(marker.point.longitude, expectedCell.centerLng);
      expect(_gridPolygons(tester), hasLength(1));
    });

    testWidgets('逃走者視点では鬼のピンは実座標のままで、セルの矩形も描かれない', (tester) async {
      await _pumpMap(
        tester,
        myRole: UserRole.fugitive,
        otherRole: UserRole.demon,
      );

      // このテストと1つ上のテストの組で、viewerRole/targetRoleの取り違え
      // (「逃走者が鬼を矩形で見て、鬼が逃走者を正確な点で見る」という
      // 機能の完全反転)を検知する。
      expect(_otherMarker(tester).point, _otherExactPoint);
      expect(_gridPolygons(tester), isEmpty);
    });
  });

  group('_LocationMap の重なり・マーカー位置 (issue #42)', () {
    testWidgets('役割アイコンのマーカーは、アイコン中心が実座標に来るalignmentになっている', (
      tester,
    ) async {
      await _pumpMap(
        tester,
        myRole: UserRole.fugitive,
        otherRole: UserRole.demon,
      );

      // マーカーwidgetは72x56で、子はColumn[アイコン40, ラベル]が上詰め。
      // Alignment.center(=widget全体の中心)だとアイコン中心は座標より
      // 8論理px北にずれるため、その分だけ上へ寄せた値を指定している。
      expect(
        _otherMarker(tester).alignment,
        const Alignment(0, (40 / 2 - 56 / 2) / (56 / 2)),
      );
    });
  });
}
