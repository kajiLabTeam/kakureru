import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/core/utils/local_notifications.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/mission/mission_notice_rules.dart';
import 'package:kakureru/features/mission/mission_rules.dart';
import 'package:kakureru/features/mission/mission_timing.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/mission/model/mission_notice.dart';
import 'package:kakureru/features/mission/model/mission_progress.dart';
import 'package:kakureru/features/mission/model/room_effect.dart';
import 'package:kakureru/features/mission/repository/mission_repository.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:vibration/vibration.dart';

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

/// [state]のときアプリが前面(画面に出ている)とみなすか。
///
/// 起動直後は`lifecycleState`がまだnullのことがあり、そのときも前面と
/// みなす(前面なのにOSの通知へ回さないため)。`inactive`(通知シェードを
/// 下ろした等)も画面には出ているので前面。`hidden`/`paused`/`detached`
/// だけを裏とみなす。
bool isForegroundLifecycle(AppLifecycleState? state) => switch (state) {
  null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
  AppLifecycleState.hidden ||
  AppLifecycleState.paused ||
  AppLifecycleState.detached => false,
};

/// ミッションのお知らせの出し先。テストでは差し替えて、何を出したかを
/// 記録する。
class MissionAlertSink {
  const MissionAlertSink();

  /// アプリを開いて画面に出ているか。開いていればバナー、閉じていれば
  /// OSの通知にする。判定は[isForegroundLifecycle]。
  bool get isForeground =>
      isForegroundLifecycle(WidgetsBinding.instance.lifecycleState);

  /// 1回だけ振動させる(音は鳴らさない)。振動できない端末では何もしない。
  Future<void> vibrate() async {
    try {
      if (!await Vibration.hasVibrator()) return;
      await Vibration.vibrate(duration: _missionVibrationMillis);
    } on Object catch (e) {
      debugPrint('[MissionAlertSink] 振動に失敗: $e');
    }
  }

  /// OSの通知を出す(音なし・振動だけ。[showMissionNotification]参照)。
  Future<void> notify(String message) => showMissionNotification(message);
}

/// お知らせの振動の長さ(ミリ秒)。
const _missionVibrationMillis = 400;

/// [MissionAlertSink]のProvider。
final Provider<MissionAlertSink> missionAlertSinkProvider = Provider(
  (ref) => const MissionAlertSink(),
);

/// アプリを開いているときに、地図の上へ出すミッションのお知らせ(バナー)。
/// 出していなければnull。[missionBannerDuration]で自動で消える。
class MissionBannerController extends Notifier<MissionNotice?> {
  Timer? _timer;

  @override
  MissionNotice? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// バナーを出す(前のものは置き換える)。
  void show(MissionNotice notice) {
    _timer?.cancel();
    state = notice;
    _timer = Timer(missionBannerDuration, dismiss);
  }

  /// バナーを消す(タップしたとき・時間切れ)。
  void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (state != null) state = null;
  }
}

/// [MissionBannerController]のProvider。
final missionBannerProvider =
    NotifierProvider<MissionBannerController, MissionNotice?>(
      MissionBannerController.new,
    );

/// ミッションの生成(ホストの端末だけ)、自分の進み具合(到着)の判定、
/// お知らせ(逃走者だけ)を、**画面が消えていても**1秒ごとに進める駆動役。
///
/// `GameAlerts`と同じ理由でウィジェットの再描画から切り離している:
/// 画面が消えるとフレームが止まり、`build`に乗せた判定は進まない。
/// ポケットに入れたまま地点に着く、が普通にあるため。
///
/// - **生成**: サーバーが無いので、ホスト(`meta/hostUserId`)の端末が
///   [missionRoundToCreate]を見て `missions` に書く。ホストが落ちたら
///   ミッションは出なくなる(ゲームは続く)
/// - **進み具合**: 自分の位置から、いちばん近い空いている地点への到着を
///   [advanceArrival]で持ち越す。RTDBには書かない
/// - **お知らせ**: [dueMissionNotices]を見て、アプリを開いていればバナー
///   ([missionBannerProvider])、閉じていればOSの通知。どちらも音なしで
///   振動だけ
///
/// 判定のロジック自体はここに書かず、`mission_rules.dart` /
/// `mission_notice_rules.dart`の純粋関数を呼ぶ。
class MissionController extends Notifier<MissionProgress> {
  Timer? _timer;
  String? _roomId;
  int _generation = 0;
  bool _disposed = false;

