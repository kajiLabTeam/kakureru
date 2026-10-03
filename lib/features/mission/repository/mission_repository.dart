import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/mission/mission_rules.dart';
import 'package:kakureru/features/mission/mission_timing.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/model/room_effect.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/repository/event_log_repository.dart';

/// 地点の取り合いの結果。
enum ClaimOutcome {
  /// 自分が取れた(ごほうびを引いて効果を足した)。
  claimed,

  /// ほかの人に先に取られていた。
  takenByOther,

  /// 期限が切れていた、終わっていた、自分がもう別の地点を取っていた、
  /// またはミッションが無かった。
  unavailable,
}

/// 取り合いの結果と、取れたときに引いたごほうび。
typedef ClaimResult = ({ClaimOutcome outcome, RewardType? reward});

/// サーバー時刻が取れず、取り合いを始められなかったことを表す。
class MissionClaimUnavailableException implements Exception {
  const MissionClaimUnavailableException();

  @override
  String toString() => '通信できないためごほうびを引けませんでした';
}

/// ミッション(`missions`)とごほうびの効果(`effects`)のRTDB操作。
class MissionRepository {
  /// 引数を省略すると実際のFirebaseを使う。テストからのみ差し替える。
  /// [random]はごほうびの抽選と地点の選択に使う。
  MissionRepository({
    FirebaseDatabase? db,
    FirebaseAuth? auth,
    math.Random? random,
    Future<int?> Function()? serverNow,
  }) : _dbOverride = db,
       _authOverride = auth,
       _random = random ?? math.Random(),
       _serverNowOverride = serverNow;

  final FirebaseDatabase? _dbOverride;
  final FirebaseAuth? _authOverride;
  final math.Random _random;
  final Future<int?> Function()? _serverNowOverride;

  // RoomRepositoryと同じ理由(Firebase未初期化のテストで`.instance`を踏まない)
  // でlateの遅延初期化にしている。
  late final FirebaseDatabase _db = _dbOverride ?? FirebaseDatabase.instance;
  late final FirebaseAuth _auth = _authOverride ?? FirebaseAuth.instance;
  late final EventLogRepository _eventLog = EventLogRepository(db: _dbOverride);

  String get _uid => _auth.currentUser!.uid;

  /// サーバー時刻(エポックミリ秒)。取れなければnull
  /// (端末時計へ黙ってフォールバックしない。`fetchServerTimeOffset`参照)。
  Future<int?> _serverNowMillis() async {
    final override = _serverNowOverride;
    if (override != null) return override();
    final offset = await fetchServerTimeOffset(_db);
    return offset == null ? null : serverNowMillis(offset);
  }

  /// ミッション一覧を監視する。前のゲームの分も含むので、使うときは
  /// [missionsOfCurrentGame]で絞ること。
  Stream<List<Mission>> watchMissions(String roomId) =>
      _watchList('rooms/$roomId/missions', Mission.fromMap);

  /// 効果の一覧を監視する。
  Stream<List<RoomEffect>> watchEffects(String roomId) =>
      _watchList('rooms/$roomId/effects', RoomEffect.fromMap);

  /// ホストの端末が、[round]回目のミッションを1件書く。
  ///
  /// 地点はエリアの中から[spotCount]個(`missionSpotCount`)、互いに50m以上離して
  /// ランダムに選ぶ([pickAccessPoints])。エリアが狭すぎて1つも選べなければ
  /// 書かない。`expiresAt` はサーバー時刻の補正値[nowMillis] + 制限時間
  /// ([missionTimeLimit])。
  Future<void> createMission(
    String roomId, {
    required List<LatLng> area,
    required int spotCount,
    required int round,
    required int nowMillis,
  }) async {
    final points = pickAccessPoints(
      area: area,
      count: spotCount,
      random: _random,
    );
    if (points.isEmpty) return;
    final ref = _db.ref('rooms/$roomId/missions').push();
    await ref.set({
      'round': round,
      'createdAt': ServerValue.timestamp,
      'expiresAt': nowMillis + missionTimeLimit.inMilliseconds,
      'spots': {
        for (final (i, point) in points.indexed)
          '$missionSpotIdPrefix$i': {
            'lat': point.lat,
            'lng': point.lng,
            'radiusM': accessPointRadiusM,
          },
      },
    });
  }

