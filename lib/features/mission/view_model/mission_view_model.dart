import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/mission/mission_rules.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/mission/model/mission_progress.dart';
import 'package:kakureru/features/mission/model/room_effect.dart';
import 'package:kakureru/features/mission/repository/mission_repository.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';
import 'package:kakureru/features/wifi/view_model/wifi_view_model.dart';

/// [MissionRepository]のProvider。テストでは差し替えられる。
final Provider<MissionRepository> missionRepositoryProvider = Provider(
  (ref) => MissionRepository(),
);

/// ミッション一覧(`missions`)。前のゲームの分も含むので、使うときは
/// `missionsOfCurrentGame` / `currentMission` で絞ること。
final missionsStreamProvider = StreamProvider.family
    .autoDispose<List<Mission>, String>((ref, roomId) {
      return ref.watch(missionRepositoryProvider).watchMissions(roomId);
    });

/// 特典の効果の一覧(`effects`)。前のゲームの分も含むので、使うときは
/// `effectsOfCurrentGame` で絞ること。
final effectsStreamProvider = StreamProvider.family
    .autoDispose<List<RoomEffect>, String>((ref, roomId) {
      return ref.watch(missionRepositoryProvider).watchEffects(roomId);
    });

/// 「鬼に近づけ」のカードに出す、相手1人とのいまの数値。どちらかの
/// スキャンがまだ無ければnull。
final wifiOverlapMetricsProvider =
    Provider.family<WifiOverlapMetrics?, (String roomId, String targetUid)>((
      ref,
      args,
    ) {
      final (roomId, targetUid) = args;
      final scans = ref.watch(clueBssidRssiProvider(roomId));
      final self = scans[ref.watch(myUidProvider)];
      final target = scans[targetUid];
      if (self == null || target == null) return null;
      return wifiOverlapMetrics(self, target);
    });

/// ミッションの生成(ホストの端末だけ)と、自分の進み具合(到着・達成)の
/// 判定を、**画面が消えていても**1秒ごとに進める駆動役。
///
/// `GameAlerts`と同じ理由でウィジェットの再描画から切り離している:
/// 画面が消えるとフレームが止まり、`build`に乗せた判定は進まない。
/// ポケットに入れたまま鬼に近づく/地点に着く、が普通にあるため。
///
/// - **生成**: サーバーが無いので、ホスト(`meta/hostUserId`)の端末が
///   [shouldCreateMission]を見て `missions` に書く。ホストが落ちたら
///   ミッションは出なくなる(ゲームは続く)
/// - **進み具合**: 自分の位置と既存のWi-Fi判定を読み、[advanceArrival] /
///   [advanceApproach]で持ち越す。RTDBには書かない
///
/// 判定のロジック自体はここに書かず、`mission_rules.dart`の純粋関数を呼ぶ。
class MissionController extends Notifier<MissionProgress> {
  /// 判定の周期。
  static const _interval = Duration(seconds: 1);

  /// ミッションを書いた直後、同じ判定で二重に書かないための間隔。
  /// 書いたミッションが購読に戻ってくるまでの間を埋める。
  static const _createCooldown = Duration(seconds: 5);

  Timer? _timer;
  String? _roomId;
  int _generation = 0;
  bool _disposed = false;

  // 購読を持っておく理由は GameAlerts の `_roomSub` と同じ(StreamProviderは
  // 誰かが購読していないと読み始めず、autoDisposeなので読んだ直後に消える)。
  ProviderSubscription<AsyncValue<Room>>? _roomSub;
  ProviderSubscription<AsyncValue<int>>? _offsetSub;
  ProviderSubscription<AsyncValue<List<Mission>>>? _missionsSub;
  ProviderSubscription<List<WifiProximityEntry>>? _wifiSub;

  bool _creating = false;
  int? _lastCreatedAt;

