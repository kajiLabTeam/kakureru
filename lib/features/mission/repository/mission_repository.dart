import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/mission/mission_rules.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/model/room_effect.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/repository/event_log_repository.dart';

/// 先着1名の取り合いの結果。
enum ClaimOutcome {
  /// 自分が取れた(特典を引いて効果を足した)。
  claimed,

  /// ほかの人に先に取られていた。
  takenByOther,

  /// 期限が切れていた、またはミッションが無かった。
  unavailable,
}

/// 取り合いの結果と、取れたときに引いた特典。
typedef ClaimResult = ({ClaimOutcome outcome, RewardType? reward});

/// サーバー時刻が取れず、取り合いを始められなかったことを表す。
class MissionClaimUnavailableException implements Exception {
  const MissionClaimUnavailableException();

  @override
  String toString() => '通信できないため特典を引けませんでした';
}

/// ミッション(`missions`)と特典の効果(`effects`)のRTDB操作。
class MissionRepository {
  /// 引数を省略すると実際のFirebaseを使う。テストからのみ差し替える。
  /// [random]は特典の抽選とミッションの種類・地点の選択に使う。
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

  /// ホストの端末が、次のミッションを1件書く。
  ///
  /// 種類はランダム(エリアが無ければ「鬼に近づけ」)。アクセスポイントの
  /// 地点はエリアの中から前回の地点と50m以上離して選ぶ。`expiresAt` は
  /// サーバー時刻の補正値[nowMillis] + 制限時間。
  Future<void> createMission(
    String roomId, {
    required List<LatLng> area,
    required LatLng? previousPoint,
    required int nowMillis,
  }) async {
    var type = chooseMissionType(area: area, random: _random);
    LatLng? point;
    if (type == MissionType.accessPoint) {
      point = pickMissionPoint(
        area: area,
        previous: previousPoint,
        random: _random,
      );
      if (point == null) type = MissionType.approachDemon;
    }
    final ref = _db.ref('rooms/$roomId/missions').push();
    await ref.set({
      'type': type.raw,
      'createdAt': ServerValue.timestamp,
      'expiresAt': nowMillis + type.timeLimit.inMilliseconds,
      if (point != null) ...{
        'lat': point.lat,
        'lng': point.lng,
        'radiusM': accessPointRadiusM,
      },
    });
  }

  /// アクセスポイントを先着で取る。
  ///
  /// **先着1名はここで決める**: `missions/{missionId}` への
  /// [DatabaseReference.runTransaction]で、`claimedBy` がnullのときだけ
  /// 自分のuidを入れる([claimMissionUpdate])。RTDBはトランザクションを
  /// サーバー側で直列にするので、2台が同時に押しても確定するのは1台だけで、
  /// 遅れた方はサーバーの値(`claimedBy` 入り)で呼び直されてabortする。
  ///
  /// 取れたときだけ特典を渡す([_grantReward])。[footPhotoSkipSlot]は、
  /// 特典が「足元写真を1回まぬがれる」だったときに飛ばすスロット
  /// (`footPhotoSlotToSkip`。押した瞬間の撮影バナーの状態で決める)。
  Future<ClaimResult> claimMission(
    String roomId,
    String missionId, {
    int? footPhotoSkipSlot,
  }) async {
    final now = await _serverNowMillis();
    if (now == null) throw const MissionClaimUnavailableException();
    final uid = _uid;
    final missionRef = _db.ref('rooms/$roomId/missions/$missionId');
    final result = await missionRef.runTransaction(
      (current) => claimMissionUpdate(current, uid: uid, nowMillis: now),
      applyLocally: false,
    );
    final value = result.snapshot.value;
    if (!result.committed || value is! Map) {
      final claimedBy = value is Map ? value['claimedBy'] : null;
      final outcome = claimedBy != null && claimedBy != uid
          ? ClaimOutcome.takenByOther
          : ClaimOutcome.unavailable;
      return (outcome: outcome, reward: null);
    }
    if (value['claimedBy'] != uid) {
      return (outcome: ClaimOutcome.takenByOther, reward: null);
    }

    final reward = await _grantReward(
      roomId,
      missionId,
      uid: uid,
      nowMillis: now,
      footPhotoSkipSlot: footPhotoSkipSlot,
    );
    unawaited(
      _eventLog.log(roomId, type: GameEventType.missionClaimed, uid: uid),
    );
    return (outcome: ClaimOutcome.claimed, reward: reward);
  }

  /// 取れたのに特典の書き込みが済んでいないミッションの、特典を受け取り直す。
  ///
  /// [claimMission]のトランザクションが確定した後、特典を書く前に通信が
  /// 切れたりアプリが落ちたりすると、「取ったのに効果が出ない」まま残る。
  /// カードの「特典を受け取る」からここを呼んでやり直す。自分が取った
  /// ミッションでなければ[MissionClaimUnavailableException]を投げる。
  Future<RewardType> completeClaim(
    String roomId,
    String missionId, {
    int? footPhotoSkipSlot,
  }) async {
    final now = await _serverNowMillis();
    if (now == null) throw const MissionClaimUnavailableException();
    final uid = _uid;
    final claimedBy = await _db
        .ref('rooms/$roomId/missions/$missionId/claimedBy')
        .get();
    if (claimedBy.value != uid) throw const MissionClaimUnavailableException();
    return _grantReward(
      roomId,
      missionId,
      uid: uid,
      nowMillis: now,
      footPhotoSkipSlot: footPhotoSkipSlot,
    );
  }

  /// 特典を抽選し、`missions/{missionId}/reward` と `effects/{missionId}` を
  /// 書く。**何度呼んでも結果は1つ**になるようにしてある:
  ///
  /// - `reward` は「まだ無いときだけ書く」トランザクション。既にあれば
  ///   それを返す(やり直しで別の特典に引き直させない)
  /// - 効果のキーをミッションIDにし、「まだ無いときだけ書く」トランザクション
  ///   で書く(やり直しで効果が2件になったり、残り時間が延びたりしない)
  ///
  /// `rooms/{roomId}` への一括書き込みはルール上できないので、2か所を
  /// 別々に書く。途中で止まっても、もう一度呼べば残りが書かれる。
  Future<RewardType> _grantReward(
    String roomId,
    String missionId, {
    required String uid,
    required int nowMillis,
    required int? footPhotoSkipSlot,
  }) async {
    final drawn = drawReward(_random);
    final rewardResult = await _db
        .ref('rooms/$roomId/missions/$missionId/reward')
        .runTransaction(
          (current) => current == null
              ? Transaction.success(drawn.raw)
              : Transaction.abort(),
          applyLocally: false,
        );
    final reward =
        RewardType.fromRaw(rewardResult.snapshot.value as String?) ?? drawn;

    await _db
        .ref('rooms/$roomId/effects/$missionId')
        .runTransaction(
          (current) => current != null
              ? Transaction.abort()
              : Transaction.success({
                  'type': reward.raw,
                  'byUid': uid,
                  // トランザクションの中ではServerValueを使わず、補正済みの
                  // サーバー時刻を入れる(claimMissionUpdateのclaimedAtと同じ)。
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

/// 特典を1つ引く。3種類から等確率。ハズレは無い。
RewardType drawReward(math.Random random) =>
    RewardType.values[random.nextInt(RewardType.values.length)];
