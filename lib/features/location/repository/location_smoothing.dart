import 'package:geolocator/geolocator.dart';

/// 位置の平滑化(ノイズ除去)に使う閾値。
///
/// 実機でのGPS挙動が確認できない環境で決めた初期値のため、実機での
/// チューニングが前提(docs/gps-location-stability.md参照)。
class LocationFilterThresholds {
  const LocationFilterThresholds._();

  /// これを超えるaccuracy(m)の測位は信頼できないとして捨てる。
  /// 屋内ではGPS単体の誤差がこれを大きく超えることがある。
  ///
  /// この足切りだけでは、屋内で慢性的に精度が悪い参加者の位置が
  /// RTDBへ一度も書かれなくなる(地図から消えるだけでなく、同じノードの子
  /// である気圧・Wi-Fi情報まで他の参加者から見えなくなる)ため、
  /// [forceAcceptAfterRejections] / [forceAcceptAfterElapsed] による
  /// 強制更新と必ずセットで使うこと。
  static const maxAcceptableAccuracyM = 30.0;

  /// 直前に採用した位置からの移動距離がこれ未満なら、実際には静止して
  /// いるとみなし位置を更新しない(デッドバンド)。GPSノイズによって
  /// 静止中でもピンが近辺を飛び回るのを抑えるための閾値。
  static const deadbandDistanceM = 8.0;

  /// 連続でこの回数だけ棄却が続いたら、その回は判定結果にかかわらず採用する
  /// (強制更新)。位置取得は4秒間隔のため、5回 ≒ 20秒に相当する。
  ///
  /// **実機での調整が前提**: 小さすぎるとノイズや信頼できない測位をそのまま
  /// 通してしまい、大きすぎると位置が更新されない空白時間が長くなる。
  static const forceAcceptAfterRejections = 5;

  /// 最後に採用してからこの時間が経過したら、判定結果にかかわらず採用する
  /// (強制更新)。取得間隔が変わったり測位の取得自体が間引かれたりしても、
  /// 「位置と`updatedAt`が更新されない最長時間」をこの値で押さえられる。
  ///
  /// **実機での調整が前提**: [forceAcceptAfterRejections] と同じトレードオフ。
  static const forceAcceptAfterElapsed = Duration(seconds: 30);
}

/// [evaluateLocationUpdate] の判定結果。
///
/// 棄却理由を戻り値として返し、ログ出力(副作用)は呼び出し側に任せることで、
/// 判定ロジック自体は純粋関数のままテストできるようにしている。
enum LocationUpdateDecision {
  /// 通常の判定で採用。
  accepted,

  /// 本来は棄却だが、更新が止まり続けるのを防ぐため強制的に採用した。
  acceptedByFallback,

  /// accuracyが閾値を超えている(測位が信頼できない)ため棄却。
  rejectedLowAccuracy,

  /// 直前に採用した位置からの移動がデッドバンド未満のため棄却。
  rejectedDeadband;

  /// RTDBへ書き込むべきか(採用されたか)。
  bool get isAccepted =>
      this == LocationUpdateDecision.accepted ||
      this == LocationUpdateDecision.acceptedByFallback;
}