  // 購読を持っておく理由は GameAlerts の `_roomSub` と同じ(StreamProviderは
  // 誰かが購読していないと読み始めず、autoDisposeなので読んだ直後に消える)。
  ProviderSubscription<AsyncValue<Room>>? _roomSub;
  ProviderSubscription<AsyncValue<int>>? _offsetSub;
  ProviderSubscription<AsyncValue<List<Mission>>>? _missionsSub;

  bool _creating = false;
  int? _lastCreatedAt;

  /// 出したお知らせのキー([MissionNotice.key])。同じものを二度出さない。
  final Set<String> _notified = {};

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
    _timer = Timer.periodic(missionEvaluateInterval, (_) => _evaluate());
  }

  /// ゲーム画面を離れたときに呼ぶ。進み具合も捨てる(次の部屋へ持ち越さない)。
  void stop() {
    final generation = ++_generation;
    _disposeTimers();
    _roomId = null;
    _creating = false;
    _lastCreatedAt = null;
    _notified.clear();
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
    final myUid = ref.read(myUidProvider);
    final isFugitive = room.users.any(
      (u) => u.id == myUid && u.role == UserRole.fugitive,
    );
    final myLocation = ref
        .read(locationViewModelProvider)
        .locations
        .where((l) => l.uid == myUid)
        .firstOrNull;
    _updateProgress(
      room,
      missions,
      nowMillis,
      isFugitive: isFugitive,
      myUid: myUid,
      myLocation: myLocation,
    );
    if (isFugitive) _announce(room, missions, nowMillis, myLocation);
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
        nowMillis - lastCreatedAt < missionCreateCooldown.inMilliseconds) {
      return;
    }
    final round = missionRoundToCreate(
      missions: missions,
      startedAt: room.startedAt,
      releasedAt: room.releasedAt,
      endsAt: room.endsAt,
      nowMillis: nowMillis,
    );
    if (round == null) return;
    final demonCount = room.users.where((u) => u.role == UserRole.demon).length;
    _creating = true;
    _lastCreatedAt = nowMillis;
    final generation = _generation;
    unawaited(
      ref
          .read(missionRepositoryProvider)
          .createMission(
            roomId,
            area: room.setting.gameArea,
            spotCount: missionSpotCount(
              round: round,
              demonCount: demonCount,
              participantCount: room.users.length,
            ),
            round: round,
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

  void _updateProgress(
    Room room,
    List<Mission> missions,
    int nowMillis, {
    required bool isFugitive,
    required String? myUid,
    required UserLocation? myLocation,
  }) {
    final mission = currentMission(
      missions,
      startedAt: room.startedAt,
      nowMillis: nowMillis,
    );
    var progress = state;
    if (progress.missionId != mission?.id) {
      progress = MissionProgress(missionId: mission?.id);
    }
    if (mission != null &&
        isFugitive &&
        spotClaimedBy(mission, myUid) == null &&
        isMissionActive(mission, nowMillis: nowMillis)) {
      final spot = nearestOpenSpot(mission, myLocation);
      // 向かう地点が変わったら(取られた・近い方が入れ替わった)数え直す。
      if (progress.spotId != spot?.id) {
        progress = MissionProgress(missionId: mission.id, spotId: spot?.id);
      }
      progress = progress.copyWith(
        arrival: advanceArrival(
          progress.arrival,
          readAccessPoint(spot: spot, location: myLocation),
        ),
      );
    }
    if (progress != state) state = progress;
  }

  void _announce(
    Room room,
    List<Mission> missions,
    int nowMillis,
    UserLocation? myLocation,
  ) {
    final current = missionsOfCurrentGame(missions, startedAt: room.startedAt);
    final notices = dueMissionNotices(
      mission: current.lastOrNull,
      nowMillis: nowMillis,
      notified: _notified,
      location: myLocation,
      nameOf: (uid) =>
          room.users.where((u) => u.id == uid).firstOrNull?.displayName ??
          'だれか',
    );
    if (notices.isEmpty) return;
    // dueMissionNoticesは1回に高々1件しか返さない(3種類は時間帯が
    // 重ならない)。念のため複数でも全部を出した扱いにし、最後の1件だけ出す。
    _notified.addAll(notices.map((n) => n.key));
    final notice = notices.last;
    final sink = ref.read(missionAlertSinkProvider);
    if (sink.isForeground) {
      ref.read(missionBannerProvider.notifier).show(notice);
      unawaited(sink.vibrate());
    } else {
      // 通知のチャンネル側で振動する(音なし)。
      unawaited(sink.notify(notice.message));
    }
  }
}

/// [MissionController]のProvider。`useGameSession`が開始・停止する。
final missionControllerProvider =
    NotifierProvider<MissionController, MissionProgress>(
      MissionController.new,
    );
