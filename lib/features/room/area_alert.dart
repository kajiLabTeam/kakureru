import 'dart:math' as math;

import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/repository/location_smoothing.dart';
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

/// `rooms/{roomId}/locations/{uid}` の位置がこれより古ければ、判定に使わず
/// 「分からない」([OutsideAreaStatus.unknown])として扱う。
///
/// 位置送信は4秒間隔で、精度足切りが続いても
/// [LocationFilterThresholds.forceAcceptAfterElapsed](30秒)で必ず1件は
/// 書き込まれる。つまり送信が生きていれば`updatedAt`は最長でも30秒ごとに
/// 進む。書き込みとRTDBの伝搬の遅れを見込んで、その1.5倍をここでの
/// 「古い」の境目にする。
///
/// この足切りが無いと、位置送信が死んだ端末の座標が最後の値で固まり、
/// 本人がエリア内に戻っても永久に警告が解除されない。BLEの
/// `BleProximityThresholds.staleAfterMillis`(`isDetectionFresh`)と同じ
/// 考え方で、古い観測を「今の状況」として扱わない。
const outsideAreaLocationStaleAfter = Duration(seconds: 45);

/// 判定に使える位置が無い([OutsideAreaStatus.unknown])間、直前の判定を
/// 保ち続ける時間。
///
/// 一瞬の欠け(自分の位置がまだ届いていない・ルーム情報が一時的に
/// 取れない)で警告や猶予の計測がリセットされないようにするための保持。
/// ただし無期限に保つと、位置が分からないまま永久に振動し続けることに
/// なるため、これを過ぎたら判定を手放して警告も解除する。
const outsideAreaUnknownHoldDuration = Duration(seconds: 30);

/// 1回ぶんの観測([OutsideAreaObservation])が示す状態。
///
/// 「エリア内」と「分からない」を同じ値で表すと、位置が届いていないだけの
/// 状態がエリア内と同じ扱いになり、猶予の計測がリセットされたり、機内モードで
/// 警告を回避できたりする。3状態に分けてそれを防ぐ。
enum OutsideAreaStatus {
  /// 判定に使える新しい位置があり、エリアの内側にいる。
  inside,

  /// 判定に使える新しい位置があり、エリアの外にはみ出している。
  outside,

  /// 判定に使える位置が無い(まだ届いていない/古すぎる/ルーム情報が無い)。
  unknown,
}

/// 猶予判定([applyOutsideAreaHysteresis])へ渡す1回ぶんの観測。
///
/// `outsideMeters`・`bearingDegrees`・`accuracyMeters`は
/// [OutsideAreaStatus.outside]のときだけ意味を持つ。`updatedAt`は観測に
/// 使った測位の時刻(サーバー時刻のエポックミリ秒)で、
/// [OutsideAreaStatus.unknown]のときは0。
typedef OutsideAreaObservation = ({
  OutsideAreaStatus status,
  double outsideMeters,
  double bearingDegrees,
  double accuracyMeters,
  int updatedAt,
});

/// 判定に使える位置が無いときの観測。
const OutsideAreaObservation unknownOutsideAreaObservation = (
  status: OutsideAreaStatus.unknown,
  outsideMeters: 0,
  bearingDegrees: 0,
  accuracyMeters: 0,
  updatedAt: 0,
);

/// [applyOutsideAreaHysteresis]が持ち越す状態。
///
/// - `isWarning`: いま警告を出しているか
/// - `outsideSince`: 猶予時間の計測を始めた時刻(計測していなければnull)
/// - `outsideSinceUpdatedAt`: 計測を始めた時点の測位の時刻。猶予のあいだに
///   新しい測位が来たかを見るために持つ
/// - `lastKnownAt`: 最後に判定できた(unknownでなかった)時刻。分からない
///   状態がどれだけ続いているかを測るために持つ
typedef OutsideAreaWarningState = ({
  bool isWarning,
  DateTime? outsideSince,
  int outsideSinceUpdatedAt,
  DateTime? lastKnownAt,
});

