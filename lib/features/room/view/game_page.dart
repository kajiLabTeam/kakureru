import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/utils/local_notifications.dart';
import 'package:kakureru/core/utils/server_time.dart';
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

/// Wi-Fi近接判定の表示方式。GamePage上でいつでも切り替えられる。
enum _WifiDisplayMode {
  /// 参加者ごとの3段階判定(近い/遠い/検知なし)。
  levels,

  /// 最も近い相手との上位3AP RSSI生データ比較。
  rssiBars,
}

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
    final wifiDisplayMode = useState(_WifiDisplayMode.levels);

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

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        countdownSec == null
                            ? '$countdownLabel: 計算中...'
                            : '$countdownLabel: ${countdownSec < 0 ? 0 : countdownSec}秒',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (locationState.permissionDenied)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '位置情報の権限(常に許可)がないため、自分の位置を送信できません',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    if (myRole != null &&
                        canReportCaught(role: myRole, phase: phase))
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: FilledButton.tonalIcon(
                          icon: isSubmittingCaught.value
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.warning_amber),
                          label: const Text('捕まった'),
                          onPressed: isSubmittingCaught.value
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('捕まりましたか?'),
                                      content: const Text(
                                        '鬼になります。この操作は取り消せません。',
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
                                          child: const Text('捕まった'),
                                        ),
                                      ],
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
                    Expanded(
                      child: _LocationMap(
                        locations: visibleLocations,
                        users: room.users,
                        myUid: myUid,
                        cachedPosition: cachedPosition.value,
                        gameArea: room.setting.gameArea,
                      ),
                    ),
                    // マップの下に「鬼(または逃走者)との上下関係」と「Wi-Fi近接表示」を
                    // 横並びで置く。ゲーム中にちらっと見てすぐ分かることを優先し、
                    // どちらも常に同時に見える位置にしている。
                    SizedBox(
                      height: 200,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _NearestOpponentVerticalIndicator(
                            pressureState: pressureState,
                            isCalibrated: _isCalibrated(room, myUid),
                            position: visibleNearestVerticalPosition,
                            opponentRole: _roleOf(
                              room.users,
                              visibleNearestVerticalPosition?.uid,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                SegmentedButton<_WifiDisplayMode>(
                                  segments: const [
                                    ButtonSegment(
                                      value: _WifiDisplayMode.levels,
                                      label: Text('3段階判定'),
                                    ),
                                    ButtonSegment(
                                      value: _WifiDisplayMode.rssiBars,
                                      label: Text('RSSI比較'),
                                    ),
                                  ],
                                  selected: {wifiDisplayMode.value},
                                  onSelectionChanged: (selection) =>
                                      wifiDisplayMode.value = selection.first,
                                ),
                                Expanded(
                                  child:
                                      wifiDisplayMode.value ==
                                          _WifiDisplayMode.levels
                                      ? _WifiProximityLevelsView(
                                          entries: visibleWifiEntries,
                                          users: room.users,
                                        )
                                      : _WifiRssiCompareView(
                                          comparisons: visibleWifiComparisons,
                                          nearestUid: visibleNearestOpponentUid,
                                          users: room.users,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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
      borderColor: Colors.blue,
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
    final color = isSelf ? Colors.blue : _colorForRole(user?.role);
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

// 取得できた位置を単純に色分けして表示する。地図・上下バー共通で使う。
Color _colorForRole(UserRole? role) {
  return role == UserRole.demon ? Colors.red : Colors.green;
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

/// 自分がキャリブレーション済みかどうか。ホストは meta/basePressure、
/// 参加者は自分の users/{uid}/pressureOffset の有無で判定する
/// (待機画面の判定基準と同じ)。
bool _isCalibrated(Room room, String? myUid) {
  if (myUid == null) return false;
  if (myUid == room.hostUserId) return room.basePressure != null;
  return _findUser(room.users, myUid)?.pressureOffset != null;
}

/// 気圧センサーによる「鬼(または逃走者)との上下関係」表示。
///
/// 以前は参加者全員を1本のバーに重ねていたが、誰が誰か分かりにくかった
/// ため、Wi-Fiの近接判定と同じ「最も近い対象の役割の相手」1人だけに絞った
/// (nearestOpponentVerticalPositionProvider参照)。表示対象を揃えることで
/// 認知負荷を下げる狙い。
///
/// センサー非対応・未キャリブレーション・検知なしの3状態を、実際に上下を
/// 表示できる状態と明確に区別して案内する。
class _NearestOpponentVerticalIndicator extends StatelessWidget {
  const _NearestOpponentVerticalIndicator({
    required this.pressureState,
    required this.isCalibrated,
    required this.position,
    required this.opponentRole,
  });

  final PressureState pressureState;
  final bool isCalibrated;
  final RelativeVerticalPosition? position;
  final UserRole? opponentRole;

  static const _rangeMeters = 5.0;
  static const _dotSize = 22.0;
  static const _boxWidth = 88.0;

  @override
  Widget build(BuildContext context) {
    final message = _statusMessage();

    return SizedBox(
      width: 120,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('上', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                width: _boxWidth,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: message != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final height = constraints.maxHeight;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // 自分の中心線。太線+色ではっきり区別する。
                              Container(height: 4, color: Colors.blue),
                              _buildDot(height),
                            ],
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 4),
            const Text('下', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  /// 実際に上下を表示できないなら理由を返す。表示できるならnull。
  String? _statusMessage() {
    if (pressureState.sensorAvailability ==
        PressureSensorAvailability.unavailable) {
      return 'この端末は非対応';
    }
    if (pressureState.sensorAvailability ==
        PressureSensorAvailability.checking) {
      return '確認中...';
    }
    if (!isCalibrated) {
      return 'キャリブレーションが必要です';
    }
    if (position == null) {
      return '検知なし';
    }
    return null;
  }

  Widget _buildDot(double height) {
    final clamped = position!.deltaMeters.clamp(-_rangeMeters, _rangeMeters);
    // t: 0(下端)〜1(上端)。deltaMetersが正(相手が上)ほどtが大きくなる。
    final t = (clamped + _rangeMeters) / (2 * _rangeMeters);
    final top = (height * (1 - t) - _dotSize / 2).clamp(0.0, height - _dotSize);

    return Positioned(
      top: top,
      child: Container(
        width: _dotSize,
        height: _dotSize,
        decoration: BoxDecoration(
          color: _colorForRole(opponentRole),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

/// Wi-Fi近接判定 表示方式A: 参加者ごとの3段階判定。
class _WifiProximityLevelsView extends StatelessWidget {
  const _WifiProximityLevelsView({required this.entries, required this.users});

  final List<WifiProximityEntry> entries;
  final List<RoomUser> users;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Wi-Fiスキャン結果を待っています...'),
      );
    }

    return ListView(
      children: entries.map((entry) {
        final user = _findUser(users, entry.uid);
        return ListTile(
          dense: true,
          leading: Icon(
            Icons.circle,
            size: 12,
            color: _colorForRole(user?.role),
          ),
          title: Text(user?.displayName ?? entry.uid),
          trailing: Text(_labelFor(entry.level)),
        );
      }).toList(),
    );
  }

  String _labelFor(ProximityLevel level) {
    switch (level) {
      case ProximityLevel.close:
        return '近い';
      case ProximityLevel.far:
        return '遠い';
      case ProximityLevel.notDetected:
        return '検知なし';
    }
  }
}

/// Wi-Fi近接判定 表示方式B: 判定を経由しない生RSSIバー比較。
///
/// 比較対象は最も近い「対象の役割」の相手(nearestOpponentUidProvider)。
/// 共通APのうち自分・相手のRSSI平均が強い上位3つを、それぞれ自分の
/// バーと相手のバーを並べて表示する(数値そのものは出さず、長さで見せる)。
class _WifiRssiCompareView extends StatelessWidget {
  const _WifiRssiCompareView({
    required this.comparisons,
    required this.nearestUid,
    required this.users,
  });

  final List<WifiApComparison> comparisons;
  final String? nearestUid;
  final List<RoomUser> users;

  static const _minRssi = -90;
  static const _maxRssi = -40;
  static const _maxBarWidth = 100.0;
  static const _circledNumbers = ['①', '②', '③'];

  @override
  Widget build(BuildContext context) {
    final targetUid = nearestUid;
    if (targetUid == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('比較対象が見つかりません(検知なし)'),
      );
    }

    final targetUser = _findUser(users, targetUid);
    final targetColor = _colorForRole(targetUser?.role);
    final targetLabel = targetUser?.role == UserRole.demon ? '鬼' : '逃走者';

    if (comparisons.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('${targetUser?.displayName ?? targetLabel} との共通APがまだありません'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '比較対象: ${targetUser?.displayName ?? targetLabel}($targetLabel)',
            style: TextStyle(color: targetColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < comparisons.length; i++)
            _buildApRow(i, comparisons[i], targetLabel, targetColor),
        ],
      ),
    );
  }

  Widget _buildApRow(
    int index,
    WifiApComparison comparison,
    String targetLabel,
    Color targetColor,
  ) {
    final number = index < _circledNumbers.length
        ? _circledNumbers[index]
        : '${index + 1}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text('Wi-Fi$number', style: const TextStyle(fontSize: 12)),
          ),
          const Text('自分', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          _bar(comparison.selfRssi, Colors.blue),
          const SizedBox(width: 12),
          Text(targetLabel, style: TextStyle(fontSize: 12, color: targetColor)),
          const SizedBox(width: 4),
          _bar(comparison.targetRssi, targetColor),
        ],
      ),
    );
  }

  Widget _bar(int rssi, Color color) {
    final ratio = ((rssi - _minRssi) / (_maxRssi - _minRssi)).clamp(0.0, 1.0);
    return Container(width: _maxBarWidth * ratio + 4, height: 10, color: color);
  }
}
