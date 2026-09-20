import 'dart:math' as math;

import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:latlong2/latlong.dart' as latlong;

/// 距離・方位の計算に使う実装。
///
/// `Geolocator.distanceBetween` ではなく latlong2 の `Distance` を
/// 使うのは、前者がstaticでテストから差し替えられないため(issue #61の
/// 実装メモ)。latlong2は純粋Dartなので、端末もプラグインも無しに
/// `flutter test` から直接呼べる。
///
/// 既定の `roundResult: true` のまま使うので、返る距離は1m単位に丸められる。
/// 表示は「約◯m」なので丸めで困らず、猶予距離(数十m)の判定にも影響しない。
const _distance = latlong.Distance();

/// 8方位の日本語ラベル。北から時計回りに45度刻み。
const _compassLabels = ['北', '北東', '東', '南東', '南', '南西', '西', '北西'];

/// 座標が完全に一致しなくても「辺の上」「頂点の上」とみなす許容誤差(度)。
///
/// 1e-12度は赤道上で約0.1マイクロメートルに相当し、GPSの精度から見れば
/// ゼロと同じ。浮動小数の丸め誤差で境界上の点が外側に落ちるのを防ぐためだけの値。
const _onBoundaryToleranceDeg = 1e-12;

/// 点が多角形[area]の内側かどうかを ray casting で判定する。
///
/// [area]が3点未満(=プレイエリア未設定のルーム)の場合は常にtrueを返す。
/// エリアが無いルームで「全員がエリア外」になってしまうのを防ぐため
/// (issue #61「エリア未設定のルームでは何も出さない」)。
///
/// 境界(辺の上・頂点の上)は内側として扱う。境界ちょうどで警告を出しても
/// 逃げ場が無く、GPSの揺れで点滅するだけなので、安全側(警告しない)に倒す。
bool isInsideArea({required List<LatLng> area, required LatLng point}) {
  if (area.length < 3) return true;

  for (var i = 0; i < area.length; i++) {
    final a = area[i];
    final b = area[(i + 1) % area.length];
    if (_isOnSegment(a, b, point)) return true;
  }

  // 点から東(経度+方向)へ半直線を伸ばし、辺と何回交差するかを数える。
  // 奇数回なら内側。`(a.lat > point.lat) != (b.lat > point.lat)` で
  // 「辺が点の緯度をまたぐか」を見て、またぐ辺だけ交点の経度を計算する。
  var isInside = false;
  for (var i = 0; i < area.length; i++) {
    final a = area[i];
    final b = area[(i + 1) % area.length];
    if ((a.lat > point.lat) == (b.lat > point.lat)) continue;
    final crossingLng =
        (b.lng - a.lng) * (point.lat - a.lat) / (b.lat - a.lat) + a.lng;
    if (point.lng < crossingLng) isInside = !isInside;
  }
  return isInside;
}

/// エリアの外にいるとき、戻るための距離(m)と方位(度)を返す。内側ならnull。
///
/// 「戻る先」は多角形の各辺への最短点。頂点の外側にいる場合は自動的に
/// その頂点が最短点になる(線分への射影をクランプしているため)。
///
/// `bearingDegrees`は北=0・東=90の時計回り0〜360度。そのまま[compassLabel]に
/// 渡せば8方位の日本語になる。
({double meters, double bearingDegrees})? describeReturnToArea({
  required List<LatLng> area,
  required LatLng point,
}) {
  if (isInsideArea(area: area, point: point)) return null;

  final target = _nearestPointOnPolygon(area: area, point: point);
  final from = latlong.LatLng(point.lat, point.lng);
  final to = latlong.LatLng(target.lat, target.lng);
  return (
    meters: _distance.distance(from, to),
    bearingDegrees: latlong.normalizeBearing(_distance.bearing(from, to)),
  );
}

/// 方位角(度)を8方位の日本語ラベルへ変換する。0→「北」、315→「北西」。
///
/// 45度ごとの境界は四捨五入で決める(22.5度未満は「北」、22.5度以上は
/// 「北東」)。0〜360の範囲外の値が来ても正規化して扱う。
String compassLabel(double bearingDegrees) {
  final normalized = latlong.normalizeBearing(bearingDegrees);
  return _compassLabels[(normalized / 45).round() % _compassLabels.length];
}

/// 「エリアまで約◯m」に出す距離の文字列。
///
/// 数十メートル単位でしか意味を持たない情報なので、小数は出さない。
/// 1km以上離れている場合(ゲーム中には起きにくいが、エリアを離れたまま
/// 移動した場合など)だけkm表記に切り替える。
String formatReturnDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
  return '${meters.round()}m';
}

/// 境界からこの距離(m)以上はみ出して初めて警告を出す(猶予距離)。
///
/// スマートフォンのGPSは街中で10m前後ずれるため、境界ちょうどを閾値に
/// すると、エリア内に立っていても揺らぎだけで外判定に振れる。
const outsideAreaGraceDistanceMeters = 15.0;

/// 猶予距離を超えて外にいる状態がこれだけ続いて初めて警告に切り替える(猶予時間)。
///
/// GPSが一瞬だけ大きく飛ぶ(マルチパス等)ケースを、距離だけでは弾けないため。
const outsideAreaGraceDuration = Duration(seconds: 10);

