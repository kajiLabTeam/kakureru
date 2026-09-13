import 'package:geolocator/geolocator.dart';

/// 位置の平滑化(ノイズ除去)に使う閾値。
///
/// 実機でのGPS挙動が確認できない環境で決めた初期値のため、実機での
/// チューニングが前提(docs/gps-location-stability.md参照)。
class LocationFilterThresholds {
  const LocationFilterThresholds._();

  /// これを超えるaccuracy(m)の測位は信頼できないとして捨てる。
  /// 屋内ではGPS単体の誤差がこれを大きく超えることがある。
  static const maxAcceptableAccuracyM = 30.0;

  /// 直前に採用した位置からの移動距離がこれ未満なら、実際には静止して
  /// いるとみなし位置を更新しない(デッドバンド)。GPSノイズによって
  /// 静止中でもピンが近辺を飛び回るのを抑えるための閾値。
  static const deadbandDistanceM = 8.0;
}

/// 新しい測位結果を採用するか判定する。
///
/// 判定順序(いずれかに該当したら確定):
/// 1. [accuracy]が[maxAcceptableAccuracyM]を超える → 不採用
///    ([accuracy]がnullの場合、この足切りは行わない)
/// 2. 直前に採用した位置([previousLatitude]/[previousLongitude])が無い
///    (初回) → 採用
/// 3. 直前に採用した位置からの距離が[deadbandDistanceM]未満 → 不採用
/// 4. それ以外 → 採用
///
/// 呼び出し側は、採用した(trueが返った)場合にのみ
/// [previousLatitude]/[previousLongitude]を今回の値で更新すること
/// (不採用時に更新すると、ゆっくりした実移動がデッドバンドを永遠に
/// 超えられなくなる)。
bool shouldAcceptLocationUpdate({
  required double latitude,
  required double longitude,
  required double? accuracy,
  required double? previousLatitude,
  required double? previousLongitude,
  double maxAcceptableAccuracyM =
      LocationFilterThresholds.maxAcceptableAccuracyM,
  double deadbandDistanceM = LocationFilterThresholds.deadbandDistanceM,
}) {
  if (accuracy != null && accuracy > maxAcceptableAccuracyM) return false;
  if (previousLatitude == null || previousLongitude == null) return true;
  final movedM = Geolocator.distanceBetween(
    previousLatitude,
    previousLongitude,
    latitude,
    longitude,
  );
  return movedM >= deadbandDistanceM;
}
