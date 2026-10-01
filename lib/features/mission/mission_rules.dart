/// ミッションの生成・期限・GPSの到着判定・先着の取り合いの純粋な計算。
/// RTDBやプラグインに依存しないため、実機なしで単体テストできる。
///
/// 時間の数値はここに書かず、`mission_timing.dart`に置く。
library;

import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/mission/mission_timing.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/room/area_alert.dart';
import 'package:kakureru/features/room/model/room_setting.dart';

/// アクセスポイントの判定の半径(m)。
const accessPointRadiusM = 15.0;

/// GPSの精度(m)がこれより悪いときは到着を判定しない。
const maxUsableAccuracyM = 30.0;

/// 範囲内がこの回数続いたら到着とする(GPSのブレを抑えるため)。
const requiredConsecutiveInRange = 2;

/// 同じミッションの地点どうしを、これ以上離す(m)。
const minSpotSeparationM = 50.0;

/// 地点の候補を引く回数。
const _maxPointAttempts = 400;

/// 2点間の距離(m)。企画どおり `Geolocator.distanceBetween` を使う
/// (中身は純粋なDartの計算なので、テストからそのまま呼べる)。
double distanceMeters(double lat1, double lng1, double lat2, double lng2) =>
    Geolocator.distanceBetween(lat1, lng1, lat2, lng2);

/// 地点の数。鬼の人数 + 1(逃走者どうしで取り合いになるよう、全員分は出さない)。
int missionSpotCount({required int demonCount}) => demonCount + 1;

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

/// 地点がすべて取られたか。地点が無いミッションは「取られた」扱いにしない。
bool areAllSpotsClaimed(Mission mission) =>
    mission.spots.isNotEmpty && mission.spots.every((s) => s.claimedBy != null);

/// 地点がすべて取られて、期限より前に終わったか。
bool isMissionFinishedEarly(Mission mission) =>
    mission.finishedAt != null || areAllSpotsClaimed(mission);

/// ミッションがまだ受けられるか(期限内で、空いている地点がある)。
bool isMissionActive(Mission mission, {required int nowMillis}) =>
    !isMissionExpired(mission, nowMillis: nowMillis) &&
    !isMissionFinishedEarly(mission);

/// ミッションが終わった時刻。すべて取られていればその時刻、そうでなければ期限。
int missionEndedAt(Mission mission) {
  final finishedAt =
      mission.finishedAt ??
      (areAllSpotsClaimed(mission)
          ? mission.spots
                .map((s) => s.claimedAt ?? mission.expiresAt)
                .reduce(math.max)
          : null);
  return finishedAt == null
      ? mission.expiresAt
      : math.min(finishedAt, mission.expiresAt);
}

/// 空いている地点。
List<MissionSpot> openSpots(Mission mission) =>
    mission.spots.where((s) => s.claimedBy == null).toList();

/// 地図に出し続ける地点(issue #155)。
///
/// 自分が取った地点はもう向かう必要が無いため出さない。ほかの人が取った
/// 地点は「埋まった」と分かるよう出し続ける(呼び出し側で色を落として描く)。
/// ただしミッションが終わった(全地点が取られてのカード表示猶予中を含む)
/// 後は、地図に何も残らないよう空リストを返す。
List<MissionSpot> visibleMissionSpots(Mission mission, {String? myUid}) {
  if (isMissionFinishedEarly(mission)) return [];
  if (myUid == null) return mission.spots;
  return mission.spots.where((s) => s.claimedBy != myUid).toList();
}

/// [uid]が取った地点。無ければnull(1人1地点まで)。
MissionSpot? spotClaimedBy(Mission mission, String? uid) {
  if (uid == null) return null;
  return mission.spots.where((s) => s.claimedBy == uid).firstOrNull;
}

/// いま画面に出すミッション(今のゲームの最新1件)。
///
/// - 期限が切れていればnull
/// - 地点がすべて取られて早く終わったものは、終わってから
///   [finishedMissionCardDuration]だけ出す(「ほかの人に取られた」を
///   同じ場所に出すため)。その後はnull
Mission? currentMission(
  List<Mission> missions, {
  required int? startedAt,
  required int nowMillis,
}) {
  final current = missionsOfCurrentGame(missions, startedAt: startedAt);
  if (current.isEmpty) return null;
  final latest = current.last;
  if (isMissionExpired(latest, nowMillis: nowMillis)) return null;
  if (isMissionFinishedEarly(latest) &&
      nowMillis >=
          missionEndedAt(latest) + finishedMissionCardDuration.inMilliseconds) {
    return null;
  }
  return latest;
}