/// エリア外警告を出すかどうかを、猶予距離・猶予時間を通して決める。
///
/// 考え方は`proximity_calculator.dart`の`applyProximityHysteresis`と同じで、
/// 「生の判定をそのまま表示に使わず、直前の表示状態と時刻を持ち越して
/// ならす」もの。判定そのものは呼び出し側が[describeReturnToArea]で出し、
/// ここには外にいる距離だけを渡す。
///
/// - [outsideMeters]: エリア外なら境界までの距離(m)、内側ならnull
/// - [wasWarning]: 前回この関数が返した`isWarning`
/// - [outsideSince]: 前回この関数が返した`outsideSince`(持ち越し用)
///
/// 遷移のルール:
/// 1. **エリア内に戻ったら即座に解除する**。振動と通知を止める方向は
///    遅らせる理由が無いので、安全側(すぐ止める)に倒す
/// 2. 一度警告に入ったら、エリア内に戻るまで解除しない。境界のすぐ外で
///    解除すると、猶予距離の境目で今度は警告が点滅するため
/// 3. 警告していないときは、[outsideMeters]が猶予距離以上の状態が
///    [graceDuration]続いたときだけ警告に切り替える。途中で猶予距離の
///    内側に戻ったら計測をやり直す(「連続して外」の判定)
///
/// 境界値は「以上・以下」で警告側に倒す(距離が猶予距離ちょうど、経過時間が
/// 猶予時間ちょうどなら警告する)。
({bool isWarning, DateTime? outsideSince}) applyOutsideAreaHysteresis({
  required double? outsideMeters,
  required bool wasWarning,
  required DateTime? outsideSince,
  required DateTime now,
  double graceDistanceMeters = outsideAreaGraceDistanceMeters,
  Duration graceDuration = outsideAreaGraceDuration,
}) {
  if (outsideMeters == null) return (isWarning: false, outsideSince: null);
  if (wasWarning) {
    return (isWarning: true, outsideSince: outsideSince ?? now);
  }
  if (outsideMeters < graceDistanceMeters) {
    return (isWarning: false, outsideSince: null);
  }

  final since = outsideSince ?? now;
  return (
    isWarning: now.difference(since) >= graceDuration,
    outsideSince: since,
  );
}

/// 多角形の各辺への最短点のうち、[point]に一番近いものを返す。
LatLng _nearestPointOnPolygon({
  required List<LatLng> area,
  required LatLng point,
}) {
  // 緯度1度と経度1度の長さは違う(経度側はcos(緯度)倍)。度のまま最短点を
  // 求めると東西方向を過大評価するので、経度をcos(緯度)で縮めた平面に
  // 投影して計算する。ゲームのプレイエリア(数百m〜数km)の範囲なら、この
  // 近似で選ばれる最短点は実用上ずれない(最終的な距離・方位は選んだ点に
  // 対してlatlong2で正確に計算し直す)。
  final lngScale = math.cos(point.lat * math.pi / 180);

  LatLng? nearest;
  var nearestSquared = double.infinity;
  for (var i = 0; i < area.length; i++) {
    final candidate = _nearestPointOnSegment(
      a: area[i],
      b: area[(i + 1) % area.length],
      point: point,
      lngScale: lngScale,
    );
    final dLat = candidate.lat - point.lat;
    final dLng = (candidate.lng - point.lng) * lngScale;
    final squared = dLat * dLat + dLng * dLng;
    if (squared < nearestSquared) {
      nearestSquared = squared;
      nearest = candidate;
    }
  }
  // areaは3点以上(isInsideAreaで確認済み)なので必ず見つかる。
  return nearest!;
}

/// 線分ab上で[point]に最も近い点。射影の位置を0〜1にクランプするので、
/// 線分からはみ出す場合は端点(=多角形の頂点)が返る。
LatLng _nearestPointOnSegment({
  required LatLng a,
  required LatLng b,
  required LatLng point,
  required double lngScale,
}) {
  final dLat = b.lat - a.lat;
  final dLng = (b.lng - a.lng) * lngScale;
  final lengthSquared = dLat * dLat + dLng * dLng;
  if (lengthSquared == 0) return a;

  final t =
      ((point.lat - a.lat) * dLat + (point.lng - a.lng) * lngScale * dLng) /
      lengthSquared;
  final clamped = t < 0
      ? 0.0
      : t > 1
      ? 1.0
      : t;
  return LatLng(
    lat: a.lat + (b.lat - a.lat) * clamped,
    lng: a.lng + (b.lng - a.lng) * clamped,
  );
}

/// [point]が線分ab上(端点含む)にあるか。
bool _isOnSegment(LatLng a, LatLng b, LatLng point) {
  final cross =
      (b.lat - a.lat) * (point.lng - a.lng) -
      (b.lng - a.lng) * (point.lat - a.lat);
  if (cross.abs() > _onBoundaryToleranceDeg) return false;
  return point.lat >= math.min(a.lat, b.lat) - _onBoundaryToleranceDeg &&
      point.lat <= math.max(a.lat, b.lat) + _onBoundaryToleranceDeg &&
      point.lng >= math.min(a.lng, b.lng) - _onBoundaryToleranceDeg &&
      point.lng <= math.max(a.lng, b.lng) + _onBoundaryToleranceDeg;
}
