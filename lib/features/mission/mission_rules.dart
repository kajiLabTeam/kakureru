/// ミッションの生成・期限・GPSの到着判定・先着1名の取り合いの純粋な計算。
/// RTDBやプラグインに依存しないため、実機なしで単体テストできる。
library;

import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/room/area_alert.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';
import 'package:kakureru/features/wifi/repository/proximity_calculator.dart';

/// 鬼の放出から1件目のミッションを出すまでの時間。
const firstMissionDelay = Duration(seconds: 30);

/// ミッションが終わって(期限切れ・誰かが取った)から次を出すまでの間隔。
const missionInterval = Duration(seconds: 60);

/// アクセスポイントの判定の半径(m)。
const accessPointRadiusM = 15.0;

/// GPSの精度(m)がこれより悪いときは到着を判定しない。
const maxUsableAccuracyM = 30.0;

/// 範囲内がこの回数続いたら到着とする(GPSのブレを抑えるため)。
const requiredConsecutiveInRange = 2;

/// 新しい地点を、前回の地点からこれ以上離す(m)。
const minMissionPointSeparationM = 50.0;

/// 地点の候補を引き直す回数の上限。
const _maxPointAttempts = 200;

/// 2点間の距離(m)。企画どおり `Geolocator.distanceBetween` を使う
/// (中身は純粋なDartの計算なので、テストからそのまま呼べる)。
double distanceMeters(double lat1, double lng1, double lat2, double lng2) =>
    Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

