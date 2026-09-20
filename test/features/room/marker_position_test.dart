import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/location_grid.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_location_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

void main() {
  group('resolveMarkerPosition (issue #39: 鬼から見た逃走者GPSのグリッド曖昧化)', () {
    const latitude = 35.681236;
    const longitude = 139.767125;
    const exactPoint = latlong.LatLng(latitude, longitude);

    test('鬼視点で逃走者を見るときは、正確な座標ではなくグリッドセルの中心を返す', () {
      final resolved = resolveMarkerPosition(
        latitude: latitude,
        longitude: longitude,
        isSelf: false,
        viewerRole: UserRole.demon,
        targetRole: UserRole.fugitive,
        gridSizeMeters: 50,
      );

      // 曖昧化の核心: マーカーの描画点が実座標のままだと、セルの矩形を
      // 描いてもピンの位置で真の座標が分かってしまい意味が無い。
      expect(resolved.point, isNot(exactPoint));
      expect(resolved.cellBounds, isNotNull);

      final expectedCell = gridCellFor(
        latitude: latitude,
        longitude: longitude,
        gridSizeMeters: 50,
      );
      expect(resolved.point.latitude, expectedCell.centerLat);
      expect(resolved.point.longitude, expectedCell.centerLng);
      expect(resolved.cellBounds, expectedCell);
    });

    test('自分の位置は鬼視点であっても正確な座標のまま', () {
      final resolved = resolveMarkerPosition(
        latitude: latitude,
        longitude: longitude,
        isSelf: true,
        viewerRole: UserRole.demon,
        targetRole: UserRole.fugitive,
        gridSizeMeters: 50,
      );

      expect(resolved.point, exactPoint);
      expect(resolved.cellBounds, isNull);
    });

    test('同ロール(鬼から見た鬼)は正確な座標のまま', () {
      final resolved = resolveMarkerPosition(
        latitude: latitude,
        longitude: longitude,
        isSelf: false,
        viewerRole: UserRole.demon,
        targetRole: UserRole.demon,
        gridSizeMeters: 50,
      );

      expect(resolved.point, exactPoint);
      expect(resolved.cellBounds, isNull);
    });

    test('逃走者視点で見た鬼は正確な座標のまま(丸めない)', () {
      final resolved = resolveMarkerPosition(
        latitude: latitude,
        longitude: longitude,
        isSelf: false,
        viewerRole: UserRole.fugitive,
        targetRole: UserRole.demon,
        gridSizeMeters: 50,
      );

      expect(resolved.point, exactPoint);
      expect(resolved.cellBounds, isNull);
    });

    test('役割が未知(null)なら丸めない', () {
      final resolved = resolveMarkerPosition(
        latitude: latitude,
        longitude: longitude,
        isSelf: false,
        viewerRole: UserRole.demon,
        targetRole: null,
        gridSizeMeters: 50,
      );

      expect(resolved.point, exactPoint);
      expect(resolved.cellBounds, isNull);
    });

    // gridSizeMeters をgridCellForへそのまま渡しているか(途中で定数に
    // すり替わっていないか)を押さえる。切替UIで20m/100mを選んでも
    // セルの大きさが変わらない、という壊れ方を検知するため。
    test('gridSizeMetersがそのままセルの大きさに反映される', () {
      ({double lat, double lng}) sizeOf(int gridSizeMeters) {
        final resolved = resolveMarkerPosition(
          latitude: latitude,
          longitude: longitude,
          isSelf: false,
          viewerRole: UserRole.demon,
          targetRole: UserRole.fugitive,
          gridSizeMeters: gridSizeMeters,
        );
        final bounds = resolved.cellBounds!;
        return (
          lat: bounds.north - bounds.south,
          lng: bounds.east - bounds.west,
        );
      }

      final small = sizeOf(20);
      final large = sizeOf(100);

      expect(large.lat / small.lat, closeTo(5, 1e-9));
      // 経度方向はcos補正の基準緯度がセルごとに異なるため厳密には5倍に
      // ならない(location_grid_test.dartと同じ理由)。
      expect(large.lng / small.lng, closeTo(5, 0.001));
    });
  });
}