/// 新しい測位結果を採用するか判定する。
///
/// 判定順序(いずれかに該当したら確定):
/// 1. [accuracy]が[maxAcceptableAccuracyM]を超える → 棄却
///    ([LocationUpdateDecision.rejectedLowAccuracy])
/// 2. 直前に採用した位置([previousLatitude]/[previousLongitude])が無い
///    (初回) → 採用
/// 3. 直前に採用した位置からの距離が[deadbandDistanceM]未満 → 棄却
///    ([LocationUpdateDecision.rejectedDeadband])
/// 4. それ以外 → 採用
///
/// ただし 1. / 3. で棄却する場合でも、次のいずれかを満たすときは
/// [LocationUpdateDecision.acceptedByFallback] として採用する(強制更新):
///
/// - 今回を棄却すると連続棄却が[forceAcceptAfterRejections]回に達する
///   ([consecutiveRejectionCount]は今回を含まない直前までの連続棄却回数)
/// - 最後に採用してからの経過時間([elapsedSinceLastAccepted])が
///   [forceAcceptAfterElapsed]以上
///
/// この強制更新が無いと、屋内でaccuracyが慢性的に悪い参加者は
/// `rooms/{roomId}/locations/{uid}` にlat/lngが一度も書かれず、地図上から
/// 消えるだけでなく、同じノードの子として書かれる気圧・Wi-Fi情報まで
/// 他の参加者から見えなくなる(lat/lngを欠いたノードは`UserLocation.fromMap`
/// が例外を投げ、購読側の`watchLocations`がそのエントリを丸ごとスキップ
/// するため)。屋内をWi-Fiと気圧で補うというこのアプリの前提そのものが
/// 崩れるので、足切りは必ずこのフォールバックとセットで使う。
/// デッドバンド由来の「ゆっくり移動していると位置も`updatedAt`も
/// 更新されない」問題も、同じ仕組みで併せて解消している。
///
/// [accuracy]について: geolocatorの`Position.accuracy`は非nullの`double`で、
/// **端末が精度を報告できない場合は0.0**が入る。つまり「精度不明」は
/// この関数には0.0(=最良)として渡り、足切りを素通りする。null分岐は
/// accuracyキー自体が欠けたデータが渡ってきた場合の保険であり、
/// geolocatorからの正常系では到達しない。
///
/// 呼び出し側は、採用した場合にのみ
/// [previousLatitude]/[previousLongitude]を今回の値で更新すること
/// (棄却時に更新すると、ゆっくりした実移動がデッドバンドを永遠に
/// 超えられなくなる)。あわせて、採用時は[consecutiveRejectionCount]を0に
/// 戻して[elapsedSinceLastAccepted]の起点を更新し、棄却時は
/// [consecutiveRejectionCount]を1増やすこと。
LocationUpdateDecision evaluateLocationUpdate({
  required double latitude,
  required double longitude,
  required double? accuracy,
  required double? previousLatitude,
  required double? previousLongitude,
  required int consecutiveRejectionCount,
  required Duration elapsedSinceLastAccepted,
  double maxAcceptableAccuracyM =
      LocationFilterThresholds.maxAcceptableAccuracyM,
  double deadbandDistanceM = LocationFilterThresholds.deadbandDistanceM,
  int forceAcceptAfterRejections =
      LocationFilterThresholds.forceAcceptAfterRejections,
  Duration forceAcceptAfterElapsed =
      LocationFilterThresholds.forceAcceptAfterElapsed,
}) {
  final rejection = _rejectionReason(
    latitude: latitude,
    longitude: longitude,
    accuracy: accuracy,
    previousLatitude: previousLatitude,
    previousLongitude: previousLongitude,
    maxAcceptableAccuracyM: maxAcceptableAccuracyM,
    deadbandDistanceM: deadbandDistanceM,
  );
  if (rejection == null) return LocationUpdateDecision.accepted;

  final reachesRejectionLimit =
      consecutiveRejectionCount + 1 >= forceAcceptAfterRejections;
  final waitedTooLong = elapsedSinceLastAccepted >= forceAcceptAfterElapsed;
  if (reachesRejectionLimit || waitedTooLong) {
    return LocationUpdateDecision.acceptedByFallback;
  }
  return rejection;
}

/// 強制更新を考慮しない素の棄却理由。採用すべきならnullを返す。
LocationUpdateDecision? _rejectionReason({
  required double latitude,
  required double longitude,
  required double? accuracy,
  required double? previousLatitude,
  required double? previousLongitude,
  required double maxAcceptableAccuracyM,
  required double deadbandDistanceM,
}) {
  if (accuracy != null && accuracy > maxAcceptableAccuracyM) {
    return LocationUpdateDecision.rejectedLowAccuracy;
  }
  if (previousLatitude == null || previousLongitude == null) return null;
  final movedM = Geolocator.distanceBetween(
    previousLatitude,
    previousLongitude,
    latitude,
    longitude,
  );
  if (movedM < deadbandDistanceM) {
    return LocationUpdateDecision.rejectedDeadband;
  }
  return null;
}
