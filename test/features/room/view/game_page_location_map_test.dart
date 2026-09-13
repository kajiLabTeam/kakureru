import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/room/location_grid.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game_page.dart';
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
  // 実機に近い幅で確認する(切替UIとバナーの重なりはこの幅で起きる)。
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

/// [polygon] の緯度方向の高さ(度)。グリッドサイズの違いを見るために使う。
double _latSpanOf(Polygon<Object> polygon) {
  final lats = polygon.points.map((p) => p.latitude).toList();
  return lats.reduce((a, b) => a > b ? a : b) -
      lats.reduce((a, b) => a < b ? a : b);
}

bool _chipSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

void main() {
  // 純粋関数(gridCellFor / resolveMarkerPosition)のテストは揃っているが、
  // それらを呼ぶ側の配線には一切テストが無かった。viewerRole/targetRoleを
  // 取り違える、切替UIの表示条件を消す、初期値を変える、といった壊れ方は
  // 純粋関数のテストでは全て素通りするため、ここで押さえる。
  group('_LocationMap のグリッド曖昧化まわりの配線 (issue #39)', () {
    testWidgets('グリッドサイズ切替UIは鬼にだけ見える', (tester) async {
      await _pumpMap(tester, myRole: UserRole.demon);

      expect(find.widgetWithText(ChoiceChip, '20m'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '50m'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '100m'), findsOneWidget);
    });

    testWidgets('グリッドサイズ切替UIは逃走者には見えない', (tester) async {
      await _pumpMap(
        tester,
        myRole: UserRole.fugitive,
        otherRole: UserRole.demon,
      );

      // 逃走者に見えると「鬼から自分がどう見えているか」の設定を
      // 逃走者が触れてしまい、受け入れ条件に反する。
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('切替UIの初期選択は50m', (tester) async {
      await _pumpMap(tester, myRole: UserRole.demon);

      expect(_chipSelected(tester, '50m'), isTrue);
      expect(_chipSelected(tester, '20m'), isFalse);
      expect(_chipSelected(tester, '100m'), isFalse);
    });

    testWidgets('鬼視点では逃走者のピンがセル中心へ丸められ、セルの矩形が描かれる', (tester) async {
      await _pumpMap(tester, myRole: UserRole.demon);

      final expectedCell = gridCellFor(
        latitude: _otherLat,
        longitude: _otherLng,
        gridSizeMeters: 50,
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

    testWidgets('切替UIで100mを選ぶとセルの矩形が大きくなり、ピンの位置も変わる', (tester) async {
      await _pumpMap(tester, myRole: UserRole.demon);

      final before = _latSpanOf(_gridPolygons(tester).single);
      final pointBefore = _otherMarker(tester).point;

      await tester.tap(find.widgetWithText(ChoiceChip, '100m'));
      await tester.pump();

      expect(_chipSelected(tester, '100m'), isTrue);
      // 切替UIの値がgridCellForまで届いていなければ、ここは変わらない。
      expect(
        _latSpanOf(_gridPolygons(tester).single),
        closeTo(before * 2, 1e-9),
      );
      expect(_otherMarker(tester).point, isNot(pointBefore));
    });
  });

  group('_LocationMap の重なり・マーカー位置 (issue #42)', () {
    testWidgets('「現在地を取得中...」バナーとグリッド切替UIが重ならない', (tester) async {
      await _pumpMap(
        tester,
        myRole: UserRole.demon,
        includeSelfLocation: false,
      );

      final banner = find.text('現在地を取得中...');
      expect(banner, findsOneWidget);

      // 両方が同時に出る幅(360dp)でも、切替チップがバナーに隠れないこと。
      final bannerRect = tester.getRect(banner);
      final selectorRect = tester.getRect(
        find.widgetWithText(ChoiceChip, '50m'),
      );
      expect(selectorRect.top, greaterThanOrEqualTo(bannerRect.bottom));
    });

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