  @override
  MissionProgress build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _disposeTimers();
    });
    return const MissionProgress();
  }

  /// ゲーム画面に入ったときに呼ぶ(`useGameSession`)。
  void start(String roomId) {
    stop();
    ++_generation;
    _roomId = roomId;
    _roomSub = ref.listen(roomStreamProvider(roomId), (_, _) {});
    _offsetSub = ref.listen(serverTimeOffsetProvider, (_, _) {});
    _missionsSub = ref.listen(missionsStreamProvider(roomId), (_, _) {});
    _wifiSub = ref.listen(wifiProximityLevelsProvider(roomId), (_, _) {});
    _timer = Timer.periodic(_interval, (_) => _evaluate());
  }

  /// ゲーム画面を離れたときに呼ぶ。進み具合も捨てる(次の部屋へ持ち越さない)。
  void stop() {
    final generation = ++_generation;
    _disposeTimers();
    _roomId = null;
    _creating = false;
    _lastCreatedAt = null;
    // useEffectの後始末(ビルド中)から呼ばれるので、stateの書き換えは外へ逃がす。
    unawaited(
      Future(() {
        if (_disposed || generation != _generation) return;
        state = const MissionProgress();
      }),
    );
  }

  void _disposeTimers() {
    _timer?.cancel();
    _timer = null;
    _roomSub?.close();
    _roomSub = null;
    _offsetSub?.close();
    _offsetSub = null;
    _missionsSub?.close();
    _missionsSub = null;
    _wifiSub?.close();
    _wifiSub = null;
  }

  @visibleForTesting
  void evaluateForTest() => _evaluate();

  void _evaluate() {
    if (_disposed) return;
    final roomId = _roomId;
    if (roomId == null) return;
    final room = _roomSub?.read().value;
    final offset = _offsetSub?.read().value;
    final missions = _missionsSub?.read().value;
    // オフセットが届くまで何も判定しない(端末時計をサーバー時刻として
    // 使うと、期限や生成の時刻がずれる。GameAlertsと同じ)。
    if (room == null || offset == null || missions == null) return;
    final nowMillis = serverNowMillis(offset);

    _createIfHost(roomId, room, missions, nowMillis);
    _updateProgress(room, missions, nowMillis);
  }

  void _createIfHost(
    String roomId,
    Room room,
    List<Mission> missions,
    int nowMillis,
  ) {
    if (ref.read(myUidProvider) != room.hostUserId) return;
    if (_creating) return;
    final lastCreatedAt = _lastCreatedAt;
    if (lastCreatedAt != null &&
        nowMillis - lastCreatedAt < _createCooldown.inMilliseconds) {
      return;
    }
    if (!shouldCreateMission(
      missions: missions,
      startedAt: room.startedAt,
      releasedAt: room.releasedAt,
      endsAt: room.endsAt,
      nowMillis: nowMillis,
    )) {
      return;
    }
    _creating = true;
    _lastCreatedAt = nowMillis;
    final generation = _generation;
    unawaited(
      ref
          .read(missionRepositoryProvider)
          .createMission(
            roomId,
            area: room.setting.gameArea,
            previousPoint: lastMissionPoint(
              missionsOfCurrentGame(missions, startedAt: room.startedAt),
            ),
            nowMillis: nowMillis,
          )
          .catchError((Object e) {
            debugPrint('[MissionController] ミッションを書けませんでした: $e');
          })
          .whenComplete(() {
            if (generation == _generation) _creating = false;
          }),
    );
  }

  void _updateProgress(Room room, List<Mission> missions, int nowMillis) {
    final mission = currentMission(
      missions,
      startedAt: room.startedAt,
      nowMillis: nowMillis,
    );
    final myUid = ref.read(myUidProvider);
    var progress = state;
    if (progress.missionId != mission?.id) {
      progress = MissionProgress(missionId: mission?.id);
    }
    final isFugitive = room.users.any(
      (u) => u.id == myUid && u.role == UserRole.fugitive,
    );
    if (mission != null && isFugitive) {
      switch (mission.type) {
        case MissionType.accessPoint:
          if (mission.claimedBy == null) {
            final myLocation = ref
                .read(locationViewModelProvider)
                .locations
                .where((l) => l.uid == myUid)
                .firstOrNull;
            progress = progress.copyWith(
              arrival: advanceArrival(
                progress.arrival,
                readAccessPoint(mission: mission, location: myLocation),
              ),
            );
          }
        case MissionType.approachDemon:
          final demonUids = {
            for (final u in room.users)
              if (u.role == UserRole.demon) u.id,
          };
          final entries = _wifiSub?.read() ?? const <WifiProximityEntry>[];
          final anyDemonClose = entries.any(
            (e) => demonUids.contains(e.uid) && e.level == ProximityLevel.close,
          );
          progress = progress.copyWith(
            approach: advanceApproach(
              progress.approach,
              anyDemonClose: anyDemonClose,
            ),
          );
      }
    }
    if (progress != state) state = progress;
  }
}

/// [MissionController]のProvider。`useGameSession`が開始・停止する。
final missionControllerProvider =
    NotifierProvider<MissionController, MissionProgress>(
      MissionController.new,
    );
