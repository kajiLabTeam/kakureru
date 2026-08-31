import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/core/utils/avatar_initial.dart';
import 'package:kakureru/core/utils/local_notifications.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/ble/repository/ble_proximity_calculator.dart';
import 'package:kakureru/features/ble/view_model/ble_view_model.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/pressure/model/relative_vertical_position.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/room/game_map_options.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/rectangle_area.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/room/role_visibility.dart';
import 'package:kakureru/features/room/view/caught_transition_overlay.dart';
import 'package:kakureru/features/room/view/game_result_page.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_ap_comparison.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';
import 'package:kakureru/features/wifi/view_model/wifi_view_model.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:vibration/vibration.dart';

/// ゲーム中の画面。ゲーム内容自体はまだ無く、残り時間と参加者の位置表示のみ行う仮実装。
class GamePage extends HookConsumerWidget {
  const GamePage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final room = roomAsync.value;
    final offset = ref.watch(serverTimeOffsetProvider).value ?? 0;
    final locationState = ref.watch(locationViewModelProvider);
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    // 「自分がどちらの役割か」はヘッダーの色・文言で常に一目で分かるようにする
    // (issue #12)。roomAsyncがまだloading/errorの間、または自分がusersに
    // 見つからない間は役割が確定しないため、その場合はヘッダーを役割色に
    // 染めず既定表示のままにする。RTDB上は参加時に必ずroleが書き込まれる
    // (docs/rtdb-schema.md)ため、usersに見つかった時点でのroleの既定値
    // フォールバック(RoomUser.role参照)は実運用では発生しない想定。
    final headerRole = _roleOf(room?.users ?? const [], myUid);
    final headerRoleTheme = headerRole != null ? roleThemeOf(headerRole) : null;