  /// アクセスポイントの地点[spotId]を先着で取る。
  ///
  /// **先着はここで決める**: `missions/{missionId}` への
  /// [DatabaseReference.runTransaction]で、`spots/{spotId}/claimedBy` が
  /// nullのときだけ自分のuidを入れる([claimSpotUpdate])。RTDBはトランザク
  /// ションをサーバー側で直列にするので、2台が同じ地点を同時に取りに来ても
  /// 確定するのは1台だけで、遅れた方はサーバーの値(`claimedBy` 入り)で
  /// 呼び直されてabortする。すべての地点が埋まったら同じトランザクションで
  /// `finishedAt` を入れる(その場で終わる)。
  ///
  /// 取れたときだけごほうびを渡す([_grantReward])。[footPhotoSkipSlot]は、
  /// ごほうびが「足元写真を1回まぬがれる」だったときに飛ばすスロット
  /// (`footPhotoSlotToSkip`。押した瞬間の撮影バナーの状態で決める)。
  Future<ClaimResult> claimMission(
    String roomId,
    String missionId,
    String spotId, {
    int? footPhotoSkipSlot,
  }) async {
    final now = await _serverNowMillis();
    if (now == null) throw const MissionClaimUnavailableException();
    final uid = _uid;
    final missionRef = _db.ref('rooms/$roomId/missions/$missionId');
    final result = await missionRef.runTransaction(
      (current) =>
          claimSpotUpdate(current, spotId: spotId, uid: uid, nowMillis: now),
      applyLocally: false,
    );
    final claimedBy = _spotClaimedBy(result.snapshot.value, spotId);
    if (!result.committed || claimedBy != uid) {
      final outcome = claimedBy != null && claimedBy != uid
          ? ClaimOutcome.takenByOther
          : ClaimOutcome.unavailable;
      return (outcome: outcome, reward: null);
    }

    final reward = await _grantReward(
      roomId,
      missionId,
      spotId,
      uid: uid,
      nowMillis: now,
      footPhotoSkipSlot: footPhotoSkipSlot,
    );
    unawaited(
      _eventLog.log(roomId, type: GameEventType.missionClaimed, uid: uid),
    );
    return (outcome: ClaimOutcome.claimed, reward: reward);
  }

  /// 取れたのにごほうびの書き込みが済んでいない地点の、ごほうびを
  /// 受け取り直す。
  ///
  /// [claimMission]のトランザクションが確定した後、ごほうびを書く前に通信が
  /// 切れたりアプリが落ちたりすると、「取ったのに効果が出ない」まま残る。
  /// カードの「ごほうびを受け取る」からここを呼んでやり直す。自分が取った
  /// 地点でなければ[MissionClaimUnavailableException]を投げる。
  Future<RewardType> completeClaim(
    String roomId,
    String missionId,
    String spotId, {
    int? footPhotoSkipSlot,
  }) async {
    final now = await _serverNowMillis();
    if (now == null) throw const MissionClaimUnavailableException();
    final uid = _uid;
    final claimedBy = await _db
        .ref('rooms/$roomId/missions/$missionId/spots/$spotId/claimedBy')
        .get();
    if (claimedBy.value != uid) throw const MissionClaimUnavailableException();
    return _grantReward(
      roomId,
      missionId,
      spotId,
      uid: uid,
      nowMillis: now,
      footPhotoSkipSlot: footPhotoSkipSlot,
    );
  }