/// 警告も計測もしていない初期状態。
const OutsideAreaWarningState initialOutsideAreaWarningState = (
  isWarning: false,
  outsideSince: null,
  outsideSinceUpdatedAt: 0,
  lastKnownAt: null,
);

/// 自分の位置とプレイエリアから、猶予判定へ渡す観測を作る。
///
/// - [area]: プレイエリアの頂点。ルーム情報がまだ取れていなければnullを
///   渡すこと(「エリア未設定のルーム」= 3点未満 とは区別する。未設定なら
///   常に[OutsideAreaStatus.inside]になり、アラートは何も出ない)
/// - [location]: 自分の位置。まだ届いていなければnull
/// - [nowMillis]: 現在のサーバー時刻(`serverNowMillis`)。`updatedAt`は
///   `ServerValue.timestamp`で書かれるので、端末時刻と比べてはいけない
///
/// 位置が無い・古い・ルーム情報が無い場合は[OutsideAreaStatus.unknown]を
/// 返す。呼び出し側(猶予判定)はその間、直前の判定を保つ。
OutsideAreaObservation observeOutsideArea({
  required List<LatLng>? area,
  required UserLocation? location,
  required int nowMillis,
  Duration staleAfter = outsideAreaLocationStaleAfter,
}) {
  if (area == null || location == null) return unknownOutsideAreaObservation;
  // updatedAtが0なのは、書き込み途中などで時刻が入っていないエントリ。
  // いつの位置か分からない以上、判定には使わない。
  if (location.updatedAt <= 0) return unknownOutsideAreaObservation;
  if (nowMillis - location.updatedAt > staleAfter.inMilliseconds) {
    return unknownOutsideAreaObservation;
  }

  final returnToArea = describeReturnToArea(
    area: area,
    point: LatLng(lat: location.latitude, lng: location.longitude),
  );
  if (returnToArea == null) {
    return (
      status: OutsideAreaStatus.inside,
      outsideMeters: 0,
      bearingDegrees: 0,
      accuracyMeters: 0,
      updatedAt: location.updatedAt,
    );
  }
  return (
    status: OutsideAreaStatus.outside,
    outsideMeters: returnToArea.meters,
    bearingDegrees: returnToArea.bearingDegrees,
    accuracyMeters: location.accuracy ?? 0,
    updatedAt: location.updatedAt,
  );
}

/// 報告された測位精度[accuracyMeters]のぶん、猶予距離をどれだけ広げるか。
///
/// 猶予距離15mに対し、採用される測位のaccuracyは
/// [LocationFilterThresholds.maxAcceptableAccuracyM](30m)まで許している。
/// 精度を無視すると、誤差25mの測位でエリア内10mに立っている人が警告を
/// 受けてしまうため、報告された誤差ぶんは猶予を広げる。
///
/// - accuracyが0以下は**精度不明**(geolocatorは精度を報告できない端末で
///   0.0を返す。location_smoothing.dartのコメント参照)。どれだけずれて
///   いるか分からないので、足切りの上限を最悪値として使う
/// - 報告があっても上限でクランプする。強制採用
///   ([LocationUpdateDecision.acceptedByFallback])では足切りを超えた測位も
///   通るため、基地局測位のaccuracy=2000mのような値をそのまま足すと
///   猶予距離が実質無限になり、アラートが機能しなくなる
double outsideAreaAccuracyAllowanceMeters(double accuracyMeters) {
  const maxAllowance = LocationFilterThresholds.maxAcceptableAccuracyM;
  if (accuracyMeters <= 0) return maxAllowance;
  return math.min(accuracyMeters, maxAllowance);
}

