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
  /// 取れたときだけ特典を抽選し、`missions/{missionId}/reward` と
  /// `effects/{effectId}` を書く(`rooms/{roomId}` への一括書き込みは
  /// ルール上できないので2回に分ける)。
  Future<ClaimResult> claimMission(String roomId, String missionId) async {
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

    final reward = drawReward(_random);
    await missionRef.child('reward').set(reward.raw);
    await _db.ref('rooms/$roomId/effects').push().set({
      'type': reward.raw,
      'byUid': uid,
      'startedAt': ServerValue.timestamp,
      'durationMs': reward.duration.inMilliseconds,
    });
    unawaited(
      _eventLog.log(roomId, type: GameEventType.missionClaimed, uid: uid),
    );
    return (outcome: ClaimOutcome.claimed, reward: reward);
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