    // 残り時間を1秒ごとに再計算するためのティッカー。
    // .info/serverTimeOffset 自体はズレが変化した時にしか流れてこないため、
    // 表示を毎秒更新するにはこのタイマーで再描画をトリガーする必要がある。
    final tick = useState(0);
    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        tick.value++;
      });
      return timer.cancel;
    }, const []);

    // 「捕まった」ボタンのフィードバック用状態(issue #15)。押してから
    // RTDBへの書き込みが終わるまではボタンをローディング表示にし、
    // 成功したら全画面演出(CaughtTransitionOverlay)を出す。
    final isSubmittingCaught = useState(false);
    final showCaughtTransition = useState(false);

    // ゲーム画面に入ったら位置送信・購読を開始し、離れたら止める。
    useEffect(() {
      ref.read(locationViewModelProvider.notifier).start(roomId);
      return () => ref.read(locationViewModelProvider.notifier).stop();
    }, [roomId]);

    // GPSの実測(getPositionStream)は初回の測位に時間がかかる(コールドスタート)。
    // 端末にキャッシュされた直近の位置を getLastKnownPosition で先に取り、
    // 地図の初期表示だけに使う。RTDBへは送らない(古い位置を他の参加者に
    // 見せないため。書き込みは LocationRepository 経由の実測のみで行う)。
    final cachedPosition = useState<Position?>(null);
    useEffect(() {
      Future<void> loadCached() async {
        try {
          cachedPosition.value = await Geolocator.getLastKnownPosition();
        } on Object {
          // 取得できなくても致命的ではない(フォールバック座標を使う)。
        }
      }

      loadCached();
      return null;
    }, const []);

    // 気圧の送信もゲーム画面滞在中だけ行う。センサー購読自体は待機画面の
    // キャリブレーションで既に始まっている想定(PressureViewModel.initは
    // 何度呼んでも安全)。
    useEffect(() {
      ref.read(pressureViewModelProvider.notifier)
        ..init(roomId)
        ..startSendingToRoom(roomId);
      return () =>
          ref.read(pressureViewModelProvider.notifier).stopSendingAndDispose();
    }, [roomId]);

    // Wi-Fiスキャンもゲーム画面滞在中だけ行う。位置情報・気圧とは別の
    // 20〜30秒間隔のタイマーで動く(Androidのスキャンスロットリング対策)。
    useEffect(() {
      ref.read(wifiScanRepositoryProvider).startScanning(roomId);
      return () => ref.read(wifiScanRepositoryProvider).stopScanning();
    }, [roomId]);

    // BLEの広告・スキャンもゲーム画面滞在中だけ行う(issue #16)。myUidが
    // 確定するまで(FirebaseAuthの復元前など)は開始できない。
    useEffect(() {
      if (myUid == null) return null;
      ref.read(bleViewModelProvider.notifier).start(myUid);
      return () => ref.read(bleViewModelProvider.notifier).stop();
    }, [myUid]);

    // 鬼放出の瞬間に一度だけ端末を振動させ、通知も出す。ポケットに入れた
    // まま遊ぶ運用のため、振動だけだと画面を見ていないと気づけない。
    // tickを依存に入れて毎秒チェックし直す(releasedAt自体は変化しない
    // ため、これが無いとreleasedAtが確定した最初の一瞬しか判定されない)。
    final hasNotifiedForRelease = useRef(false);
    useEffect(() {
      final releasedAt = room?.releasedAt;
      if (releasedAt == null || hasNotifiedForRelease.value) return null;
      if (serverNowMillis(offset) >= releasedAt) {
        hasNotifiedForRelease.value = true;
        Vibration.hasVibrator().then((hasVibrator) {
          if (hasVibrator) Vibration.vibrate(duration: 800);
        });
        showDemonReleasedNotification();
      }
      return null;
    }, [room?.releasedAt, tick.value]);

    // ゲーム終了(endsAtを過ぎた、またはmeta/statusがFINISHEDになった)を
    // 検知したら結果画面へ遷移する。tickを依存に入れて毎秒チェックし直す
    // (endsAt自体は変化しないため、これが無いとendsAtが確定した最初の
    // 一瞬しか判定されない)。
    final hasNavigatedToResult = useRef(false);
    useEffect(() {
      if (hasNavigatedToResult.value || room == null) return null;
      // 「捕まった」確定演出(CaughtTransitionOverlay)の表示中に結果画面へ
      // 差し替えてしまうと演出が一瞬で消えてしまう。演出を閉じた後の
      // tick更新で改めて判定させるため、ここでは何もせず抜ける。
      if (showCaughtTransition.value) return null;
      final gameOver = isGameOver(
        status: room.status,
        endsAt: room.endsAt,
        nowMillis: serverNowMillis(offset),
      );
      if (!gameOver) return null;
      hasNavigatedToResult.value = true;
      final demonNames = room.users
          .where((u) => u.role == UserRole.demon)
          .map((u) => u.displayName)
          .toList();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameResultPage(demonNames: demonNames),
        ),
      );
      return null;
    }, [room?.status, room?.endsAt, tick.value, showCaughtTransition.value]);

    // 誰かがDEMONになったら(ホストの指名受諾・自己申告どちらでも)全員に
    // 知らせる。表示制御(役割による可視性)とは別軸の情報のため、
    // 見える/見えないに関わらず通知する。
    final previousDemonUids = useRef<Set<String>?>(null);
    ref.listen(roomStreamProvider(roomId), (prev, next) {
      final nextRoom = next.value;
      if (nextRoom == null) return;
      final currentDemonUids = nextRoom.users
          .where((u) => u.role == UserRole.demon)
          .map((u) => u.id)
          .toSet();

      final previous = previousDemonUids.value;
      if (previous != null) {
        final demonTheme = roleThemeOf(UserRole.demon);
        final uidsToNotify = uidsToNotifyOfDemonChange(
          previousDemonUids: previous,
          currentDemonUids: currentDemonUids,
          myUid: myUid,
        );
        for (final uid in uidsToNotify) {
          final name = _findUser(nextRoom.users, uid)?.displayName ?? '誰か';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: demonTheme.color,
              content: Row(
                children: [
                  Icon(demonTheme.icon, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$nameが鬼になりました',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
      previousDemonUids.value = currentDemonUids;
    });

    final pressureState = ref.watch(pressureViewModelProvider);
    final nearestVerticalPosition = ref.watch(
      nearestOpponentVerticalPositionProvider(roomId),
    );
    final bleDetections = ref.watch(bleViewModelProvider);

    // ゲーム画面からは戻れない(バックボタン・OSのスワイプ戻る等、
    // どの経路でもポップさせない)。canPop: falseにすると、
    // AppBarが自動生成する戻る矢印も含めてポップ操作自体を常にブロックする。
    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: headerRoleTheme?.color,
              foregroundColor: headerRoleTheme != null ? Colors.white : null,
              title: Text(headerRoleTheme?.label ?? 'ゲーム中'),
              actions: headerRoleTheme != null
                  ? [
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Icon(headerRoleTheme.icon),
                      ),
                    ]
                  : null,
            ),
            body: roomAsync.when(
              data: (room) {
                final now = serverNowMillis(offset);
                final myRole = _roleOf(room.users, myUid);
                final phase = determineGamePhase(
                  releasedAt: room.releasedAt,
                  nowMillis: now,
                );
                final countdownSec = calculateCountdownSeconds(
                  phase: phase,
                  releasedAt: room.releasedAt,
                  endsAt: room.endsAt,
                  nowMillis: now,
                );
                final countdownLabel = phase == GamePhase.beforeRelease
                    ? '鬼放出まで'
                    : '残り時間';

                // 役割による表示制御(7/13のプレイテストで決まった非対称な可視性)。
                // 自分は常に見える。相手は同role同士なら常に、異roleなら
                // releasedAt(鬼→逃走者)/releasedAt+fugitiveInfoDelaySec
                // (逃走者→鬼)を過ぎるまで見えない。地図・上下バー・Wi-Fi表示
                // すべてにこれを適用する。
                bool isVisibleToMe(String uid) {
                  if (uid == myUid) return true;
                  final targetRole = _roleOf(room.users, uid);
                  if (myRole == null || targetRole == null) return false;
                  return isRoleVisible(
                    viewerRole: myRole,
                    targetRole: targetRole,
                    releasedAt: room.releasedAt,
                    fugitiveInfoDelaySec: room.setting.fugitiveInfoDelaySec,
                    nowMillis: now,
                  );
                }

                final visibleLocations = locationState.locations
                    .where((location) => isVisibleToMe(location.uid))
                    .toList();
                final visibleNearestVerticalPosition =
                    nearestVerticalPosition != null &&
                        isVisibleToMe(nearestVerticalPosition.uid)
                    ? nearestVerticalPosition
                    : null;
                final visibleWifiEntries = ref
                    .watch(wifiProximityLevelsProvider(roomId))
                    .where((entry) => isVisibleToMe(entry.uid))
                    .toList();
                final rawNearestOpponentUid = ref.watch(
                  nearestOpponentUidProvider(roomId),
                );
                final visibleNearestOpponentUid =
                    rawNearestOpponentUid != null &&
                        isVisibleToMe(rawNearestOpponentUid)
                    ? rawNearestOpponentUid
                    : null;
                final visibleWifiComparisons = visibleNearestOpponentUid != null
                    ? ref.watch(topWifiComparisonsProvider(roomId))
                    : const <WifiApComparison>[];
                final visibleVerticalPositions = ref
                    .watch(relativeVerticalPositionsProvider(roomId))
                    .where((position) => isVisibleToMe(position.uid))
                    .toList();

                // 逃走者から見て、可視性ディレイでまだ見えていない鬼がいるか
                // (UI改修モック2a-04)。何も表示しないと不具合と区別が付かない
                // ため、理由を明示するカードに切り替える。
                final anyDemonHiddenFromMe =
                    myRole == UserRole.fugitive &&
                    room.users.any(
                      (u) => u.role == UserRole.demon && !isVisibleToMe(u.id),
                    );
                final hiddenOpponentReason = anyDemonHiddenFromMe
                    ? fugitiveHiddenDemonReason(
                        phase: phase,
                        releasedAt: room.releasedAt,
                        fugitiveInfoDelaySec: room.setting.fugitiveInfoDelaySec,
                        nowMillis: now,
                      )
                    : null;

                // BLEで対象の役割の相手が至近距離(3m程度)にいるかどうか(issue #16)。
                // 「捕まった」ボタン(常時表示・自己申告)とは別に、確実な捕捉を
                // 支援するためのボタンを検知時だけ追加で出す。isVisibleToMeで
                // 絞るのは、他の近接表示(Wi-Fi・気圧)と同じく「鬼タイム」中は
                // 逃走者から鬼の至近距離情報も見せない、という既存の非対称な
                // 可視性ルール(role_visibility.dart)をBLEにも適用するため。
                final opponentRoleForBle = myRole == UserRole.demon
                    ? UserRole.fugitive
                    : UserRole.demon;
                final opponentShortUids = myRole == null
                    ? const <String>{}
                    : room.users
                          .where(
                            (u) =>
                                u.role == opponentRoleForBle &&
                                u.id != myUid &&
                                isVisibleToMe(u.id),
                          )
                          .map((u) => shortenUid(u.id))
                          .toSet();
                // BLEの検知時刻(detectedAtMillis)は端末ローカル時計で記録している
                // ため、freshness判定もサーバー時刻(now)ではなく端末ローカル時刻で
                // 比較する必要がある(単位を揃えないとserverTimeOffset分ずれる)。
                final bleBecomeDemonDetected = isOpponentWithinBecomeDemonRange(
                  detections: bleDetections,
                  opponentShortUids: opponentShortUids,
                  nowMillis: DateTime.now().millisecondsSinceEpoch,
                );

                return Column(
                  children: [
                    // 鬼放出前、逃走者に「いまのうちに離れる」ことを促す
                    // バナー(UI改修モック2a-04)。鬼にはこの助言は無関係
                    // なので逃走者のみに出す。
                    if (myRole == UserRole.fugitive &&
                        phase == GamePhase.beforeRelease)
                      _PreReleaseBanner(countdownSec: countdownSec),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            countdownLabel,
                            style: const TextStyle(
                              color: appMuted,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            countdownSec == null
                                ? '計算中...'
                                : '${countdownSec < 0 ? 0 : countdownSec}秒',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (locationState.permissionDenied)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '位置情報の権限(常に許可)がないため、自分の位置を送信できません',
                          style: TextStyle(color: Color(0xFFE5484D)),
                        ),
                      ),
                    // 「捕まった」(自己申告のみ)は廃止し、BLEで近接を検知できた
                    // ときだけ出す「鬼になる」に一本化した。ローディング表示・
                    // エラー処理・確定演出(CaughtTransitionOverlay)は、旧
                    // 「捕まった」ボタンのものをそのまま踏襲している。
                    // この「鬼になる」ボタン(BLE 3m接近検知時)はissue #29の
                    // スコープ外(2a-05相当。既存のUIのまま一切変更しないと
                    // ユーザー確認済み)。アプリ全体のテーマ変更の影響も受け
                    // ないよう、Flutter標準のThemeDataで局所的に上書きする。
                    if (myRole != null &&
                        canReportCaught(role: myRole, phase: phase) &&
                        bleBecomeDemonDetected)
                      Theme(
                        data: ThemeData(useMaterial3: true),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: FilledButton.icon(
                            icon: isSubmittingCaught.value
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.priority_high),
                            label: const Text('鬼になる'),
                            onPressed: isSubmittingCaught.value
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => Theme(
                                        data: ThemeData(useMaterial3: true),
                                        child: AlertDialog(
                                          title: const Text('鬼が近くにいます'),
                                          content: const Text(
                                            'BLEで鬼が至近距離(3m程度)にいることを検知しました。'
                                            '鬼になりますか?この操作は取り消せません。',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                dialogContext,
                                              ).pop(false),
                                              child: const Text('キャンセル'),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(
                                                dialogContext,
                                              ).pop(true),
                                              child: const Text('鬼になる'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                    if (confirmed != true) return;

                                    isSubmittingCaught.value = true;
                                    try {
                                      await ref
                                          .read(roomRepositoryProvider)
                                          .reportCaught(roomId);
                                      showCaughtTransition.value = true;
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('送信に失敗しました: $e'),
                                          ),
                                        );
                                      }
                                    } finally {
                                      isSubmittingCaught.value = false;
                                    }
                                  },
                          ),
                        ),
                      ),
                    Expanded(
                      child: _LocationMap(
                        locations: visibleLocations,
                        users: room.users,
                        myUid: myUid,
                        cachedPosition: cachedPosition.value,
                        gameArea: room.setting.gameArea,
                      ),
                    ),
                    // マップの下は「いま追う相手」1人に絞った統合カード
                    // (アバター・上下判定・Wi-Fi距離感を1枚に。UI改修モック
                    // 2a-03/2a-04)。以前は上下判定とWi-Fiを別ウィジェットに
                    // 分け、Wi-Fi側もさらに3段階判定/RSSI比較をタブ切替して
                    // いたが、切替の手間と情報の分断が見にくさにつながって
                    // いたため、対象を1人に絞った上で常に両方同時表示する
                    // 形に統合した(issue #29フォローアップ)。
                    //
                    // 逃走者から見て可視性ディレイでまだ鬼が見えていない間は、
                    // 統合カードの代わりに理由を明示するカードを出す
                    // (hiddenOpponentReason != null)。
                    if (hiddenOpponentReason != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: _HiddenOpponentCard(
                          reason: hiddenOpponentReason,
                        ),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'いま追う相手',
                              style: TextStyle(color: appMuted, fontSize: 11),
                            ),
                            Text(
                              myRole == UserRole.demon
                                  ? 'いちばん近い逃走者'
                                  : 'いちばん近い鬼',
                              style: const TextStyle(
                                color: appMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _NearestOpponentCard(
                          user: visibleNearestOpponentUid == null
                              ? null
                              : _findUser(
                                  room.users,
                                  visibleNearestOpponentUid,
                                ),
                          pressureState: pressureState,
                          isCalibrated: _isCalibrated(room, myUid),
                          verticalPosition: visibleNearestVerticalPosition,
                          wifiLevel: _levelFor(
                            visibleWifiEntries,
                            visibleNearestOpponentUid,
                          ),
                          comparisons: visibleWifiComparisons,
                        ),
                      ),
                      if (visibleWifiEntries.any(
                        (e) => e.uid != visibleNearestOpponentUid,
                      )) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _OtherParticipantsRow(
                            entries: visibleWifiEntries
                                .where(
                                  (e) => e.uid != visibleNearestOpponentUid,
                                )
                                .toList(),
                            verticalPositions: visibleVerticalPositions,
                            users: room.users,
                          ),
                        ),
                      ],
                    ],
                    // BLEでの至近距離検知は逃走者にとって「鬼が来たら分かる」
                    // 安心材料になるため、常時案内しておく(UI改修モック2a-04)。
                    // モックの原文は「残り5分から有効」だが、実装ではBLEは
                    // ゲーム中ずっと有効(時間による絞り込みは無い)ため、
                    // 実態と合わない文言は載せない。
                    if (myRole == UserRole.fugitive) ...[
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _BleHintCard(),
                      ),
                    ] else
                      const SizedBox(height: 8),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('エラー: $e')),
            ),
          ),
          // 「捕まった」確定直後の全画面演出(issue #15)。マップ等の下に
          // 溜まっている再描画とは独立に、Stackの最前面に重ねるだけにする。
          if (showCaughtTransition.value)
            CaughtTransitionOverlay(
              onContinue: () => showCaughtTransition.value = false,
            ),
        ],
      ),
    );
  }
}