/// エリア外警告を出すかどうかを、猶予距離・猶予時間を通して決める。
///
/// 考え方は`proximity_calculator.dart`の`applyProximityHysteresis`と同じで、
/// 「生の判定をそのまま表示に使わず、直前の表示状態と時刻を持ち越して
/// ならす」もの。判定そのものは[observeOutsideArea]が出し、ここはその
/// 観測([observation])と前回の状態([previous])から次の状態を決める。
///
/// 遷移のルール:
/// 1. **エリア内に戻ったら即座に解除する**。振動と通知を止める方向は
///    遅らせる理由が無いので、安全側(すぐ止める)に倒す
/// 2. 一度警告に入ったら、エリア内に戻るまで解除しない。境界のすぐ外で
///    解除すると、猶予距離の境目で今度は警告が点滅するため
/// 3. 警告していないときは、はみ出し距離が「猶予距離 + 測位精度ぶんの
///    上乗せ」以上の状態が[graceDuration]続き、**かつその間に新しい測位が
///    届いた**ときだけ警告に切り替える。時間だけで満了させると、マルチパスで
///    飛んだ1点が採用されたあと後続が精度足切りで棄却され続けた場合に、
///    その1点だけで警告が成立してしまう(最大20秒固まる:
///    [LocationFilterThresholds.forceAcceptAfterRejections]×4秒間隔)
/// 4. 判定に使える位置が無い間([OutsideAreaStatus.unknown])は直前の判定を
///    そのまま保つ。一瞬の欠けで猶予の計測がリセットされたり、警告が
///    消えたりしないようにするため。ただし[unknownHold]を過ぎても分から
///    ないままなら、判定を手放して警告を解除する(位置が分からない相手を
///    永久に振動させ続けないため)
///
/// 境界値は「以上・以下」で警告側に倒す(距離が猶予距離ちょうど、経過時間が
/// 猶予時間ちょうどなら警告する)。
OutsideAreaWarningState applyOutsideAreaHysteresis({
  required OutsideAreaObservation observation,
  required OutsideAreaWarningState previous,
  required DateTime now,
  double graceDistanceMeters = outsideAreaGraceDistanceMeters,
  Duration graceDuration = outsideAreaGraceDuration,
  Duration unknownHold = outsideAreaUnknownHoldDuration,
}) {
  switch (observation.status) {
    case OutsideAreaStatus.unknown:
      final lastKnownAt = previous.lastKnownAt;
      // 一度も判定できていなければ、保持する判定自体が無い。
      if (lastKnownAt == null) return previous;
      if (now.difference(lastKnownAt) < unknownHold) return previous;
      return initialOutsideAreaWarningState;

    case OutsideAreaStatus.inside:
      return (
        isWarning: false,
        outsideSince: null,
        outsideSinceUpdatedAt: 0,
        lastKnownAt: now,
      );

    case OutsideAreaStatus.outside:
      if (previous.isWarning) {
        return (
          isWarning: true,
          outsideSince: previous.outsideSince ?? now,
          outsideSinceUpdatedAt: previous.outsideSinceUpdatedAt,
          lastKnownAt: now,
        );
      }

      final grace =
          graceDistanceMeters +
          outsideAreaAccuracyAllowanceMeters(observation.accuracyMeters);
      if (observation.outsideMeters < grace) {
        return (
          isWarning: false,
          outsideSince: null,
          outsideSinceUpdatedAt: 0,
          lastKnownAt: now,
        );
      }

      final since = previous.outsideSince ?? now;
      final sinceUpdatedAt = previous.outsideSince == null
          ? observation.updatedAt
          : previous.outsideSinceUpdatedAt;
      // 猶予を始めた測位より新しいものが届いているか(ルール3)。
      final hasNewerFix = observation.updatedAt > sinceUpdatedAt;
      return (
        isWarning: hasNewerFix && now.difference(since) >= graceDuration,
        outsideSince: since,
        outsideSinceUpdatedAt: sinceUpdatedAt,
        lastKnownAt: now,
      );
  }
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
