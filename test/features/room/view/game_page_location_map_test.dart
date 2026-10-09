import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/map/repository/grid_snap.dart';
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

/// 地図に描かれている多角形(プレイエリア等)。無ければ空。
List<Polygon<Object>> _polygons(WidgetTester tester) {
  final finder = find.byType(PolygonLayer<Object>);
  if (finder.evaluate().isEmpty) return const [];
  return tester.widget<PolygonLayer<Object>>(finder).polygons;
}

void main() {
  // 他人のピンは送り出す側が丸めたマスの中心に出す。自分のピンは生の位置。
  // 以前の100mグリッド(issue #39)は#118で廃止したが、200mのマスの中心への
  // 丸めを改めて入れた(feat/map-grid-snap)。
  group('_LocationMap のピン位置 (マスの中心への丸め)', () {
    final cell = gridCellOf(_otherLat, _otherLng);
    final center = gridCenterOf(cell.x, cell.y);
    final snapped = latlong.LatLng(center.lat, center.lng);

    testWidgets('鬼視点で逃走者のピンはマスの中心に出て、マス目の矩形は描かれない', (tester) async {
      await _pumpMap(tester, myRole: UserRole.demon);

      expect(_otherMarker(tester).point, snapped);
      expect(_otherMarker(tester).point, isNot(_otherExactPoint));
      expect(_polygons(tester), isEmpty);
    });

    testWidgets('逃走者視点でも鬼のピンはマスの中心', (tester) async {
      await _pumpMap(
        tester,
        myRole: UserRole.fugitive,
        otherRole: UserRole.demon,
      );

      expect(_otherMarker(tester).point, snapped);
      expect(_polygons(tester), isEmpty);
    });

    testWidgets('自分のピンは丸めず生の位置に出る', (tester) async {
      await _pumpMap(tester, myRole: UserRole.demon);

      final markers = tester
          .widget<MarkerLayer>(find.byType(MarkerLayer))
          .markers;
      expect(markers.first.point, const latlong.LatLng(_myLat, _myLng));
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
      // flutter_mapのalignmentは「座標から見てwidgetをどちらに置くか」なので、
      // アイコン中心(上端から20)を座標に合わせるにはwidgetを下へ寄せる
      // (yが正)。描画された位置そのものは animated_marker_layer_test.dart
      // で確かめている。
      expect(
        _otherMarker(tester).alignment,
        const Alignment(0, (56 / 2 - 40 / 2) / (56 / 2)),
      );
    });
  });
}