class _LocationMap extends HookWidget {
  const _LocationMap({
    required this.locations,
    required this.users,
    required this.myUid,
    required this.cachedPosition,
    required this.gameArea,
  });

  final List<UserLocation> locations;
  final List<RoomUser> users;
  final String? myUid;
  final Position? cachedPosition;

  /// ルーム設定で指定されたプレイエリア。未設定なら空。
  final List<LatLng> gameArea;

  @override
  Widget build(BuildContext context) {
    final selfLocation = _findLocation(locations, myUid);

    // プレイエリアが設定されていれば、地図はその範囲だけを映す。
    // 初期表示をエリアにフィットさせ、地図の中心がエリアから出ないよう制限し、
    // エリア外は影で覆う。未設定のルームでは従来どおり自分中心の地図にする。
    final areaBounds = gameAreaBounds(gameArea);
    // マスクと境界線の両方が使うので、毎秒のリビルドのたびに変換し直さない
    // よう一度だけ変換する。
    final areaPoints = useMemoized(
      () => areaBounds == null ? null : toLatLngPoints(gameArea),
      [gameArea],
    );

    // 自分の位置の情報源には優先度がある: 実測(GPS) > 端末キャッシュ > 何も無い。
    // 精度の低いソースから高いソースへ切り替わったタイミングだけ地図を
    // 動かす(常時追従させると自由にパン・ズームできなくなるため)。
    final positionTier = selfLocation != null
        ? 2
        : cachedPosition != null
        ? 1
        : 0;
    final currentCenter = selfLocation != null
        ? latlong.LatLng(selfLocation.latitude, selfLocation.longitude)
        : cachedPosition != null
        ? latlong.LatLng(cachedPosition!.latitude, cachedPosition!.longitude)
        : _initialFallbackCenter();

    final mapController = useMemoized(MapController.new);
    final bestTierShown = useRef(0);

    // GamePageは残り時間の更新で毎秒リビルドされる。CameraFitは同値でも
    // 別インスタンスだと「変わった」と判定されFlutterMap側の再設定が
    // 毎秒走るため、エリアが変わらない限り同じMapOptionsを使い回す。
    final mapOptions = useMemoized(
      () => buildGameMapOptions(
        areaBounds: areaBounds,
        fallbackCenter: currentCenter,
      ),
      [areaBounds],
    );

    useEffect(() {
      // エリア指定がある場合はエリア全体を映したままにする(自分の位置が
      // 取れるたびに寄せ直すと、せっかくのエリア表示が崩れるため)。
      if (areaBounds == null && positionTier > bestTierShown.value) {
        bestTierShown.value = positionTier;
        // MapControllerがまだレイアウト前だと move() が失敗しうるため、
        // フレーム確定後に呼ぶ。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            mapController.move(currentCenter, mapController.camera.zoom);
          } on Object {
            // 画面遷移直後などでmapがまだ存在しない場合は無視する。
          }
        });
      }
      return null;
    }, [positionTier, currentCenter.latitude, currentCenter.longitude]);

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: mapOptions,
          children: [
            // Phase 1では手軽さを優先し、追加設定・課金設定が不要な
            // OpenStreetMapのタイルをそのまま使う(flutter_map採用)。
            // Google Mapsだと google_maps_flutter 用のAPIキー発行と
            // 課金設定が要るため、開発初期の身内テスト用途には過剰。
            // 公開規模が大きくなったら自前タイルサーバや商用プロバイダへの
            // 切り替えを検討すること(OSMのタイル使用ポリシー上、
            // 本番の常用には推奨されない)。
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'me.nenex.kakureru',
            ),
            if (areaPoints != null)
              PolygonLayer(
                polygons: [
                  _outsideMaskPolygon(areaPoints),
                  _areaBorderPolygon(areaPoints),
                ],
              ),
            MarkerLayer(markers: locations.map(_buildMarker).toList()),
          ],
        ),
        if (positionTier == 0)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('現在地を取得中...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// プレイエリアの外側を覆う影。外周を世界全体(緯度±90度・経度±180度)
  /// まで広げた矩形を塗り、エリアの形を穴として抜くことで「範囲の外」
  /// だけを暗くする。
  ///
  /// 外周をエリアの周りに小さく取る(エリア+一定マージンの矩形)方式だと、
  /// カメラ中心はエリア内に制限されていてもズームだけは制限しておらず
  /// (`buildGameMapOptions` は `minZoom` を設定していない)、ズームアウト
  /// すればマージンの外側にすぐ地の地図が見えてしまう。外周を世界全体に
  /// すれば、どれだけズームアウトしても常に画面全体を覆える。
  Polygon<Object> _outsideMaskPolygon(List<latlong.LatLng> areaPoints) {
    return Polygon(
      points: const [
        latlong.LatLng(-90, -180),
        latlong.LatLng(-90, 180),
        latlong.LatLng(90, 180),
        latlong.LatLng(90, -180),
      ],
      holePointsList: [areaPoints],
      color: Colors.black.withValues(alpha: 0.35),
    );
  }

  /// プレイエリアの境界線。ルーム設定画面と同じ青い破線で揃えている。
  Polygon<Object> _areaBorderPolygon(List<latlong.LatLng> areaPoints) {
    return Polygon(
      points: areaPoints,
      borderStrokeWidth: 2,
      borderColor: _selfColor,
      pattern: StrokePattern.dashed(segments: const [8, 4]),
    );
  }

  /// 自分の位置(実測・キャッシュとも)がまだ無い間の初期センター。
  /// ルーム内の他の参加者が既にいればその位置、いなければ固定の暫定座標。
  latlong.LatLng _initialFallbackCenter() {
    if (locations.isNotEmpty) {
      final other = locations.first;
      return latlong.LatLng(other.latitude, other.longitude);
    }
    return fallbackMapCenter;
  }

  Marker _buildMarker(UserLocation location) {
    final isSelf = location.uid == myUid;
    final user = _findUser(users, location.uid);
    final color = isSelf ? _selfColor : _colorForRole(user?.role);
    final label = markerLabelFor(uid: location.uid, myUid: myUid, user: user);

    return Marker(
      point: latlong.LatLng(location.latitude, location.longitude),
      // ラベル表示のため横幅を拡張(名前が長い場合は省略表示)。
      // 縦はピンアイコン(36) + ラベル(~18) で余裕を持たせる。
      width: 72,
      height: 56,
      // Icons.location_pinは下端に尖った先端があるアイコンなので、既定の
      // Alignment.center(中央合わせ)のままだと先端が実座標より下にずれる。
      // topCenterにして先端を座標に合わせる。
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_pin, color: color, size: 36),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  UserLocation? _findLocation(List<UserLocation> locations, String? uid) {
    if (uid == null) return null;
    for (final location in locations) {
      if (location.uid == uid) return location;
    }
    return null;
  }
}

/// 自分自身を表す色(青)。docs/ui-mockup-2a.htmlの配色ルール
/// (赤=鬼/青=自分/緑=逃走者)に合わせている。
const _selfColor = Color(0xFF3B82F6);

// 取得できた位置を単純に色分けして表示する。地図・上下バー共通で使う。
// role_theme.dartと同じ配色(鬼=赤/逃走者=緑)に揃える。
Color _colorForRole(UserRole? role) {
  return role == null ? Colors.grey : roleThemeOf(role).color;
}

/// GPSピンに表示するラベルテキストを返す(issue #13)。
///
/// 自分のピンは「自分」と表示して一目で分かるようにする。
/// 他のプレイヤーは [RoomUser.displayName] を表示する。
/// displayName が空(参加直後でまだ届いていない等)のときは「?」をフォールバックにする。
@visibleForTesting
String markerLabelFor({
  required String uid,
  required String? myUid,
  required RoomUser? user,
}) {
  if (uid == myUid) return '自分';
  final name = user?.displayName ?? '';
  return name.isEmpty ? '?' : name;
}

RoomUser? _findUser(List<RoomUser> users, String uid) {
  for (final user in users) {
    if (user.id == uid) return user;
  }
  return null;
}

UserRole? _roleOf(List<RoomUser> users, String? uid) {
  if (uid == null) return null;
  return _findUser(users, uid)?.role;
}

/// [entries]から指定uidの3段階判定を探す。uidがnull、または該当エントリが
/// 無ければnull(検知なし扱い)。
ProximityLevel? _levelFor(List<WifiProximityEntry> entries, String? uid) {
  if (uid == null) return null;
  for (final entry in entries) {
    if (entry.uid == uid) return entry.level;
  }
  return null;
}

/// 自分がキャリブレーション済みかどうか。ホストは meta/basePressure、
/// 参加者は自分の users/{uid}/pressureOffset の有無で判定する
/// (待機画面の判定基準と同じ)。
bool _isCalibrated(Room room, String? myUid) {
  if (myUid == null) return false;
  if (myUid == room.hostUserId) return room.basePressure != null;
  return _findUser(room.users, myUid)?.pressureOffset != null;
}

/// 鬼放出前、逃走者に「いまのうちに離れる」ことを促すバナー
/// (UI改修モック2a-04)。
class _PreReleaseBanner extends StatelessWidget {
  const _PreReleaseBanner({required this.countdownSec});

  final int? countdownSec;

  @override
  Widget build(BuildContext context) {
    final sec = countdownSec;
    final label = sec == null ? '計算中...' : '${sec < 0 ? 0 : sec}秒';
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFFAF0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('⏳', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '鬼の放出まで $label — いまのうちに離れる',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A6A1E)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 可視性ディレイ中、逃走者に「なぜ鬼が見えないか」を明示するカード
/// (UI改修モック2a-04)。何も表示しないと不具合と区別が付かないため、
/// [fugitiveHiddenDemonReason]で計算した理由をそのまま出す。
class _HiddenOpponentCard extends StatelessWidget {
  const _HiddenOpponentCard({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCCCCCC), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Opacity(
            opacity: 0.35,
            child: Text('👹', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 4),
          const Text(
            '鬼の位置はまだ見えません',
            style: TextStyle(fontSize: 12.5, color: appMuted),
          ),
          const SizedBox(height: 2),
          Text(
            reason,
            style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA)),
          ),
        ],
      ),
    );
  }
}