  /// ごほうびを抽選し、`missions/{missionId}/spots/{spotId}/reward` と
  /// `effects/{missionId}_{spotId}` を書く。**何度呼んでも結果は1つ**に
  /// なるようにしてある:
  ///
  /// - `reward` は「まだ無いときだけ書く」トランザクション。既にあれば
  ///   それを返す(やり直しで別のごほうびに引き直させない)
  /// - 効果のキーを地点ごとに決め、「まだ無いときだけ書く」トランザクション
  ///   で書く(やり直しで効果が2件になったり、残り時間が延びたりしない)
  ///
  /// `rooms/{roomId}` への一括書き込みはルール上できないので、2か所を
  /// 別々に書く。途中で止まっても、もう一度呼べば残りが書かれる。
  Future<RewardType> _grantReward(
    String roomId,
    String missionId,
    String spotId, {
    required String uid,
    required int nowMillis,
    required int? footPhotoSkipSlot,
  }) async {
    final drawn = drawReward(_random);
    final rewardResult = await _db
        .ref('rooms/$roomId/missions/$missionId/spots/$spotId/reward')
        .runTransaction(
          (current) => current == null
              ? Transaction.success(drawn.raw)
              : Transaction.abort(),
          applyLocally: false,
        );
    final reward =
        RewardType.fromRaw(rewardResult.snapshot.value as String?) ?? drawn;

    await _db
        .ref('rooms/$roomId/effects/${missionEffectId(missionId, spotId)}')
        .runTransaction(
          (current) => current != null
              ? Transaction.abort()
              : Transaction.success({
                  'type': reward.raw,
                  'byUid': uid,
                  // トランザクションの中ではServerValueを使わず、補正済みの
                  // サーバー時刻を入れる(claimSpotUpdateのclaimedAtと同じ)。
                  'startedAt': nowMillis,
                  'durationMs': reward.duration.inMilliseconds,
                  if (reward == RewardType.skipFootPhoto &&
                      footPhotoSkipSlot != null)
                    'skipSlot': footPhotoSkipSlot,
                }),
          applyLocally: false,
        );
    return reward;
  }

  /// トランザクションの結果から、地点[spotId]を取った人のuidを読む。
  static Object? _spotClaimedBy(Object? mission, String spotId) {
    if (mission is! Map) return null;
    final spots = mission['spots'];
    if (spots is! Map) return null;
    final spot = spots[spotId];
    return spot is Map ? spot['claimedBy'] : null;
  }

  /// `path`直下の子を[parse]で読み、一覧として流す
  /// (`RoomRepository._watchList`と同じ形。読めない子は飛ばす)。
  Stream<List<T>> _watchList<T>(
    String path,
    T Function(String id, Map<dynamic, dynamic> raw) parse,
  ) {
    final controller = StreamController<List<T>>.broadcast();
    final sub = _db.ref(path).onValue.listen((event) {
      final value = event.snapshot.value as Map<dynamic, dynamic>?;
      final items = <T>[];
      for (final entry in (value ?? const {}).entries) {
        try {
          items.add(
            parse(entry.key.toString(), entry.value as Map<dynamic, dynamic>),
          );
        } on Object catch (e) {
          debugPrint('[MissionRepository] $path/${entry.key}を読めません: $e');
        }
      }
      controller.add(items);
    }, onError: controller.addError);
    controller.onCancel = sub.cancel;
    return controller.stream;
  }
}

/// ごほうびを1つ引く。各[RewardType.oddsPercent]に従った重み付き抽選
/// (当たり3種で合計[rewardWinningOddsPercent]%を均等に、ハズレが
/// [rewardMissOddsPercent]%)。
RewardType drawReward(math.Random random) {
  final roll = random.nextDouble() * 100;
  var cumulative = 0.0;
  for (final type in RewardType.values) {
    cumulative += type.oddsPercent;
    if (roll < cumulative) return type;
  }
  return RewardType.values.last;
}

/// 地点idの頭(`s0`, `s1`, …)。
const missionSpotIdPrefix = 's';

/// 地点を取った人のごほうびの効果のキー。1地点に1件だけになる。
String missionEffectId(String missionId, String spotId) =>
    '${missionId}_$spotId';
