import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/core/utils/duration_format.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/ble/repository/ble_proximity_calculator.dart';
import 'package:kakureru/features/ble/view_model/ble_view_model.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/pressure/model/relative_vertical_position.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/room/async_action.dart';
import 'package:kakureru/features/room/debug_mock_players.dart';
import 'package:kakureru/features/room/game_map_options.dart';
import 'package:kakureru/features/room/game_notifications.dart';
import 'package:kakureru/features/room/game_over_navigation.dart';
import 'package:kakureru/features/room/game_session.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/opponent_roster_status.dart';
import 'package:kakureru/features/room/restart_recovery.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/room/role_visibility.dart';
import 'package:kakureru/features/room/view/caught_transition_overlay.dart';
import 'package:kakureru/features/room/view/game/become_demon_button.dart';
import 'package:kakureru/features/room/view/game/become_demon_confirm_dialog.dart';
import 'package:kakureru/features/room/view/game/game_location_map.dart';
import 'package:kakureru/features/room/view/game/game_status_cards.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/room/view/game/opponent_detail_card.dart';
import 'package:kakureru/features/room/view/game/opponent_selector_chips.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:kakureru/features/wifi/model/wifi_ap_comparison.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';
import 'package:kakureru/features/wifi/view_model/wifi_view_model.dart';

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
    final myUid = ref.watch(myUidProvider);
    // 「自分がどちらの役割か」はヘッダーの色・文言で常に一目で分かるようにする
    // (issue #12)。roomAsyncがまだloading/errorの間、または自分がusersに
    // 見つからない間は役割が確定しないため、その場合はヘッダーを役割色に
    // 染めず既定表示のままにする。RTDB上は参加時に必ずroleが書き込まれる
    // (docs/rtdb-schema.md)ため、usersに見つかった時点でのroleの既定値
    // フォールバック(RoomUser.role参照)は実運用では発生しない想定。
    final headerRole = roleOf(room?.users ?? const [], myUid);
    final headerRoleTheme = headerRole != null ? roleThemeOf(headerRole) : null;

    // タイマー表示はAppBar(ヘッダー)側でも使うため、body内(roomAsync.when)
    // より前のここで計算しておく。UI改修モックはヘッダーの帯1本に役割文言と
    // タイマーを同居させているため(2a-03/2a-04)、AppBarのtitleにこの値を渡す。
    final now = serverNowMillis(offset);
    final phase = determineGamePhase(
      releasedAt: room?.releasedAt,
      nowMillis: now,
    );
    final countdownSec = calculateCountdownSeconds(
      phase: phase,
      releasedAt: room?.releasedAt,
      endsAt: room?.endsAt,
      nowMillis: now,
    );

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
    final becomeDemon = useAsyncAction(context);
    final showCaughtTransition = useState(false);

    // 詳細カードで選択中の相手(UI改修モック2a-03「逃走者を選んで詳細を見る」)。
    // nullの間は既定で最も近い相手を選ぶ(下のeffectiveSelectedUid参照)。
    // ウィジェット内で完結する一時状態なのでhooksで持つ(AGENTS.md規約)。
    final selectedOpponentUid = useState<String?>(null);

    // デバッグ用の偽プレイヤーを出しているかどうか(issue #67)。多人数での
    // 見え方は端末を人数分集めないと確認できないため、デバッグビルドでだけ
    // AppBarに出るボタンで切り替えられるようにしている。この画面を離れたら
    // 消えてよい一時状態なのでhooksで持つ(AGENTS.md規約)。
    final showMockPlayers = useState(false);

    // ゲーム画面に滞在している間だけ、位置情報・気圧・Wi-Fi・BLEを動かす。
    useGameSession(ref, roomId: roomId, myUid: myUid);

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

    // 鬼放出の瞬間に一度だけ振動+通知で知らせる。
    useDemonReleaseNotification(
      releasedAt: room?.releasedAt,
      serverTimeOffset: offset,
      tick: tick.value,
    );

    // ゲーム終了を検知したら結果画面へ遷移する。
    useGameOverNavigation(
      context,
      room: room,
      roomId: roomId,
      serverTimeOffset: offset,
      tick: tick.value,
      isShowingCaughtTransition: showCaughtTransition.value,
    );

    // 「同じメンバーでもう一回」による巻き戻しの検知。ホストが結果画面
    // (GameResultPage)で巻き戻しを実行した瞬間、この端末がまだisGameOver
    // を検知できておらずこのGamePageに留まっている場合がある(バック
    // グラウンド化・ネットワーク遅延等)。その場合でも待機画面に戻れる
    // よう、GameResultPageと同じフックをここでも使う(issue #44)。
    useRestartRecovery(ref, context, roomId: roomId);

    // 誰かが鬼になったらSnackBarで全員に知らせる。
    useDemonChangeNotifications(ref, context, roomId: roomId, myUid: myUid);

    final pressureState = ref.watch(pressureViewModelProvider);
    final bleDetections = ref.watch(bleViewModelProvider);

    // 「鬼になる」ボタンの確定処理。onPressed直下に書くとネストが深くなり
    // すぎるため、独立した関数として切り出している(挙動は従来通り)。
    //
    // 失敗はuseAsyncActionのerrorにも入るが、この画面では地図が主役で
    // エラー行を置く場所が無いためSnackBarで出す。
    Future<void> handleBecomeDemonPressed() async {
      if (!await showBecomeDemonConfirmDialog(context)) return;

      final result = await becomeDemon.run(
        () => ref.read(roomRepositoryProvider).reportCaught(roomId),
      );
      if (!context.mounted) return;
      switch (result.status) {
        case AsyncActionStatus.succeeded:
          showCaughtTransition.value = true;
        case AsyncActionStatus.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('送信に失敗しました: ${result.error}')),
          );
        case AsyncActionStatus.skipped:
          // 前の送信がまだ終わっていないだけなので、何も出さない。
          break;
      }
    }

    // ゲーム画面からは戻れない(バックボタン・OSのスワイプ戻る等、
    // どの経路でもポップさせない)。canPop: falseにすると、
    // AppBarが自動生成する戻る矢印も含めてポップ操作自体を常にブロックする。
    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          Scaffold(
            // UI改修モック(2a-03/2a-04)はヘッダーの帯1本に役割文言と
            // タイマーを左右に並べて同居させている。以前はAppBarのtitleに
            // 役割文言だけを出し、タイマーは本文側の別行に分けていたが、
            // 本文側は毎秒rebuildされるため、そのつどAppBarのtitleだけ
            // 文言色が上書きされない不具合が起きていた経緯もあり、ここで
            // 1つのRowにまとめて明示的に色を指定する。
            appBar: AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: headerRoleTheme?.color,
              foregroundColor: headerRoleTheme != null ? Colors.white : null,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    headerRoleTheme?.label ?? 'ゲーム中',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  if (headerRoleTheme != null)
                    Text(
                      countdownSec == null
                          ? '--:--'
                          : formatCountdown(countdownSec),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                      ),
                    ),
                ],
              ),
              // デバッグビルド限定の、偽プレイヤーの表示/非表示トグル
              // (issue #67)。RTDBには一切書かず、この端末の画面にだけ
              // 偽の相手を足す。kDebugModeがfalseのリリースビルドでは
              // このボタン自体が存在しない。
              actions: [
                if (kDebugMode)
                  IconButton(
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    tooltip: showMockPlayers.value
                        ? 'デバッグ用の偽プレイヤーを隠す'
                        : 'デバッグ用の偽プレイヤーを出す',
                    icon: Icon(
                      showMockPlayers.value
                          ? Icons.group
                          : Icons.group_outlined,
                    ),
                    onPressed: () =>
                        showMockPlayers.value = !showMockPlayers.value,
                  ),
              ],
            ),
            body: roomAsync.when(
              data: (room) {
                // now/phase/countdownSecはヘッダー(AppBar)側でも使うため
                // build()の上のほうで計算済み。ここではroomがnon-nullに
                // 確定した状態でそのまま使い回す。
                final myRole = roleOf(room.users, myUid);

                // 役割による表示制御(7/13のプレイテストで決まった非対称な可視性)。
                // 自分は常に見える。相手は同role同士なら常に、異roleなら
                // releasedAt(鬼→逃走者)/releasedAt+fugitiveInfoDelaySec
                // (逃走者→鬼)を過ぎるまで見えない。地図・上下バー・Wi-Fi表示
                // すべてにこれを適用する。
                bool isVisibleToMe(String uid) {
                  if (uid == myUid) return true;
                  final targetRole = roleOf(room.users, uid);
                  if (myRole == null || targetRole == null) return false;
                  return isRoleVisible(
                    viewerRole: myRole,
                    targetRole: targetRole,
                    releasedAt: room.releasedAt,
                    fugitiveInfoDelaySec: room.setting.fugitiveInfoDelaySec,
                    nowMillis: now,
                  );
                }

                // デバッグ用の偽プレイヤー(issue #67)。表示用のリストに
                // 「足すだけ」で、RTDB由来の値は書き換えないし、RTDBにも
                // 一切書かない(他の参加者には影響しない)。kDebugModeが
                // falseのリリースビルドでは、この分岐ごと落ちる
                // (game_map_options.dartと同じ方針)。
                var mockUsers = const <RoomUser>[];
                var mockWifiEntries = const <WifiProximityEntry>[];
                var mockVerticalPositions = const <RelativeVerticalPosition>[];
                var mockLocations = const <UserLocation>[];
                if (kDebugMode && showMockPlayers.value && myRole != null) {
                  final center = debugMockCenterOf(
                    locations: locationState.locations,
                    myUid: myUid,
                    fallbackLatitude:
                        cachedPosition.value?.latitude ??
                        fallbackMapCenter.latitude,
                    fallbackLongitude:
                        cachedPosition.value?.longitude ??
                        fallbackMapCenter.longitude,
                  );
                  mockUsers = debugMockUsers(myRole: myRole);
                  mockWifiEntries = debugMockWifiEntries();
                  mockVerticalPositions = debugMockVerticalPositions();
                  mockLocations = debugMockLocations(
                    centerLatitude: center.latitude,
                    centerLongitude: center.longitude,
                  );
                }
                // 地図のピンのラベル・役割色と、詳細カードの名前は
                // room.users(RTDB由来)から引くため、偽プレイヤーのぶんは
                // ここで足した表示専用の一覧を渡す。可視性やBLEの判定には
                // 使わない(そちらはRTDB由来のroom.usersのまま)。
                final displayUsers = mockUsers.isEmpty
                    ? room.users
                    : [...room.users, ...mockUsers];

                final visibleLocations = [
                  ...locationState.locations.where(
                    (location) => isVisibleToMe(location.uid),
                  ),
                  ...mockLocations,
                ];
                final visibleWifiEntries = [
                  ...ref
                      .watch(wifiProximityLevelsProvider(roomId))
                      .where((entry) => isVisibleToMe(entry.uid)),
                  ...mockWifiEntries,
                ];
                final rawNearestOpponentUid = ref.watch(
                  nearestOpponentUidProvider(roomId),
                );
                final visibleNearestOpponentUid =
                    rawNearestOpponentUid != null &&
                        isVisibleToMe(rawNearestOpponentUid)
                    ? rawNearestOpponentUid
                    : null;
                final visibleVerticalPositions = [
                  ...ref
                      .watch(relativeVerticalPositionsProvider(roomId))
                      .where((position) => isVisibleToMe(position.uid)),
                  ...mockVerticalPositions,
                ];

                // 「対象の役割」(自分と逆の役割)。BLEの至近距離検知、相手
                // 選択チップ、「まだ見えない理由」の3つで使う。
                final opponentRole = myRole == UserRole.demon
                    ? UserRole.fugitive
                    : UserRole.demon;

                // 可視性ディレイでまだ見えていない相手がいるか
                // (UI改修モック2a-04)。何も表示しないと不具合と区別が付かない
                // ため、理由を明示するカードに切り替える。鬼放出前は鬼からも
                // 逃走者が見えない(role_visibility.dart)ので、逃走者視点だけ
                // でなく鬼視点でも出す(issue #30)。
                final anyOpponentHiddenFromMe =
                    myRole != null &&
                    room.users.any(
                      (u) => u.role == opponentRole && !isVisibleToMe(u.id),
                    );
                final hiddenReason = myRole == null || !anyOpponentHiddenFromMe
                    ? null
                    : hiddenOpponentReason(
                        viewerRole: myRole,
                        phase: phase,
                        releasedAt: room.releasedAt,
                        fugitiveInfoDelaySec: room.setting.fugitiveInfoDelaySec,
                        nowMillis: now,
                      );

                // BLEで対象の役割の相手が至近距離(3m程度)にいるかどうか(issue #16)。
                // 「捕まった」ボタン(常時表示・自己申告)とは別に、確実な捕捉を
                // 支援するためのボタンを検知時だけ追加で出す。isVisibleToMeで
                // 絞るのは、他の近接表示(Wi-Fi・気圧)と同じく「鬼タイム」中は
                // 逃走者から鬼の至近距離情報も見せない、という既存の非対称な
                // 可視性ルール(role_visibility.dart)をBLEにも適用するため。
                final opponentShortUids = myRole == null
                    ? const <String>{}
                    : room.users
                          .where(
                            (u) =>
                                u.role == opponentRole &&
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

                // 相手選択チップの一覧(UI改修モック2a-03「逃走者を選んで詳細を
                // 見る」)。Wi-Fiスキャン結果がまだ無い相手(visibleWifiEntries
                // には現れない)も「検知なし」として一覧には出す必要があるため、
                // room.usersを起点に絞り込む(visibleWifiEntriesを起点にすると
                // スキャン未着の相手が一覧から消えてしまう)。
                final opponentRoster = myRole == null
                    ? const <RoomUser>[]
                    : [
                        ...room.users.where(
                          (u) =>
                              u.role == opponentRole &&
                              u.id != myUid &&
                              isVisibleToMe(u.id),
                        ),
                        ...mockUsers,
                      ];
                final rosterUids = opponentRoster.map((u) => u.id).toSet();
                // 選択中のuidがまだ一覧に残っていればそれを使い、無ければ
                // (未選択・退室・可視性が外れた等)既定で最も近い相手に戻す。
                final effectiveSelectedUid =
                    selectedOpponentUid.value != null &&
                        rosterUids.contains(selectedOpponentUid.value)
                    ? selectedOpponentUid.value
                    : visibleNearestOpponentUid;
                final selectedComparisons = effectiveSelectedUid != null
                    ? ref.watch(
                        wifiComparisonsForProvider((
                          roomId,
                          effectiveSelectedUid,
                        )),
                      )
                    : const <WifiApComparison>[];

                return Column(
                  children: [
                    // 鬼放出前、逃走者に「いまのうちに離れる」ことを促す
                    // バナー(UI改修モック2a-04)。鬼にはこの助言は無関係
                    // なので逃走者のみに出す。
                    if (myRole == UserRole.fugitive &&
                        phase == GamePhase.beforeRelease)
                      PreReleaseBanner(countdownSec: countdownSec),
                    if (locationState.permissionDenied)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '位置情報の権限(常に許可)がないため、自分の位置を送信できません',
                          style: TextStyle(color: Color(0xFFE5484D)),
                        ),
                      ),
                    // 「捕まった」(自己申告のみ)は廃止し、BLEで近接を検知できた
                    // ときだけ押せる「鬼になる」に一本化した。ローディング表示・
                    // エラー処理・確定演出(CaughtTransitionOverlay)は、旧
                    // 「捕まった」ボタンのものをそのまま踏襲している。
                    //
                    // ボタン自体は常に表示し、BLEで検知していない間はdisabled
                    // にする(issue #43)。以前(issue #16/#29)はBLE検知時だけ
                    // Widgetごと出し入れする方式だったが、検知距離が閾値付近を
                    // 行き来するたびにボタンの出現/消滅でレイアウト全体が
                    // 上下にガタつく問題があった。「常時表示にすると誤タップが
                    // 増えるのでは」という2a-05以来の懸念は、disabledのままなら
                    // 押しても何も起きない=誤タップにならないため両立する
                    // (誤タップ防止という元の目的はdisabled化で引き継ぐ)。
                    // アプリ全体のテーマ変更の影響も受けないよう、Flutter標準の
                    // ThemeDataで局所的に上書きする構造は維持する。
                    if (shouldShowBecomeDemonButton(role: myRole, phase: phase))
                      BecomeDemonButton(
                        isDetected: bleBecomeDemonDetected,
                        isSubmitting: becomeDemon.isRunning,
                        onPressed: handleBecomeDemonPressed,
                      ),
                    Expanded(
                      child: GameLocationMap(
                        locations: visibleLocations,
                        users: displayUsers,
                        myUid: myUid,
                        cachedPosition: cachedPosition.value,
                        gameArea: room.setting.gameArea,
                      ),
                    ),
                    // マップの下は、対象役割の相手をタップで選べるチップ一覧と、
                    // 選んだ1人だけの詳細カード(UI改修モック2a-03「逃走者を
                    // 選んで詳細を見る」)。人数が増えても見やすいよう、対象を
                    // 常に1人だけに絞って詳細(上下判定+Wi-Fi距離感)を出す
                    // (issue #29フォローアップ)。
                    //
                    // チップ一覧が出せないときは、その理由を明示するカードに
                    // 差し替える。「可視性ディレイでまだ見えない」「対象役割
                    // の相手がそもそも居ない」「居るがまだ検知できていない」
                    // の3つは、以前は一律「検知なし」と出していて区別が付か
                    // なかった(issue #30)。
                    if (opponentRoster.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: HiddenOpponentCard(
                          message: emptyOpponentMessage(
                            // 役割がまだ確定していない間の扱いは
                            // opponentRoleの既定と揃える(鬼と確定するまで
                            // 逃走者側として扱う)。
                            viewerRole: myRole ?? UserRole.fugitive,
                            opponentCountInRoom: room.users
                                .where((u) => u.role == opponentRole)
                                .length,
                            hiddenReason: hiddenReason,
                          ),
                        ),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          opponentRole == UserRole.fugitive
                              ? '逃走者を選んで詳細を見る'
                              : '鬼を選んで詳細を見る',
                          style: const TextStyle(color: appMuted, fontSize: 11),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OpponentSelectorChips(
                          roster: opponentRoster,
                          entries: visibleWifiEntries,
                          selectedUid: effectiveSelectedUid,
                          onSelect: (uid) => selectedOpponentUid.value = uid,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OpponentDetailCard(
                          user: effectiveSelectedUid == null
                              ? null
                              : findUser(displayUsers, effectiveSelectedUid),
                          pressureState: pressureState,
                          isCalibrated: isCalibrated(room, myUid),
                          verticalPosition: verticalFor(
                            visibleVerticalPositions,
                            effectiveSelectedUid,
                          ),
                          wifiLevel: levelFor(
                            visibleWifiEntries,
                            effectiveSelectedUid,
                          ),
                          comparisons: selectedComparisons,
                        ),
                      ),
                    ],
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