/// 「いま追う相手」1人ぶんの情報を、アバター・上下判定・Wi-Fi距離感を
/// 1枚のカードにまとめて表示する(UI改修モック2a-03/2a-04)。
///
/// 以前は上下判定とWi-Fi(3段階判定/RSSI比較のタブ切替)を別ウィジェットに
/// 分けていたが、
/// 切替の手間と情報の分断が見にくさにつながっていたため、対象を
/// 「最も近い相手」1人に絞った上で常に両方を同時表示する形に統合した。
///
/// センサー非対応・未キャリブレーション・検知なしの状態は、実際に
/// 表示できる状態と明確に区別して案内する。
class _NearestOpponentCard extends StatelessWidget {
  const _NearestOpponentCard({
    required this.user,
    required this.pressureState,
    required this.isCalibrated,
    required this.verticalPosition,
    required this.wifiLevel,
    required this.comparisons,
  });

  final RoomUser? user;
  final PressureState pressureState;
  final bool isCalibrated;
  final RelativeVerticalPosition? verticalPosition;
  final ProximityLevel? wifiLevel;
  final List<WifiApComparison> comparisons;

  static const _rangeMeters = 5.0;
  static const _dotSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final target = user;
    if (target == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: appFaintBorder, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            '検知なし',
            style: TextStyle(color: appMuted, fontSize: 13),
          ),
        ),
      );
    }

    final color = _colorForRole(target.role);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: appInk, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 56, child: _identitySection(target, color)),
            const VerticalDivider(
              width: 16,
              color: appFaintBorder,
              thickness: 2,
            ),
            SizedBox(width: 52, child: _verticalSection(color)),
            const VerticalDivider(
              width: 16,
              color: appFaintBorder,
              thickness: 2,
            ),
            Expanded(child: _wifiSection(color)),
          ],
        ),
      ),
    );
  }

  Widget _identitySection(RoomUser target, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: color,
          child: Text(
            avatarInitial(target.displayName),
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          target.displayName,
          style: const TextStyle(fontSize: 11),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget _verticalSection(Color opponentColor) {
    final message = _verticalStatusMessage();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('上下', style: TextStyle(fontSize: 9.5, color: appMuted)),
        const SizedBox(height: 3),
        SizedBox(
          height: 44,
          child: message != null
              ? Center(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 8.5, color: appMuted),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(height: 3, color: _selfColor),
                          _buildDot(constraints.maxHeight, opponentColor),
                        ],
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 3),
        Text(
          _verticalLabel(),
          style: const TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  /// 実際に上下を表示できないなら理由を返す。表示できるならnull。
  String? _verticalStatusMessage() {
    if (pressureState.sensorAvailability ==
        PressureSensorAvailability.unavailable) {
      return '非対応';
    }
    if (pressureState.sensorAvailability ==
        PressureSensorAvailability.checking) {
      return '確認中';
    }
    if (!isCalibrated) {
      return '未実施';
    }
    if (verticalPosition == null) {
      return '検知なし';
    }
    return null;
  }

  String _verticalLabel() {
    final position = verticalPosition;
    if (position == null) return '';
    final meters = position.deltaMeters.abs().toStringAsFixed(0);
    return position.deltaMeters >= 0
        ? '+$meters'
              'm 上'
        : '-$meters'
              'm 下';
  }

  Widget _buildDot(double height, Color opponentColor) {
    final clamped = verticalPosition!.deltaMeters.clamp(
      -_rangeMeters,
      _rangeMeters,
    );
    // t: 0(下端)〜1(上端)。deltaMetersが正(相手が上)ほどtが大きくなる。
    final t = (clamped + _rangeMeters) / (2 * _rangeMeters);
    final top = (height * (1 - t) - _dotSize / 2).clamp(0.0, height - _dotSize);

    return Positioned(
      top: top,
      child: Container(
        width: _dotSize,
        height: _dotSize,
        decoration: BoxDecoration(
          color: opponentColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  Widget _wifiSection(Color opponentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Wi-Fi距離感',
          style: TextStyle(fontSize: 9.5, color: appMuted),
        ),
        const SizedBox(height: 2),
        Text(
          _wifiLevelLabel(),
          style: TextStyle(
            fontSize: 14,
            color: opponentColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (comparisons.isNotEmpty) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final comparison in comparisons) ...[
                  Expanded(child: _miniBar(comparison.selfRssi, _selfColor)),
                  const SizedBox(width: 2),
                  Expanded(
                    child: _miniBar(comparison.targetRssi, opponentColor),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const Text(
            '青=自分/色=相手 のRSSI',
            style: TextStyle(fontSize: 8, color: Color(0xFFAAAAAA)),
          ),
        ],
      ],
    );
  }

  String _wifiLevelLabel() {
    switch (wifiLevel) {
      case ProximityLevel.close:
        return '近い';
      case ProximityLevel.far:
        return '遠い';
      case ProximityLevel.notDetected:
      case null:
        return '検知なし';
    }
  }

  Widget _miniBar(int rssi, Color color) {
    const minRssi = -90;
    const maxRssi = -40;
    final ratio = ((rssi - minRssi) / (maxRssi - minRssi)).clamp(0.05, 1.0);
    return FractionallySizedBox(
      heightFactor: ratio,
      alignment: Alignment.bottomCenter,
      child: Container(color: color),
    );
  }
}

/// 「いま追う相手」以外の参加者を、簡潔な一行(チップ)ずつで表示する
/// (UI改修モック2a-03「他の人は下に一行ずつ」)。
class _OtherParticipantsRow extends StatelessWidget {
  const _OtherParticipantsRow({
    required this.entries,
    required this.verticalPositions,
    required this.users,
  });

  final List<WifiProximityEntry> entries;
  final List<RelativeVerticalPosition> verticalPositions;
  final List<RoomUser> users;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: entries.map((entry) {
        final user = _findUser(users, entry.uid);
        final vertical = _findVertical(entry.uid);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDDDDD), width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${user?.displayName ?? entry.uid} ${_levelLabel(entry.level)}'
            '${_arrow(vertical)}',
            style: const TextStyle(fontSize: 10.5, color: appMuted),
          ),
        );
      }).toList(),
    );
  }

  RelativeVerticalPosition? _findVertical(String uid) {
    for (final position in verticalPositions) {
      if (position.uid == uid) return position;
    }
    return null;
  }

  String _levelLabel(ProximityLevel level) {
    switch (level) {
      case ProximityLevel.close:
        return '近い';
      case ProximityLevel.far:
        return '遠い';
      case ProximityLevel.notDetected:
        return '検知なし';
    }
  }

  String _arrow(RelativeVerticalPosition? position) {
    if (position == null) return '';
    return position.deltaMeters >= 0 ? ' ↑' : ' ↓';
  }
}

/// BLEでの至近距離検知についての案内(UI改修モック2a-04)。
class _BleHintCard extends StatelessWidget {
  const _BleHintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Text('📡', style: TextStyle(fontSize: 13)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'BLEで3m以内に鬼が来ると通知されます',
              style: TextStyle(fontSize: 10.5, color: appMuted),
            ),
          ),
        ],
      ),
    );
  }
}
