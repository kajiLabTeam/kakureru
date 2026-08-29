import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/rectangle_area.dart';
import 'package:latlong2/latlong.dart' as latlong;

void main() {
  group('calculateRectangleCorners', () {
    test('左上→右下へドラッグした場合に正しい四隅を返す', () {
      final corners = calculateRectangleCorners(
        const LatLng(lat: 35.0, lng: 139.0),
        const LatLng(lat: 34.0, lng: 140.0),
      );

      expect(corners, [
        const LatLng(lat: 34.0, lng: 139.0), // 左下
        const LatLng(lat: 34.0, lng: 140.0), // 右下
        const LatLng(lat: 35.0, lng: 140.0), // 右上
        const LatLng(lat: 35.0, lng: 139.0), // 左上
      ]);
    });

    test('右下→左上へ逆方向にドラッグしても同じ矩形になる', () {
      final forward = calculateRectangleCorners(
        const LatLng(lat: 35.0, lng: 139.0),
        const LatLng(lat: 34.0, lng: 140.0),
      );
      final backward = calculateRectangleCorners(
        const LatLng(lat: 34.0, lng: 140.0),
        const LatLng(lat: 35.0, lng: 139.0),
      );

      expect(backward, forward);
    });

    test('右上→左下へドラッグしても同じ矩形になる', () {
      final forward = calculateRectangleCorners(
        const LatLng(lat: 35.0, lng: 139.0),
        const LatLng(lat: 34.0, lng: 140.0),
      );
      final other = calculateRectangleCorners(
        const LatLng(lat: 35.0, lng: 140.0),
        const LatLng(lat: 34.0, lng: 139.0),
      );

      expect(other, forward);
    });

    test('常に4頂点を返す', () {
      final corners = calculateRectangleCorners(
        const LatLng(lat: 1.0, lng: 1.0),
        const LatLng(lat: 2.0, lng: 2.0),
      );
      expect(corners.length, 4);
    });

    test('開始点と終了点が同じ場合は面積0の矩形(4頂点が全て同じ点)になる', () {
      const point = LatLng(lat: 35.0, lng: 139.0);
      final corners = calculateRectangleCorners(point, point);

      expect(corners, [point, point, point, point]);
    });
  });

  group('toLatLngPoints', () {
    test('RoomSetting.LatLngをlatlong2のLatLngへ順序を保って変換する', () {
      final points = toLatLngPoints(const [
        LatLng(lat: 35.0, lng: 139.0),
        LatLng(lat: -34.0, lng: -58.0),
      ]);

      expect(points, [
        const latlong.LatLng(35.0, 139.0),
        const latlong.LatLng(-34.0, -58.0),
      ]);
    });

    test('空リストなら空リストを返す', () {
      expect(toLatLngPoints(const []), isEmpty);
    });
  });
}
