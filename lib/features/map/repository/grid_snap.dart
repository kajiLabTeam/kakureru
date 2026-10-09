import 'dart:math' as math;

/// マスの一辺(メートル)。プレイ後に150へ落とす可能性があるので、ここだけ
/// 変えれば全体が追従する。
const kGridMeters = 200.0;

/// 境目のちらつき対策の余裕(メートル)。一度入ったマスからは、境目を
/// これだけ行き過ぎるまで出ない。
const kGridHysteresisMeters = 30.0;

/// 経度方向の距離を出すための基準緯度(度)。端末ごとにマスの幅がずれない
/// よう、生の緯度ではなくこの定数を使う。構内の緯度。
const kGridRefLatitude = 35.18;

/// 緯度1度あたりのメートル。
const _metersPerDegreeLat = 111320.0;

/// マス番号。原点は緯度経度のゼロ。
typedef GridCell = ({int x, int y});

double get _latStep => kGridMeters / _metersPerDegreeLat;

double get _lngStep =>
    kGridMeters /
    (_metersPerDegreeLat * math.cos(kGridRefLatitude * math.pi / 180));

/// 緯度経度が入るマスの番号を返す(境目のちらつき対策なし)。
///
/// `truncate` / `toInt` は0方向に切るので、負の値で1マスずれる。`floor` を使う。
GridCell gridCellOf(double lat, double lng) {
  return (x: (lng / _lngStep).floor(), y: (lat / _latStep).floor());
}

/// マス番号から、そのマスの中心の緯度経度。
({double lat, double lng}) gridCenterOf(int x, int y) {
  return (lat: (y + 0.5) * _latStep, lng: (x + 0.5) * _lngStep);
}

/// 境目のちらつき対策込みで、出すマスを決める。
///
/// [previous] のマスの範囲を [kGridHysteresisMeters] だけ外へ広げた矩形に
/// 生の位置が収まっていれば [previous] を維持する。緯度と経度は別々に
/// 判定する。外に出たら今いるマスへ切り替える。[previous] が null のときは
/// 今いるマス。
GridCell stableGridCell({
  required double lat,
  required double lng,
  required GridCell? previous,
}) {
  final current = gridCellOf(lat, lng);
  if (previous == null) return current;

  const margin = kGridHysteresisMeters / _metersPerDegreeLat;
  final marginLng =
      kGridHysteresisMeters /
      (_metersPerDegreeLat * math.cos(kGridRefLatitude * math.pi / 180));

  final latMin = previous.y * _latStep - margin;
  final latMax = (previous.y + 1) * _latStep + margin;
  final lngMin = previous.x * _lngStep - marginLng;
  final lngMax = (previous.x + 1) * _lngStep + marginLng;

  return (
    x: lng >= lngMin && lng < lngMax ? previous.x : current.x,
    y: lat >= latMin && lat < latMax ? previous.y : current.y,
  );
}
