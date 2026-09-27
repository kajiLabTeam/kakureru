import 'package:geolocator/geolocator.dart';
import 'package:kakureru/features/location/model/location_sample.dart';

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

  /// 強制更新で「棄却していた間の最良の測位」を書くとき、候補にできる
  /// 測位の古さの上限(受け取ってからの時間)。
  ///
  /// 精度だけで選ぶと、走っている人の20〜30秒前の位置が今の時刻付きで
  /// 書かれ、何十mも後ろにピンが出てしまう。送信間隔(4秒)の2回分に
  /// 絞り、これより古い候補は使わず今回の測位を書く。
  static const fallbackCandidateMaxAge = Duration(seconds: 8);
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
  rejectedDeadband,

  /// すでに受け取った測位より古い(または同じ)時刻の測位のため棄却
  /// (issue #117)。取得の完了順が入れ替わると、古い位置が新しい位置の
  /// 後に書かれてピンが一瞬逆戻りするのを防ぐ。強制更新の対象にもしない。
  rejectedStale;

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

/// [LocationUpdateFilter.offer] の結果。
///
/// `toWrite` は RTDB へ書くべき測位で、棄却なら null。強制更新のときは
/// 今回渡した測位ではなく、棄却が続いた間で最も精度の良かった測位になる
/// ことがある。
typedef LocationFilterResult = ({
  LocationUpdateDecision decision,
  LocationSample? toWrite,
});

/// 測位を1件ずつ受け取り、RTDBへ書くべきものだけを返す状態付きフィルタ。
///
/// 判定そのものは純粋関数 [evaluateLocationUpdate] に任せ、ここでは
/// 呼び出し側が守るべき状態の更新規則(直前の採用位置・連続棄却回数・
/// 最終採用時刻のリセット)をまとめて持つ。以前は `LocationRepository` の
/// コールバック内に直接書いていたが、Firebaseに触れるためテストできな
/// かった(issue #117 で規則が増えたので切り出した)。
///
/// issue #117 で足した規則は2つ:
///
/// - **古い測位を捨てる**: すでに受け取った測位以前の時刻のものは
///   [LocationUpdateDecision.rejectedStale] として捨てる。これも連続棄却に
///   数え、強制更新の対象にする。端末の時計のずれなどで未来の時刻の測位が
///   1件来ると、以後の測位がすべて「古い」扱いになるため、強制更新で
///   採用したときに時刻の基準をその測位へ戻して抜け出せるようにしている
/// - **強制更新では最良の測位を書く**: 以前は強制更新の回に来た測位を
///   そのまま書いていたため、accuracyが100m級の値でも書かれ、次の良い
///   測位で戻る「遠くへ飛んで戻る」動きになっていた。直近
///   ([LocationFilterThresholds.fallbackCandidateMaxAge]以内)に棄却した
///   測位と今回の測位のうち、accuracyが最も良いものを書くようにする
class LocationUpdateFilter {
  /// [startedAt] は強制更新の経過時間の起点。まだ一度も採用していない間も
  /// 時間による強制更新が効くよう、送信開始時刻を渡す。
  LocationUpdateFilter({required DateTime startedAt})
    : _lastAcceptedAt = startedAt;

  double? _lastAcceptedLat;
  double? _lastAcceptedLng;
  int _consecutiveRejections = 0;
  DateTime _lastAcceptedAt;
  int? _latestTimestampMs;

  /// 前回採用してから棄却した測位のうち、accuracyが最も良いものと、
  /// それを受け取った時刻。古くなった候補は捨てる([_rememberRejected])。
  ({LocationSample sample, DateTime receivedAt})? _bestRejected;

  /// 直前まで連続して棄却した回数(ログ用)。
  int get consecutiveRejections => _consecutiveRejections;

  /// 最後に採用した時刻(ログ用)。
  DateTime get lastAcceptedAt => _lastAcceptedAt;

  /// 測位 [sample] を1件渡し、書くべきかを判定する。[now] は受け取った時刻。
  LocationFilterResult offer(LocationSample sample, {required DateTime now}) {
    final elapsed = now.difference(_lastAcceptedAt);
    final timestampMs = sample.timestampMs;
    final latest = _latestTimestampMs;
    final isStale =
        timestampMs != null && latest != null && timestampMs <= latest;

    final LocationUpdateDecision decision;
    if (isStale) {
      // 古い測位も連続棄却に数え、強制更新の条件は通常の棄却と揃える。
      final forced =
          _consecutiveRejections + 1 >=
              LocationFilterThresholds.forceAcceptAfterRejections ||
          elapsed >= LocationFilterThresholds.forceAcceptAfterElapsed;
      decision = forced
          ? LocationUpdateDecision.acceptedByFallback
          : LocationUpdateDecision.rejectedStale;
    } else {
      if (timestampMs != null) _latestTimestampMs = timestampMs;
      decision = evaluateLocationUpdate(
        latitude: sample.latitude,
        longitude: sample.longitude,
        accuracy: sample.accuracy,
        previousLatitude: _lastAcceptedLat,
        previousLongitude: _lastAcceptedLng,
        consecutiveRejectionCount: _consecutiveRejections,
        elapsedSinceLastAccepted: elapsed,
      );
    }

    if (!decision.isAccepted) {
      _consecutiveRejections++;
      _rememberRejected(sample, now);
      return (decision: decision, toWrite: null);
    }

    final toWrite = decision == LocationUpdateDecision.acceptedByFallback
        ? moreAccurateSample(_recentBestRejected(now), sample)
        : sample;
    // 古い測位を強制採用したときは、時刻の基準を今回の測位へ戻す。未来の
    // 時刻が基準に居座ったままだと、以後の測位がすべて捨てられ続けるため。
    if (isStale) _latestTimestampMs = timestampMs;
    _lastAcceptedLat = toWrite.latitude;
    _lastAcceptedLng = toWrite.longitude;
    _consecutiveRejections = 0;
    _lastAcceptedAt = now;
    _bestRejected = null;
    return (decision: decision, toWrite: toWrite);
  }

  /// 棄却した測位を、強制更新の候補として覚える。すでに覚えている候補が
  /// 古くなっていれば、精度に関係なく今回の測位に置き換える。
  void _rememberRejected(LocationSample sample, DateTime now) {
    final best = _recentBestRejected(now);
    final chosen = moreAccurateSample(best, sample);
    _bestRejected = identical(chosen, sample)
        ? (sample: sample, receivedAt: now)
        : _bestRejected;
  }

  /// 覚えている候補のうち、まだ古くなっていないもの。無ければnull。
  LocationSample? _recentBestRejected(DateTime now) {
    final best = _bestRejected;
    if (best == null) return null;
    final age = now.difference(best.receivedAt);
    if (age > LocationFilterThresholds.fallbackCandidateMaxAge) return null;
    return best.sample;
  }
}

/// 2つの測位のうちaccuracyが良い(小さい)方を返す。[current] がnullなら
/// [candidate]。同じなら新しい方の [candidate] を選ぶ(位置は新しいほど
/// 実態に近いため)。
///
/// accuracyがnull(キー欠け)の測位は精度が分からないので最も悪い扱いにする。
/// 0.0(geolocatorで「精度不明」)は [evaluateLocationUpdate] の足切りと
/// 揃えて、値どおり最良として扱う。
LocationSample moreAccurateSample(
  LocationSample? current,
  LocationSample candidate,
) {
  if (current == null) return candidate;
  final currentAccuracy = current.accuracy ?? double.infinity;
  final candidateAccuracy = candidate.accuracy ?? double.infinity;
  return candidateAccuracy <= currentAccuracy ? candidate : current;
}