/// 鬼の放出から見て、いま出ているはずの回(1始まり)。まだなら0。
int dueMissionRound({required int releasedAt, required int nowMillis}) {
  var round = 0;
  for (var i = 0; i < missionDueDelays.length; i++) {
    if (nowMillis >= releasedAt + missionDueDelays[i].inMilliseconds) {
      round = i + 1;
    }
  }
  return round;
}

/// ホストの端末が、いま書くべきミッションの回。書かないならnull。
///
/// - 放出から[firstMissionDelay]で1回目、[secondMissionDelay]で2回目。
///   3回目は無い([missionDueDelays]の長さまで)
/// - 同時に出すのは1件だけ(受けられるものが残っていれば書かない)。
///   そのため1回目が遅れて書かれると、2回目もずれる。たとえば放出から
///   14:59に1回目を書くと期限は19:59なので、2回目は15分ではなく1回目が
///   切れた直後(約20分)に出る。2件を重ねて出さないことを優先している
/// - 同じ回を二度書かない。書きそびれた回は飛ばす(ホストが遅れて
///   戻ってきたときに、1回目と2回目を続けて出さない)
/// - ゲームが終わっていたら書かない(2回目の前に終われば2回目は出ない)
int? missionRoundToCreate({
  required List<Mission> missions,
  required int? startedAt,
  required int? releasedAt,
  required int? endsAt,
  required int nowMillis,
}) {
  if (releasedAt == null) return null;
  if (endsAt != null && nowMillis >= endsAt) return null;
  final due = dueMissionRound(releasedAt: releasedAt, nowMillis: nowMillis);
  if (due == 0) return null;
  final current = missionsOfCurrentGame(missions, startedAt: startedAt);
  if (current.any((m) => isMissionActive(m, nowMillis: nowMillis))) {
    return null;
  }
  final highest = current.fold(0, (max, m) => math.max(max, m.round));
  if (highest >= due) return null;
  return due;
}