/// 今のゲームのミッションだけを、出した順(古い順)に返す。
///
/// 「同じメンバーでもう一回」(`restartRoom`)は `missions` を消さないため、
/// 前のゲームのものが残っている(`catchesOfCurrentGame` と同じ理由)。
/// [startedAt]がnull(開始前)なら空。
List<Mission> missionsOfCurrentGame(
  List<Mission> missions, {
  required int? startedAt,
}) {
  if (startedAt == null) return const [];
  return missions.where((m) => m.createdAt >= startedAt).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

/// 期限が切れたか。`expiresAt` ちょうどからは切れている。
bool isMissionExpired(Mission mission, {required int nowMillis}) =>
    nowMillis >= mission.expiresAt;

/// ミッションがまだ受けられるか。アクセスポイントは誰かが取ったら終わり、
/// 「鬼に近づけ」は全員が挑めるので期限まで続く。
bool isMissionActive(Mission mission, {required int nowMillis}) {
  if (isMissionExpired(mission, nowMillis: nowMillis)) return false;
  return switch (mission.type) {
    MissionType.accessPoint => mission.claimedBy == null,
    MissionType.approachDemon => true,
  };
}

/// ミッションが終わった時刻。取られていれば取られた時刻、そうでなければ期限。
int missionEndedAt(Mission mission) {
  final claimedAt = mission.claimedAt;
  if (mission.claimedBy != null && claimedAt != null) {
    return math.min(claimedAt, mission.expiresAt);
  }
  return mission.expiresAt;
}

/// 取られたアクセスポイントのカード(「ほかの人に取られた」「特典を引いた」)
/// を出しておく時間。期限(最長180秒)まで出し続けると、次のミッションが
/// 出るまで終わったカードが地図を塞ぐため。
const claimedCardDuration = Duration(seconds: 15);

/// いま画面に出すミッション(今のゲームの最新1件)。期限が切れていれば、
/// または取られてから[claimedCardDuration]たっていればnull。
///
/// 取られた直後のアクセスポイントは返す(「ほかの人に取られた」を
/// 同じ場所に出すため)。
Mission? currentMission(
  List<Mission> missions, {
  required int? startedAt,
  required int nowMillis,
}) {
  final current = missionsOfCurrentGame(missions, startedAt: startedAt);
  if (current.isEmpty) return null;
  final latest = current.last;
  if (isMissionExpired(latest, nowMillis: nowMillis)) return null;
  final claimedAt = latest.claimedAt;
  if (latest.claimedBy != null &&
      claimedAt != null &&
      nowMillis >= claimedAt + claimedCardDuration.inMilliseconds) {
    return null;
  }
  return latest;
}

/// ホストの端末が、いま新しいミッションを書くべきか。
///
/// - 鬼の放出([releasedAt])から[firstMissionDelay]たったら1件目
/// - 直前のミッションが終わって(期限切れ・誰かが取った)から
///   [missionInterval]あけて次
/// - 同時に出すのは1件だけ(受けられるものが残っていれば書かない)
/// - ゲームが終わっていたら書かない
bool shouldCreateMission({
  required List<Mission> missions,
  required int? startedAt,
  required int? releasedAt,
  required int? endsAt,
  required int nowMillis,
}) {
  if (releasedAt == null) return false;
  if (endsAt != null && nowMillis >= endsAt) return false;
  final current = missionsOfCurrentGame(missions, startedAt: startedAt);
  if (current.isEmpty) {
    return nowMillis >= releasedAt + firstMissionDelay.inMilliseconds;
  }
  if (current.any((m) => isMissionActive(m, nowMillis: nowMillis))) {
    return false;
  }
  final lastEnded = current.map(missionEndedAt).reduce(math.max);
  return nowMillis >= lastEnded + missionInterval.inMilliseconds;
}

/// 次に出すミッションの種類。エリアが無い(地点を置けない)ときは
/// 「鬼に近づけ」だけにする。
MissionType chooseMissionType({
  required List<LatLng> area,
  required math.Random random,
}) {
  if (area.length < 3) return MissionType.approachDemon;
  return random.nextBool()
      ? MissionType.accessPoint
      : MissionType.approachDemon;
}

/// エリア[area]の中から、前回の地点[previous]から
/// [minMissionPointSeparationM]以上離れた点をランダムに選ぶ。
///
/// エリアの外接矩形から候補を引き、内側([isInsideArea])のものだけを使う。
/// 引き直しの上限までに条件を満たす点が無ければ、内側の候補のうち前回から
/// 一番遠いものにする(エリアが狭すぎて50m離せない場合でも出せるように)。
/// エリアが3点未満、または内側の点が1つも引けなければnull。
LatLng? pickMissionPoint({
  required List<LatLng> area,
  required LatLng? previous,
  required math.Random random,
}) {
  if (area.length < 3) return null;
  final minLat = area.map((p) => p.lat).reduce(math.min);
  final maxLat = area.map((p) => p.lat).reduce(math.max);
  final minLng = area.map((p) => p.lng).reduce(math.min);
  final maxLng = area.map((p) => p.lng).reduce(math.max);

  LatLng? farthest;
  var farthestDistance = -1.0;
  for (var i = 0; i < _maxPointAttempts; i++) {
    final candidate = LatLng(
      lat: minLat + (maxLat - minLat) * random.nextDouble(),
      lng: minLng + (maxLng - minLng) * random.nextDouble(),
    );
    if (!isInsideArea(area: area, point: candidate)) continue;
    if (previous == null) return candidate;
    final distance = distanceMeters(
      previous.lat,
      previous.lng,
      candidate.lat,
      candidate.lng,
    );
    if (distance >= minMissionPointSeparationM) return candidate;
    if (distance > farthestDistance) {
      farthest = candidate;
      farthestDistance = distance;
    }
  }
  return farthest;
}

/// 今のゲームで最後に出したアクセスポイントの地点。無ければnull。
LatLng? lastMissionPoint(List<Mission> missionsOfGame) {
  for (final mission in missionsOfGame.reversed) {
    final lat = mission.lat;
    final lng = mission.lng;
    if (lat != null && lng != null) return LatLng(lat: lat, lng: lng);
  }
  return null;
}

/// GPSの読み取り1回ぶんの分類。
enum AccessPointFix {
  /// 自分の位置がまだ届いていない。
  noFix,

  /// 精度が[maxUsableAccuracyM]より悪い(または不明)ので判定しない。
  weakGps,

  /// 判定範囲の外。
  outside,

  /// 判定範囲の中。
  inside,
}

/// アクセスポイントとの位置関係。カードの「のこり N m」「GPS ±N m」に使う。
typedef AccessPointReading = ({
  AccessPointFix fix,

  /// 地点までの距離(m)。位置が無ければnull。
  double? distanceM,

  /// GPSの精度(m)。不明ならnull。
  double? accuracyM,

  /// 読み取りの時刻(`locations/{uid}/updatedAt`)。同じ値を二重に数えない
  /// ために使う。
  int? sampleAt,
});

/// 自分の位置[location]とミッション[mission]から、1回ぶんの読み取りを作る。
///
/// 精度が不明なときも判定しない(悪いかどうか分からないため)。距離は
/// 判定しないときも出す(近いのに反応しない理由が分かるように)。
AccessPointReading readAccessPoint({
  required Mission mission,
  required UserLocation? location,
}) {
  final lat = mission.lat;
  final lng = mission.lng;
  if (location == null || lat == null || lng == null) {
    return (
      fix: AccessPointFix.noFix,
      distanceM: null,
      accuracyM: null,
      sampleAt: null,
    );
  }
  final distance = distanceMeters(
    location.latitude,
    location.longitude,
    lat,
    lng,
  );
  final accuracy = location.accuracy;
  final radius = mission.radiusM ?? accessPointRadiusM;
  final AccessPointFix fix;
  if (accuracy == null || accuracy > maxUsableAccuracyM) {
    fix = AccessPointFix.weakGps;
  } else if (distance <= radius) {
    fix = AccessPointFix.inside;
  } else {
    fix = AccessPointFix.outside;
  }
  return (
    fix: fix,
    distanceM: distance,
    accuracyM: accuracy,
    sampleAt: location.updatedAt,
  );
}

/// 到着判定の持ち越し状態。
typedef ArrivalProgress = ({
  /// 範囲内が続いた回数。
  int streak,

  /// 最後に数えた読み取りの時刻。同じ読み取りを二重に数えない。
  int? lastSampleAt,

  /// 一度でも到着したか(範囲内が[requiredConsecutiveInRange]回続いたか)。
  /// そのミッションの間は保つが、これだけでは引けない。引けるかどうかは
  /// いまの読み取りと合わせて[canClaimAccessPoint]で決める。
  bool arrived,
});

/// まだ何も読んでいない状態。
const ArrivalProgress initialArrival = (
  streak: 0,
  lastSampleAt: null,
  arrived: false,
);

/// 読み取り[reading]を1回ぶん反映する。
///
/// - 範囲内が[requiredConsecutiveInRange]回続いたら到着
/// - 範囲外・精度が悪い読み取りで連続は途切れる
/// - 同じ時刻の読み取り(位置が更新されていない)は数えない
/// - 一度到着したら、以後の読み取りでは変えない(戻ってきたときに、
///   また2回待たせないため)
ArrivalProgress advanceArrival(
  ArrivalProgress previous,
  AccessPointReading reading,
) {
  if (previous.arrived) return previous;
  final sampleAt = reading.sampleAt;
  if (reading.fix == AccessPointFix.noFix || sampleAt == null) {
    return previous;
  }
  if (sampleAt == previous.lastSampleAt) return previous;
  if (reading.fix != AccessPointFix.inside) {
    return (streak: 0, lastSampleAt: sampleAt, arrived: false);
  }
  final streak = previous.streak + 1;
  return (
    streak: streak,
    lastSampleAt: sampleAt,
    arrived: streak >= requiredConsecutiveInRange,
  );
}

/// いま「特典を引く」を押せるか。
///
/// 一度到着していて([ArrivalProgress.arrived])、**いまの読み取りでも範囲の
/// 外に出ていない**ときだけ引ける。一度通っただけで、離れた場所から期限まで
/// 引けてしまうのを防ぐ(「先に着いた人が取る」ため)。
///
/// 到着した後にGPSの精度が悪くなっただけ([AccessPointFix.weakGps])なら
/// 引ける。精度が悪いときは距離も当てにならず、その場に立っている人の
/// ボタンがブレで消えてしまうため。位置が届いていないとき(noFix)は
/// 確かめられないので引けない。
bool canClaimAccessPoint({
  required ArrivalProgress arrival,
  required AccessPointReading reading,
}) {
  if (!arrival.arrived) return false;
  return switch (reading.fix) {
    AccessPointFix.inside || AccessPointFix.weakGps => true,
    AccessPointFix.outside || AccessPointFix.noFix => false,
  };
}

/// 先着1名のトランザクションの中身(`missions/{missionId}` に対して回す)。
///
/// - 手元にキャッシュが無いと、最初はサーバーの値に関係なく[current]が
///   nullで呼ばれる。ここでabortするとサーバーの値で再実行されずに終わる
///   ため、nullのまま成功を返す(サーバーにミッションがあれば実際の値で
///   呼び直され、本当に無ければnullのまま確定する。`attachCatchPhoto`と同じ)
/// - もう誰かが取っている、または期限が切れていればabort
/// - それ以外は自分のuidと取った時刻を入れる
///
/// [nowMillis]はサーバー時刻。`claimedAt`に`ServerValue.timestamp`を
/// 使わないのは、トランザクションの中で使うと手元の仮の値と確定値が
/// 食い違い、再実行の判定が不安定になるため。
Transaction claimMissionUpdate(
  Object? current, {
  required String uid,
  required int nowMillis,
}) {
  if (current == null) return Transaction.success(null);
  if (current is! Map) return Transaction.abort();
  if (current['claimedBy'] != null) return Transaction.abort();
  final expiresAt = current['expiresAt'];
  if (expiresAt is num && nowMillis >= expiresAt) return Transaction.abort();
  return Transaction.success({
    ...current,
    'claimedBy': uid,
    'claimedAt': nowMillis,
  });
}

/// 「鬼に近づけ」の持ち越し状態。
typedef ApproachProgress = ({
  /// ミッション中に一度でも「反応なし」(どの鬼とも近いと出ていない)を見たか。
  bool sawNoReaction,

  /// 「反応なし」から「反応あり」に変わったか。
  bool achieved,
});

/// まだ何も見ていない状態。
const ApproachProgress initialApproach = (
  sawNoReaction: false,
  achieved: false,
);

/// Wi-Fiの判定1回ぶんを反映する。
///
/// 達成条件は**判定が「反応なし」から「反応あり」に変わること**。
/// ミッションが出た時点で既に「反応あり」だった人は、一度「反応なし」を
/// 経ないと達成しない(近くにいただけで達成にならないように)。
/// [anyDemonClose]は既存の判定(`wifiProximityLevelsProvider`)で、
/// どれかの鬼が `ProximityLevel.close` かどうか。
ApproachProgress advanceApproach(
  ApproachProgress previous, {
  required bool anyDemonClose,
}) {
  if (previous.achieved) return previous;
  if (!anyDemonClose) return (sawNoReaction: true, achieved: false);
  return (
    sawNoReaction: previous.sawNoReaction,
    achieved: previous.sawNoReaction,
  );
}

/// 「鬼に近づけ」のカードに出す、いまの数値。
typedef WifiOverlapMetrics = ({
  /// 自分と相手の両方に見えている物理AP(弱い電波を除いた後)の数。
  int commonCount,

  /// 自分に見えている物理APの数。
  int selfCount,

  /// 共通APのRSSI差の中央値(dB)。共通APが無ければnull。
  double? medianDiffDbm,
});

/// 判定と同じ前処理([prepareForProximity])をしたうえで、カードに出す数値を
/// 求める。判定そのものは既存の[calculateProximity]に任せ、ここでは変えない。
WifiOverlapMetrics wifiOverlapMetrics(
  Map<String, int> selfBssidRssi,
  Map<String, int> targetBssidRssi,
) {
  final self = prepareForProximity(selfBssidRssi);
  final target = prepareForProximity(targetBssidRssi);
  return (
    commonCount: self.keys.where(target.containsKey).length,
    selfCount: self.length,
    medianDiffDbm: calculateMedianRssiDiff(self, target),
  );
}

/// [candidateUids]の順に見て、Wi-Fiの判定が「反応あり」(close)の最初の
/// 相手。いなければnull。「鬼に近づけ」で、達成の判定に使われた鬼を
/// 画面に出すために使う。
String? firstCloseUid(
  List<WifiProximityEntry> entries,
  Iterable<String> candidateUids,
) {
  final close = {
    for (final entry in entries)
      if (entry.level == ProximityLevel.close) entry.uid,
  };
  for (final uid in candidateUids) {
    if (close.contains(uid)) return uid;
  }
  return null;
}
