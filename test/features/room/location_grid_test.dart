import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/location_grid.dart';

void main() {
  group('snapToGridCell', () {
    test('同じマス内の複数座標が同じマスに丸められること', () {
      const gridSizeMeters = 50;
      final a = snapToGridCell(
        latitude: 35.6812,
        longitude: 139.7671,
        gridSizeMeters: gridSizeMeters,
      );
      // aと同じマスの中心付近の座標(境界をまたがないよう、aのセル範囲から
      // 直接中心点を計算する)。
      final b = snapToGridCell(
        latitude: a.centerLatitude,
        longitude: a.centerLongitude,
        gridSizeMeters: gridSizeMeters,
      );

      expect(a, equals(b));
    });

    test('隣接するマスの座標が別のマスになること', () {
      const gridSizeMeters = 50;
      final a = snapToGridCell(
        latitude: 35.6812,
        longitude: 139.7671,
        gridSizeMeters: gridSizeMeters,
      );
      // 緯度方向に約100m(グリッド2つぶん)離れた座標。
      final b = snapToGridCell(
        latitude: 35.6812 + 100 / 111320,
        longitude: 139.7671,
        gridSizeMeters: gridSizeMeters,
      );

      expect(a, isNot(equals(b)));
      expect(a.south, isNot(equals(b.south)));
    });

    test('緯度による経度方向の補正(cos補正)が効いていること', () {
      const gridSizeMeters = 50;
      // 赤道付近(緯度0度)と高緯度(緯度60度)で同じグリッドサイズを指定した
      // とき、経度方向のセル幅(度単位)は異なるはず
      // (緯度60度ではcos(60°)=0.5倍の実距離のため、度としては2倍の幅になる)。
      final equator = snapToGridCell(
        latitude: 0,
        longitude: 0,
        gridSizeMeters: gridSizeMeters,
      );
      final highLatitude = snapToGridCell(
        latitude: 60,
        longitude: 0,
        gridSizeMeters: gridSizeMeters,
      );

      final equatorLngWidthDeg = equator.east - equator.west;
      final highLatitudeLngWidthDeg = highLatitude.east - highLatitude.west;

      expect(highLatitudeLngWidthDeg, greaterThan(equatorLngWidthDeg));
      expect(
        highLatitudeLngWidthDeg,
        closeTo(equatorLngWidthDeg * 2, 0.0001),
      );

      // 緯度方向のセル幅(度単位)は緯度に依存せず一定。
      final equatorLatWidthDeg = equator.north - equator.south;
      final highLatitudeLatWidthDeg = highLatitude.north - highLatitude.south;
      expect(equatorLatWidthDeg, closeTo(highLatitudeLatWidthDeg, 0.0000001));
    });

    test('セルの範囲に元の座標が含まれる', () {
      const gridSizeMeters = 20;
      const latitude = 35.123456;
      const longitude = 139.654321;
      final cell = snapToGridCell(
        latitude: latitude,
        longitude: longitude,
        gridSizeMeters: gridSizeMeters,
      );

      expect(latitude, greaterThanOrEqualTo(cell.south));
      expect(latitude, lessThan(cell.north));
      expect(longitude, greaterThanOrEqualTo(cell.west));
      expect(longitude, lessThan(cell.east));
    });
  });
}