/// エリア[area]の中から、[count]個の地点をランダムに選ぶ。地点どうしは
/// なるべく[minSpotSeparationM]以上離す。
///
/// エリアの外接矩形から候補を引き、内側([isInsideArea])のものだけを使う。
/// 引いた順に「選んだ地点すべてから50m以上」のものを取り、足りなければ
/// 残りの候補のうち、選んだ地点から一番遠いものを足す(エリアが狭くて
/// 50m離せないときでも出せるように)。
///
/// エリアが3点未満、または内側の点が1つも引けなければ空(ミッションは出ない)。
List<LatLng> pickAccessPoints({
  required List<LatLng> area,
  required int count,
  required math.Random random,
}) {
  if (area.length < 3 || count <= 0) return const [];
  final minLat = area.map((p) => p.lat).reduce(math.min);
  final maxLat = area.map((p) => p.lat).reduce(math.max);
  final minLng = area.map((p) => p.lng).reduce(math.min);
  final maxLng = area.map((p) => p.lng).reduce(math.max);

  final candidates = <LatLng>[];
  for (var i = 0; i < _maxPointAttempts; i++) {
    final candidate = LatLng(
      lat: minLat + (maxLat - minLat) * random.nextDouble(),
      lng: minLng + (maxLng - minLng) * random.nextDouble(),
    );
    if (isInsideArea(area: area, point: candidate)) candidates.add(candidate);
  }
  if (candidates.isEmpty) return const [];

  double nearest(LatLng p, List<LatLng> chosen) => chosen
      .map((c) => distanceMeters(c.lat, c.lng, p.lat, p.lng))
      .fold(double.infinity, math.min);

  final chosen = <LatLng>[];
  final rest = <LatLng>[];
  for (final candidate in candidates) {
    if (chosen.length < count &&
        nearest(candidate, chosen) >= minSpotSeparationM) {
      chosen.add(candidate);
    } else {
      rest.add(candidate);
    }
  }
  while (chosen.length < count && rest.isNotEmpty) {
    var bestIndex = 0;
    var bestDistance = -1.0;
    for (var i = 0; i < rest.length; i++) {
      final d = nearest(rest[i], chosen);
      if (d > bestDistance) {
        bestIndex = i;
        bestDistance = d;
      }
    }
    chosen.add(rest.removeAt(bestIndex));
  }
  return chosen;
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

/// 位置も地点も無いときの読み取り。
const AccessPointReading noAccessPointReading = (
  fix: AccessPointFix.noFix,
  distanceM: null,
  accuracyM: null,
  sampleAt: null,
);

/// 空いている地点のうち、[location]から一番近いもの。位置が無ければ
/// 最初の空いている地点。空きが無ければnull。
MissionSpot? nearestOpenSpot(Mission mission, UserLocation? location) {
  final open = openSpots(mission);
  if (open.isEmpty) return null;
  if (location == null) return open.first;
  MissionSpot? best;
  var bestDistance = double.infinity;
  for (final spot in open) {
    final d = distanceMeters(
      location.latitude,
      location.longitude,
      spot.lat,
      spot.lng,
    );
    if (d < bestDistance) {
      best = spot;
      bestDistance = d;
    }
  }
  return best;
}

/// 自分の位置[location]と地点[spot]から、1回ぶんの読み取りを作る。
///
/// 精度が不明なときも判定しない(悪いかどうか分からないため)。距離は
/// 判定しないときも出す(近いのに反応しない理由が分かるように)。
AccessPointReading readAccessPoint({
  required MissionSpot? spot,
  required UserLocation? location,
}) {
  if (location == null || spot == null) return noAccessPointReading;
  final distance = distanceMeters(
    location.latitude,
    location.longitude,
    spot.lat,
    spot.lng,
  );
  final accuracy = location.accuracy;
  final AccessPointFix fix;
  if (accuracy == null || accuracy > maxUsableAccuracyM) {
    fix = AccessPointFix.weakGps;
  } else if (distance <= spot.radiusM) {
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
  /// その地点の間は保つが、これだけでは引けない。引けるかどうかは
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

/// いま「ごほうびガチャを引く」を押せるか。
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

/// 先着のトランザクションの中身(`missions/{missionId}` に対して回す)。
///
/// - 手元にキャッシュが無いと、最初はサーバーの値に関係なく[current]が
///   nullで呼ばれる。ここでabortするとサーバーの値で再実行されずに終わる
///   ため、nullのまま成功を返す(サーバーにミッションがあれば実際の値で
///   呼び直され、本当に無ければnullのまま確定する。`attachCatchPhoto`と同じ)
/// - 期限切れ・終わっている・地点が無い・**その地点の `claimedBy` が
///   nullでない**・自分が既にほかの地点を取っている、のどれかならabort
/// - それ以外は地点に自分のuidと取った時刻を入れる。これですべての地点が
///   埋まったら `finishedAt` も入れる(その場で終わる)
///
/// [nowMillis]はサーバー時刻。`claimedAt`に`ServerValue.timestamp`を
/// 使わないのは、トランザクションの中で使うと手元の仮の値と確定値が
/// 食い違い、再実行の判定が不安定になるため。
Transaction claimSpotUpdate(
  Object? current, {
  required String spotId,
  required String uid,
  required int nowMillis,
}) {
  if (current == null) return Transaction.success(null);
  if (current is! Map) return Transaction.abort();
  final expiresAt = current['expiresAt'];
  if (expiresAt is num && nowMillis >= expiresAt) return Transaction.abort();
  if (current['finishedAt'] != null) return Transaction.abort();
  final spots = current['spots'];
  if (spots is! Map) return Transaction.abort();
  final spot = spots[spotId];
  if (spot is! Map || spot['claimedBy'] != null) return Transaction.abort();
  if (spots.values.any((s) => s is Map && s['claimedBy'] == uid)) {
    return Transaction.abort();
  }
  final nextSpots = {
    ...spots,
    spotId: {...spot, 'claimedBy': uid, 'claimedAt': nowMillis},
  };
  final allClaimed = nextSpots.values.every(
    (s) => s is Map && s['claimedBy'] != null,
  );
  return Transaction.success({
    ...current,
    'spots': nextSpots,
    if (allClaimed) 'finishedAt': nowMillis,
  });
}
