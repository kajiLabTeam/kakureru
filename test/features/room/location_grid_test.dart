import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/location_grid.dart';

void main() {
  group('gridCellFor (issue #39: 鬼から見た逃走者GPSのグリッド曖昧化)', () {
    test('同じマス内の複数座標は同じセルに丸められる', () {
      const gridSizeMeters = 50;
      final a = gridCellFor(
        latitude: 35.00001,
        longitude: 139.00001,
        gridSizeMeters: gridSizeMeters,
      );
      final b = gridCellFor(
        latitude: 35.00005,
        longitude: 139.00008,
        gridSizeMeters: gridSizeMeters,
      );

      expect(a.south, b.south);
      expect(a.north, b.north);
      expect(a.west, b.west);
      expect(a.east, b.east);
    });

    test('隣接するマスの座標は別のセルになる', () {
      const gridSizeMeters = 50;
      final base = gridCellFor(
        latitude: 35,
        longitude: 139,
        gridSizeMeters: gridSizeMeters,
      );
      // セルの北側の外側に出る程度に緯度をずらす。
      final north = gridCellFor(
        latitude: base.north + 0.00001,
        longitude: 139,
        gridSizeMeters: gridSizeMeters,
      );
      // セルの東側の外側に出る程度に経度をずらす。
      final east = gridCellFor(
        latitude: 35,
        longitude: base.east + 0.00001,
        gridSizeMeters: gridSizeMeters,
      );

      expect(north.south, isNot(base.south));
      expect(east.west, isNot(base.west));
    });

    test('緯度によって経度方向のセル幅が変わる(cos補正が効いている)', () {
      const gridSizeMeters = 50;
      final atEquator = gridCellFor(
        latitude: 0,
        longitude: 139,
        gridSizeMeters: gridSizeMeters,
      );
      final atHighLatitude = gridCellFor(
        latitude: 60,
        longitude: 139,
        gridSizeMeters: gridSizeMeters,
      );

      final equatorLngWidthDeg = atEquator.east - atEquator.west;
      final highLatLngWidthDeg = atHighLatitude.east - atHighLatitude.west;

      // 高緯度ほど経度1度あたりの実距離が短くなるため、同じ物理サイズの
      // セルを表す経度方向の幅(度)は高緯度のほうが大きくなる。
      expect(highLatLngWidthDeg, greaterThan(equatorLngWidthDeg));

      // 緯度方向のセル幅は緯度に依存しないため変わらない
      // (浮動小数点の丸め誤差の範囲で一致すればよい)。
      expect(
        atHighLatitude.north - atHighLatitude.south,
        closeTo(atEquator.north - atEquator.south, 1e-9),
      );
    });

    test('原点(赤道・グリニッジ子午線)を基準に、同じ物理位置なら常に同じセルになる', () {
      const gridSizeMeters = 100;
      final first = gridCellFor(
        latitude: 35.681236,
        longitude: 139.767125,
        gridSizeMeters: gridSizeMeters,
      );
      final second = gridCellFor(
        latitude: 35.681236,
        longitude: 139.767125,
        gridSizeMeters: gridSizeMeters,
      );

      expect(first.south, second.south);
      expect(first.north, second.north);
      expect(first.west, second.west);
      expect(first.east, second.east);
    });

    // gridSizeMeters が実際に効いているかを押さえるテスト。これが無いと
    // gridCellFor が引数を無視して定数(例: 50)を使うようになっても、
    // 他の全テストが通ってしまう(鬼が20m/100mを押しても手触りが変わらない
    // まま出荷される)。issue #39の核心はグリッドサイズをプレイテストで
    // 詰められることなので、ここは値ごと固定しておく。
    test('セルの南北幅は指定したgridSizeMetersの実距離になる', () {
      const metersPerDegreeLat = 111320.0;
      for (final gridSizeMeters in [20, 50, 100]) {
        final bounds = gridCellFor(
          latitude: 35.681236,
          longitude: 139.767125,
          gridSizeMeters: gridSizeMeters,
        );

        expect(
          (bounds.north - bounds.south) * metersPerDegreeLat,
          closeTo(gridSizeMeters, 0.001),
          reason: '${gridSizeMeters}mを指定したのにセルの南北幅が一致しない',
        );
      }
    });

    test('同じ座標でも20mと100mではセルの大きさが5倍違う', () {
      const latitude = 35.681236;
      const longitude = 139.767125;
      final small = gridCellFor(
        latitude: latitude,
        longitude: longitude,
        gridSizeMeters: 20,
      );
      final large = gridCellFor(
        latitude: latitude,
        longitude: longitude,
        gridSizeMeters: 100,
      );

      expect(
        (large.north - large.south) / (small.north - small.south),
        closeTo(5, 1e-9),
      );
      // 経度方向は、cos補正の基準がそれぞれのセルの南端緯度(20mセルと
      // 100mセルでは最大100m弱ずれる)なので厳密には5倍にならない。
      // 倍率が変わったことさえ分かればよいので緩い許容で見る。
      expect(
        (large.east - large.west) / (small.east - small.west),
        closeTo(5, 0.001),
      );
    });

    test('centerLat/centerLngはセルの中心を返す', () {
      final bounds = gridCellFor(
        latitude: 35,
        longitude: 139,
        gridSizeMeters: 50,
      );

      expect(bounds.centerLat, (bounds.south + bounds.north) / 2);
      expect(bounds.centerLng, (bounds.west + bounds.east) / 2);
    });

    test('南半球・西経の座標でも同じマス内なら同じセルに丸められる', () {
      const gridSizeMeters = 50;
      final a = gridCellFor(
        latitude: -34.00001,
        longitude: -58.00001,
        gridSizeMeters: gridSizeMeters,
      );
      final b = gridCellFor(
        latitude: -34.00005,
        longitude: -58.00008,
        gridSizeMeters: gridSizeMeters,
      );

      expect(a.south, b.south);
      expect(a.north, b.north);
      expect(a.west, b.west);
      expect(a.east, b.east);
    });

    test('南半球・西経の座標でも隣接するマスは別のセルになる', () {
      const gridSizeMeters = 50;
      final base = gridCellFor(
        latitude: -34,
        longitude: -58,
        gridSizeMeters: gridSizeMeters,
      );
      final south = gridCellFor(
        latitude: base.south - 0.00001,
        longitude: -58,
        gridSizeMeters: gridSizeMeters,
      );
      final west = gridCellFor(
        latitude: -34,
        longitude: base.west - 0.00001,
        gridSizeMeters: gridSizeMeters,
      );

      expect(south.south, isNot(base.south));
      expect(west.west, isNot(base.west));
    });
  });
}
