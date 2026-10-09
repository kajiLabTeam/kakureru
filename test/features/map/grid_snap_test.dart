import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/map/repository/grid_snap.dart';

/// 緯度方向の1マスの度数(テスト用に定数から求める)。
const double _latStep = kGridMeters / 111320;
const double _latMarginDeg = kGridHysteresisMeters / 111320;

void main() {
  group('gridCellOf / gridCenterOf', () {
    test('同じマスの2点は同じマス番号になる', () {
      final a = gridCellOf(35.1801, 139.9301);
      final center = gridCenterOf(a.x, a.y);
      final b = gridCellOf(center.lat + 0.0002, center.lng + 0.0002);
      expect(b, a);
    });

    test('マスをまたぐと結果が変わる', () {
      final a = gridCellOf(35.18, 139.93);
      final center = gridCenterOf(a.x, a.y);
      final north = gridCellOf(center.lat + _latStep, center.lng);
      expect(north.y, a.y + 1);
      expect(north.x, a.x);
    });

    test('中心は(番号+0.5)*刻みで、元の点を含むマスの中心になる', () {
      final c = gridCenterOf(2, 3);
      expect(c.lat, closeTo(3.5 * _latStep, 1e-12));
      final cell = gridCellOf(c.lat, c.lng);
      expect(cell, (x: 2, y: 3));
    });

    test('負の緯度経度でもfloorで切る(0方向に切らない)', () {
      expect(gridCellOf(-0.0001, -0.0001), (x: -1, y: -1));
      expect(gridCellOf(0.0001, 0.0001), (x: 0, y: 0));
      final c = gridCenterOf(-1, -1);
      expect(c.lat, lessThan(0));
      expect(c.lng, lessThan(0));
    });

    test('点から中心までの距離はマスの対角線の半分以内', () {
      final cell = gridCellOf(35.1812, 139.9345);
      final c = gridCenterOf(cell.x, cell.y);
      final dLatM = (c.lat - 35.1812).abs() * 111320;
      expect(dLatM, lessThanOrEqualTo(kGridMeters / 2 + 1e-6));
    });
  });

  group('stableGridCell', () {
    test('previousがnullなら今いるマス', () {
      expect(
        stableGridCell(lat: 35.18, lng: 139.93, previous: null),
        gridCellOf(35.18, 139.93),
      );
    });

    test('緯度だけ境目をまたいでも、余裕の中ならpreviousのまま', () {
      const previous = (x: 1000, y: 2000);
      final c = gridCenterOf(previous.x, previous.y);
      // 北の境目を余裕の半分だけ越えた位置。
      final lat = c.lat + _latStep / 2 + _latMarginDeg / 2;
      expect(gridCellOf(lat, c.lng).y, previous.y + 1);
      expect(
        stableGridCell(lat: lat, lng: c.lng, previous: previous),
        previous,
      );
    });

    test('緯度が余裕を越えたら新しいマスになる', () {
      const previous = (x: 1000, y: 2000);
      final c = gridCenterOf(previous.x, previous.y);
      final lat = c.lat + _latStep / 2 + _latMarginDeg * 2;
      final result = stableGridCell(lat: lat, lng: c.lng, previous: previous);
      expect(result, (x: previous.x, y: previous.y + 1));
    });

    test('経度だけ境目をまたいだ場合も余裕の中なら維持、越えたら切替', () {
      const previous = (x: 1000, y: 2000);
      final c = gridCenterOf(previous.x, previous.y);
      final next = gridCenterOf(previous.x + 1, previous.y);
      final halfLng = next.lng - c.lng;
      // 余裕は経度で30mぶん。1度あたり約91.0kmなので約0.00033度。
      final inside = c.lng + halfLng / 2 + 0.0001;
      expect(gridCellOf(c.lat, inside).x, previous.x + 1);
      expect(
        stableGridCell(lat: c.lat, lng: inside, previous: previous),
        previous,
      );
      final outside = c.lng + halfLng / 2 + 0.001;
      expect(
        stableGridCell(lat: c.lat, lng: outside, previous: previous),
        (x: previous.x + 1, y: previous.y),
      );
    });

    test('2マス以上離れた位置に飛んだら新しいマスになる', () {
      const previous = (x: 1000, y: 2000);
      final far = gridCenterOf(previous.x + 5, previous.y - 3);
      expect(
        stableGridCell(lat: far.lat, lng: far.lng, previous: previous),
        (x: previous.x + 5, y: previous.y - 3),
      );
    });

    test('境目に立って揺れても、点が往復しない', () {
      var cell = stableGridCell(lat: 35.18, lng: 139.93, previous: null);
      final c = gridCenterOf(cell.x, cell.y);
      final boundary = c.lat + _latStep / 2;
      final seen = <GridCell>{};
      for (final d in [-0.00008, 0.00008, -0.00005, 0.00005, 0.0001]) {
        cell = stableGridCell(lat: boundary + d, lng: c.lng, previous: cell);
        seen.add(cell);
      }
      expect(seen.length, 1);
    });
  });

  group('UserLocation.displayPoint', () {
    test('丸めた値があればそれを使う', () {
      const loc = UserLocation(
        uid: 'a',
        latitude: 35.18,
        longitude: 139.93,
        snapLatitude: 35.1,
        snapLongitude: 139.9,
      );
      expect(loc.displayPoint, (lat: 35.1, lng: 139.9));
    });

    test('丸めた値が無い旧端末は、読む側でマスの中心に丸める', () {
      const loc = UserLocation(uid: 'a', latitude: 35.18, longitude: 139.93);
      final cell = gridCellOf(35.18, 139.93);
      expect(loc.displayPoint, gridCenterOf(cell.x, cell.y));
      expect(loc.latitude, 35.18);
    });
  });
}
