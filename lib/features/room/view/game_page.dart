import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/ble/view_model/ble_view_model.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/mission/effect_rules.dart';
import 'package:kakureru/features/mission/mission_rules.dart';
import 'package:kakureru/features/mission/mission_timing.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/repository/mission_repository.dart';
import 'package:kakureru/features/mission/view/effect_band.dart';
import 'package:kakureru/features/mission/view/held_reward_bar.dart';
import 'package:kakureru/features/mission/view/mission_card.dart';
import 'package:kakureru/features/mission/view/gacha/gacha_page.dart';
import 'package:kakureru/features/mission/view/mission_notice_banner.dart';
import 'package:kakureru/features/mission/view_model/mission_view_model.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/pressure/model/relative_vertical_position.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/room/area_alert.dart';
import 'package:kakureru/features/room/async_action.dart';
import 'package:kakureru/features/room/catch_flow.dart';
import 'package:kakureru/features/room/catch_rules.dart';
import 'package:kakureru/features/room/debug_mock_players.dart';
import 'package:kakureru/features/room/error_message.dart';
import 'package:kakureru/features/room/game_alerts.dart';
import 'package:kakureru/features/room/game_map_options.dart';
import 'package:kakureru/features/room/game_notifications.dart';
import 'package:kakureru/features/room/game_over_navigation.dart';
import 'package:kakureru/features/room/game_session.dart';
import 'package:kakureru/features/room/model/clue_floor_math.dart';
import 'package:kakureru/features/room/model/photo_slot.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/new_photo_badge.dart';
import 'package:kakureru/features/room/opponent_roster_status.dart';
import 'package:kakureru/features/room/photo_capture_config.dart';
import 'package:kakureru/features/room/photo_taken_notifications.dart';
import 'package:kakureru/features/room/repository/event_log_repository.dart';
import 'package:kakureru/features/room/restart_recovery.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/room/role_visibility.dart';
import 'package:kakureru/features/room/view/catch_capture_page.dart';
import 'package:kakureru/features/room/view/game/area_rules_dialog.dart';
import 'package:kakureru/features/room/view/game/catch_announcement_card.dart';
import 'package:kakureru/features/room/view/game/catch_button_strip.dart';
import 'package:kakureru/features/room/view/game/catch_photo_section.dart';
import 'package:kakureru/features/room/view/game/catch_target_sheet.dart';
import 'package:kakureru/features/room/view/game/caught_by_demon_overlay.dart';
import 'package:kakureru/features/room/view/game/clue_card.dart';
import 'package:kakureru/features/room/view/game/clue_guide_page.dart';
import 'package:kakureru/features/room/view/game/clue_trend_scope.dart';
import 'package:kakureru/features/room/view/game/debug_mock_players_toggle.dart';
import 'package:kakureru/features/room/view/game/game_header_bar.dart';
import 'package:kakureru/features/room/view/game/game_location_map.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';
import 'package:kakureru/features/room/view/game/game_status_cards.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/room/view/game/map_photo_tab_bar.dart';
import 'package:kakureru/features/room/view/game/opponent_selector_chips.dart';
import 'package:kakureru/features/room/view/game/outside_area_alert.dart';
import 'package:kakureru/features/room/view/game/photo_capture_banner.dart';
import 'package:kakureru/features/room/view/game/sighting_photo_button.dart';
import 'package:kakureru/features/room/view/photo_gallery_page.dart';
import 'package:kakureru/features/room/view/room_stream_error.dart';
import 'package:kakureru/features/room/view_model/photo_capture_controller.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:kakureru/features/wifi/model/wifi_ap_comparison.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';
import 'package:kakureru/features/wifi/view_model/wifi_view_model.dart';
import 'package:kakureru/features/wifi/wifi_clue_math.dart';

/// 位置が送れていないときに画面上部へ出す赤い警告文。問題なければnull。
///
/// 同じ「自分の位置が出ない」でも直し方が違うので、原因ごとに案内を変える。
/// 以前は全部まとめて「権限(常に許可)がない」と出していたため、権限はある
/// のにForeground Serviceが起動できていないケースで、設定を見に行っても
/// 何も直らない案内になっていた(issue #66)。
///
/// 特に通知の拒否は要注意で、位置情報の許可を促す文言を出すと、ユーザーは
/// 設定で位置情報が許可済みなのを確認して詰む(issue #66のレビュー指摘)。
///
/// どの原因でも自分の位置が無い状態なので、**エリア外アラートも効かない**
/// ことを併記する(issue #61)。一番エリアの外に出そうな人(GPSが無く鬼からも
/// 見えない人)が、警告も受けないまま出ていくことになるため、送信だけの話に
/// 読めると気づけない。
String? locationWarningMessage(LocationState state) {
  final cause = switch (state.failure) {
    LocationFailure.none => null,
    LocationFailure.serviceDisabled =>
      '端末の位置情報がOFFになっています。設定から位置情報をONにしてから戻ってください',
    LocationFailure.locationPermission =>
      'このアプリに位置情報が許可されていないため、自分の位置を送信できません。'
          '設定から位置情報を許可してから戻ってください',
    LocationFailure.notificationPermission =>
      '通知が許可されていないため、自分の位置を送信できません。'
          '設定から通知を許可してから戻ってください',
    LocationFailure.sendingFailed =>
      '位置情報の送信を開始できませんでした。'
          'アプリのバッテリー最適化を外すか、ゲーム画面に入り直してください',
  };
  if (cause == null) return null;
  return '$cause(エリア外アラートも出ません)';
}

/// ゲーム中の画面。ゲーム内容自体はまだ無く、残り時間と参加者の位置表示のみ行う仮実装。
class GamePage extends HookConsumerWidget {
  const GamePage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final room = roomAsync.value;
    final photosAsync = ref.watch(photosStreamProvider(roomId));
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

    // 残り時間の**表示**を1秒ごとに描き直すためのティッカー。
    // .info/serverTimeOffset 自体はズレが変化した時にしか流れてこないため、
    // 表示を毎秒更新するにはこのタイマーで再描画をトリガーする必要がある。
    //
    // 値そのものは読まない。書き込みが再描画を呼び、その中で now が
    // 取り直されるのが目的。時間で発火する**判定**はここではなく
    // GameAlerts 側にある(画面が消えると再描画は止まるため。issue #71)。
    final tick = useState(0);
    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        tick.value++;
      });
      return timer.cancel;
    }, const []);

    // 鬼の「捕まえた」(issue #140)。選択シート・撮影画面(CatchCapturePage)を
    // 開いている間は、ボタンを押せなくし、ゲーム終了の自動遷移を止める
    // (captureOpen。handleCatchPressed参照)。
    final captureOpen = useState(false);

    // ミッションの「ごほうびガチャを引く」。送信中はボタンをローディング表示にし、
    // 取れたら確定演出(GachaPage)を開く。開いている間はゲーム終了の
    // 自動遷移を止める(captureOpenと同じ)。
    final claimAction = useAsyncAction(context);
    final rewardOpen = useState(false);

    // デバッグ用の「ミッションをいますぐ出す」の書き込み中(DEBUG_MISSION)。
    final debugCreateAction = useAsyncAction(context);

    // 持っているごほうび(鬼の手がかりを止める)の「つかう」の書き込み中。
    final useRewardAction = useAsyncAction(context);

    // 詳細カードで選択中の相手(UI改修モック2a-03「逃走者を選んで詳細を見る」)。
    // nullの間は既定で最も近い相手を選ぶ(下のeffectiveSelectedUid参照)。
    // ウィジェット内で完結する一時状態なのでhooksで持つ(AGENTS.md規約)。
    final selectedOpponentUid = useState<String?>(null);

    // 地図/写真一覧タブの選択状態(MapPhotoTabBar⇔PageViewのスワイプ両方から
    // 変わりうる)。GamePageが消えたら一緒に消えてよい一時状態なので
    // hooksで持つ(AGENTS.md規約)。
    final pageIndex = useState(0);
    final pageController = usePageController();

    // 手がかりの見方(ゲーム画面モック04)を、初めてゲーム画面に入ったとき
    // だけ自動で出す。見たかどうかは端末に残す(shared_preferences)。
    // 2回目以降は手がかりカードの「?」からいつでも開ける。
    //
    // 画面遷移をuseEffectの中で同期的に呼ぶと、ビルド中にNavigatorを
    // 触ることになるため、次のフレームに回してからmountedを確かめて開く。
    useEffect(() {
      var disposed = false;
      Future<void> showGuideOnce() async {
        final prefs = ref.read(playerPreferencesRepositoryProvider);
        if (await prefs.loadClueGuideSeen()) return;
        if (disposed || !context.mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (disposed || !context.mounted) return;
          unawaited(prefs.saveClueGuideSeen());
          // 開く時点のルームから自分の役割を引く(このeffectは初回に1度だけ
          // 走るので、buildの時点の値を閉じ込めると古いことがある)。
          final users = ref.read(roomStreamProvider(roomId)).value?.users;
          final viewerRole = users == null
              ? null
              : roleOf(users, ref.read(myUidProvider));
          unawaited(showClueGuide(context, viewerRole: viewerRole));
        });
      }

      unawaited(showGuideOnce());
      return () {
        disposed = true;
      };
    }, const []);

    // 写真タブの「新着」の赤い点。最後に写真タブを開いたときの枚数より
    // 増えていれば出す。画面に入った時点で既にある写真は見たことにする
    // (入るたびに点が付くと、新着の意味が無くなるため)。
    // 画面内で完結する一時状態なのでhooksで持つ(AGENTS.md規約)。
    // 捕まえた瞬間の写真(issue #140)も数に入れる。取り消しの期限を過ぎた
    // 捕獲の写真だけを数える(一覧に出るものと揃える)。
    final photos = photosAsync.value ?? const [];
    final catchesAsync = ref.watch(catchesStreamProvider(roomId));
    final catchPhotosAsync = ref.watch(catchPhotosStreamProvider(roomId));
    final galleryCatchPhotos = catchPhotosForGallery(
      catchPhotos: catchPhotosAsync.value ?? const [],
      catches: catchesAsync.value ?? const [],
      startedAt: room?.startedAt,
      nowMillis: now,
    );
    final galleryPhotoCount = photos.length + galleryCatchPhotos.length;
    // 捕獲の側は読めなくても(エラーでも)数え始める。待ち続けると、
    // 足元の写真の赤い点まで出なくなるため(isSettledForPhotoBadge参照)。
    final photoCountReady =
        photosAsync.hasValue &&
        isSettledForPhotoBadge(catchesAsync) &&
        isSettledForPhotoBadge(catchPhotosAsync);
    final seenPhotoCount = useRef<int?>(null);
    if (photoCountReady) {
      seenPhotoCount.value ??= galleryPhotoCount;
    }
    if (pageIndex.value == 1 && photoCountReady) {
      seenPhotoCount.value = galleryPhotoCount;
    }
    final hasNewPhotos =
        pageIndex.value != 1 &&
        seenPhotoCount.value != null &&
        galleryPhotoCount > seenPhotoCount.value!;

    // 目撃写真(見つけた鬼の写真)の未読の数と、シートを開く操作。地図の
    // ページは写真タブへ移ると破棄されるため、見た数はここ(GamePage本体)で
    // 持つ。中身はsighting_photo_button.dartにある。
    final sightingBadge = useSightingBadge(
      context,
      ref,
      roomId: roomId,
      startedAt: room?.startedAt,
      myUid: myUid,
    );

    // デバッグ用の偽プレイヤーを出しているかどうか(issue #67)。多人数での
    // 見え方は端末を人数分集めないと確認できないため、デバッグビルドでだけ
    // AppBarに出るボタンで切り替えられるようにしている。待機画面と同じ
    // 状態を見る(画面をまたいで持ち回りたいのでRiverpod。AGENTS.md規約)。
    final showMocks = kDebugMode && ref.watch(showDebugMockPlayersProvider);

    // ゲーム画面に滞在している間だけ、位置情報・気圧・Wi-Fi・BLEを動かす。
    useGameSession(ref, roomId: roomId, myUid: myUid);

    // 撮影プロンプトのタイマー。鬼の放出(meta/releasedAt)から
    // setting/photoIntervalSecたった時点を1回目とし、以後その間隔ごとの
    // スロットで、今のスロットに撮ったか(users/{uid}/lastPhotoAt)を見る。
    // PHOTO_API_BASE_URL未設定の環境では機能を無効化するだけで、
    // タイマー自体は動かしたままにしても実害は無いためフックは常に呼ぶ
    // (呼び出しを条件分岐するとhooksの呼び出し順が崩れるため)。
    warnIfPhotoFeatureNotConfigured();

    // ミッションのごほうびの効果(effects)。前のゲームの分は除く。残り時間は
    // サーバー時刻(now)で数える。
    final roomEffects = effectsOfCurrentGame(
      ref.watch(effectsStreamProvider(roomId)).value ?? const [],
      startedAt: room?.startedAt,
    );
    final photoIntervalSec = room?.setting.photoIntervalSec ?? 300;
    final myLastPhotoAt = myUid == null
        ? null
        : findUser(room?.users ?? const [], myUid)?.lastPhotoAt;
    // ごほうび「足元写真を1回まぬがれる」で飛ばすスロット。撮影プロンプトと
    // 写真一覧(まぬがれたスロットも撮った扱いにする。issue #157)の両方で使う。
    final skippedPhotoSlots = skippedFootPhotoSlots(
      effects: roomEffects,
      myUid: myUid,
      scheduleStartMillis: photoScheduleStartMillis(
        releasedAt: room?.releasedAt,
        intervalSec: photoIntervalSec,
      ),
      intervalSec: photoIntervalSec,
    );
    final photoCapture = usePhotoCaptureController(
      context,
      roomId: roomId,
      myUid: myUid,
      intervalSec: photoIntervalSec,
      releasedAt: room?.releasedAt,
      serverTimeOffsetMillis: offset,
      lastPhotoAt: myLastPhotoAt,
      // 鬼も逃走者も撮る(issue #140)。
      notifyWhenDue: takesFootPhotos(roleOf(room?.users ?? const [], myUid)),
      skippedSlots: skippedPhotoSlots,
    );

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

      unawaited(loadCached());
      return null;
    }, const []);

    // 捕獲まわり(issue #140)。捕まった本人の役割の書き換えと全画面、
    // 取り消しの期限を過ぎた捕獲の全員への通知、取り消しの鬼への通知。
    final caught = useCaughtByDemon(ref, roomId: roomId, myUid: myUid);
    final undoCatch = useUndoCatch(context, ref, roomId: roomId);
    final announcement = useCatchAnnouncements(
      ref,
      roomId: roomId,
      myUid: myUid,
    );
    useCatchUndoneNotifications(ref, context, roomId: roomId, myUid: myUid);

    // 鬼放出の振動+通知、ゲーム終了の検知、エリア外の判定は GameAlerts
    // (useGameSessionが開始する)が1秒ごとのタイマーで回している。画面が
    // 消えていても進むようにするため、ウィジェットの再描画から切り離した
    // (issue #71)。ここはその結果を受け取って画面に出すだけ。
    useGameOverNavigation(
      ref,
      context,
      roomId: roomId,
      isNavigationBlocked:
          caught.shownCatch != null || captureOpen.value || rewardOpen.value,
    );

    // 「同じメンバーでもう一回」による巻き戻しの検知。ホストが結果画面
    // (GameResultPage)で巻き戻しを実行した瞬間、この端末がまだisGameOver
    // を検知できておらずこのGamePageに留まっている場合がある(バック
    // グラウンド化・ネットワーク遅延等)。その場合でも待機画面に戻れる
    // よう、GameResultPageと同じフックをここでも使う(issue #44)。
    useRestartRecovery(ref, context, roomId: roomId);

    // 誰かが鬼になったらSnackBarで全員に知らせる。
    useDemonChangeNotifications(ref, context, roomId: roomId, myUid: myUid);

    // 鬼のとき、逃走者が写真を撮ったら通知とSnackBarで知らせる(issue #120)。
    usePhotoTakenNotifications(ref, context, roomId: roomId, myUid: myUid);

    // プレイエリア外のアラート(issue #61 / UI改修モック2a-07)。
    //
    // 判定・振動・通知はすべて GameAlerts 側で回っている(issue #71)。画面が
    // 消えている間も検知と解除を続ける必要があり、ウィジェットの再描画に
    // 乗せられないため。ここはその結果を表示に変換するだけ。
    //
    // 以前はここで「本文がdataを描いているか」も条件に混ぜ、RTDBが一瞬
    // こけている間に「バナーが無いのに振動だけ続く」のを防いでいた。いまは
    // GameAlerts側が room を取れないことをそのまま「判定に使える情報が無い」
    // (OutsideAreaStatus.unknown)として扱い、猶予判定が直前の状態を保つので、
    // 画面の状態に依存せず同じ結果になる。
    //
    // 矢印の向きに使う観測だけは、表示のたびに最新の位置から作り直す。
    final myLocation = _findLocation(locationState.locations, myUid);
    final outsideAreaObservation = observeOutsideArea(
      area: room?.setting.gameArea,
      location: myLocation,
      // updatedAtはServerValue.timestampで書かれるのでサーバー時刻で比べる。
      nowMillis: now,
    );
    // 表示と発火の条件を揃える。これ1つで赤帯・地図の赤かぶせ・方向矢印が
    // まとめて出入りする。
    final outsideAreaAlert = outsideAreaAlertOf(
      isWarning: ref.watch(gameAlertsProvider).isOutsideAreaWarning,
      observation: outsideAreaObservation,
    );

    final pressureState = ref.watch(pressureViewModelProvider);
    final bleDetections = ref.watch(bleViewModelProvider);

    // ミッション(逃走者だけが受ける)。いま出ている1件と、自分の進み具合
    // (到着。MissionControllerが画面と無関係に1秒ごとに更新する)。
    final missionProgress = ref.watch(missionControllerProvider);
    final missionBanner = ref.watch(missionBannerProvider);
    final mission = roleOf(room?.users ?? const [], myUid) == UserRole.fugitive
        ? currentMission(
            ref.watch(missionsStreamProvider(roomId)).value ?? const [],
            startedAt: room?.startedAt,
            nowMillis: now,
          )
        : null;
    // 持っていてまだ使っていないごほうび(逃走者だけ。引いた順)。
    final heldRewards =
        roleOf(room?.users ?? const [], myUid) == UserRole.fugitive
        ? heldRewardsOf(
            missions: missionsOfCurrentGame(
              ref.watch(missionsStreamProvider(roomId)).value ?? const [],
              startedAt: room?.startedAt,
            ),
            effects: roomEffects,
            uid: myUid,
          )
        : const <HeldReward>[];
    // 向かう先は、いちばん近い空いている地点(取られたら次に近い地点へ移る)。
    final missionTargetSpot = mission == null
        ? null
        : nearestOpenSpot(mission, myLocation);
    final missionReading = mission == null
        ? null
        : readAccessPoint(spot: missionTargetSpot, location: myLocation);

    // ミッションのお知らせバナーを、出してしばらくしたら小さいアイコンに
    // 畳む(issue #155)。開閉そのものは画面内で完結する一時状態なので
    // hooksで持つ(AGENTS.md規約)。新しいお知らせが来たら(keyが変わったら)
    // 展開し直し、[missionBannerDuration]後にまた畳む。
    final missionBannerCollapsed = useState(false);
    useEffect(() {
      if (missionBanner == null) return null;
      missionBannerCollapsed.value = false;
      final timer = Timer(missionBannerDuration, () {
        missionBannerCollapsed.value = true;
      });
      return timer.cancel;
    }, [missionBanner?.key]);

    // ミッションのカードを折りたたんでいるか(issue #155。地図を隠す
    // 面積を減らす)。これも画面内で完結する一時状態なのでhooksで持つ。
    // 新しいミッションが始まったら開いた状態に戻す。
    final missionCardExpanded = useState(true);
    useEffect(() {
      missionCardExpanded.value = true;
      return null;
    }, [mission?.id]);

    // ごほうびが「足元写真を1回まぬがれる」だったときに飛ばすスロット。押した
    // 瞬間の撮影バナーの状態で決め、効果に書いておく(後から撮り直しても
    // ずれないように)。
    int? footPhotoSkipSlotNow() => footPhotoSlotToSkip(
      scheduleStartMillis: photoScheduleStartMillis(
        releasedAt: room?.releasedAt,
        intervalSec: photoIntervalSec,
      ),
      intervalSec: photoIntervalSec,
      nowMillis: serverNowMillis(offset),
      isDue: photoCapture.state.isDue,
    );

    // ごほうびを引けたら、確定演出(GachaPage)→ ごほうびの画面(RewardPage)の順に
    // 出す。両方が閉じるまでゲーム終了の自動遷移を止める。
    Future<void> showReward(RewardType reward) async {
      rewardOpen.value = true;
      await GachaPage.show(context, reward);
      if (context.mounted) rewardOpen.value = false;
    }

    // 取れたのにごほうびの書き込みが済んでいないとき(取った直後に通信が切れた
    // 等)の「ごほうびを受け取る」。書き込みは何度やっても1つにまとまる。
    Future<void> handleCompleteClaimPressed(
      Mission target,
      MissionSpot spot,
    ) async {
      RewardType? reward;
      final result = await claimAction.run(() async {
        reward = await ref
            .read(missionRepositoryProvider)
            .completeClaim(
              roomId,
              target.id,
              spot.id,
              footPhotoSkipSlot: footPhotoSkipSlotNow(),
            );
      });
      if (!context.mounted) return;
      switch (result.status) {
        case AsyncActionStatus.succeeded:
          if (reward case final granted?) await showReward(granted);
        case AsyncActionStatus.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ごほうびを受け取れませんでした。'
                '${userFacingErrorMessage(result.error!)}',
              ),
            ),
          );
        case AsyncActionStatus.skipped:
          break;
      }
    }

    // 持っているごほうびの「つかう」。効果はこの時刻から効き始める。
    // 2回押しても、効果は1回しか書かれない(useHeldReward)。
    Future<void> handleUseHeldRewardPressed(HeldReward held) async {
      var used = false;
      final result = await useRewardAction.run(() async {
        used = await ref
            .read(missionRepositoryProvider)
            .useHeldReward(roomId, held.missionId, held.spotId);
      });
      if (!context.mounted) return;
      switch (result.status) {
        case AsyncActionStatus.succeeded:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                used ? '「${held.type.title}」を使った' : 'このごほうびはもう使ってある',
              ),
            ),
          );
        case AsyncActionStatus.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ごほうびを使えませんでした。'
                '${userFacingErrorMessage(result.error!)}',
              ),
            ),
          );
        case AsyncActionStatus.skipped:
          break;
      }
    }

    // デバッグ用の「ミッションをいますぐ出す」(DEBUG_MISSION)。何回目を
    // 出すかを選ばせ、時刻やホストかどうかに関係なくその場で書く。
    Future<void> handleDebugCreatePressed(Room current) async {
      final round = await showMissionDebugRoundPicker(context);
      if (round == null || !context.mounted) return;
      var written = false;
      final result = await debugCreateAction.run(() async {
        written = await ref
            .read(missionControllerProvider.notifier)
            .debugCreateMission(round);
      });
      if (!context.mounted) return;
      if (result.status == AsyncActionStatus.skipped) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            written ? '$round回目のミッションを出しました' : 'まだ部屋の情報が届いていないため出せませんでした',
          ),
        ),
      );
    }

    // 「ごほうびガチャを引く」。先着はリポジトリのトランザクションで決まる。
    // [skipRangeCheck]はデバッグ用の「着いたことにする」からだけtrue
    // (距離とGPSの精度の判定だけを飛ばし、トランザクションはふつうに走る)。
    Future<void> handleClaimPressed(
      Mission target,
      MissionSpot spot, {
      bool skipRangeCheck = false,
    }) async {
      // 押した瞬間にも範囲の中にいるかを確かめ直す。一度通っただけで、
      // 離れた場所から引けてしまわないように(canClaimAccessPoint)。
      // ボタンは範囲の外では出ないが、描画から押すまでの間に位置が
      // 更新されていることがあるため、最新の位置でもう一度見る。
      final latest = readAccessPoint(
        spot: spot,
        location: _findLocation(
          ref.read(locationViewModelProvider).locations,
          myUid,
        ),
      );
      final progress = ref.read(missionControllerProvider);
      if (!skipRangeCheck &&
          (progress.spotId != spot.id ||
              !canClaimAccessPoint(
                arrival: progress.arrival,
                reading: latest,
              ))) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '判定範囲の外に出ています。'
              '半径${formatMeters(spot.radiusM)}に戻ってから引いてください',
            ),
          ),
        );
        return;
      }
      ClaimResult? claim;
      final result = await claimAction.run(() async {
        claim = await ref
            .read(missionRepositoryProvider)
            .claimMission(
              roomId,
              target.id,
              spot.id,
              footPhotoSkipSlot: footPhotoSkipSlotNow(),
            );
      });
      if (!context.mounted) return;
      switch (result.status) {
        case AsyncActionStatus.succeeded:
          final outcome = claim;
          if (outcome == null) return;
          switch (outcome.outcome) {
            case ClaimOutcome.claimed:
              final reward = outcome.reward;
              if (reward == null) return;
              await showReward(reward);
            case ClaimOutcome.takenByOther:
              // カードも「ほかの人に取られた」に変わるが、押した直後の
              // 結果なので知らせておく。
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ほかの人に取られた')),
              );
            case ClaimOutcome.unavailable:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('このアクセスポイントはもう取れません')),
              );
          }
        case AsyncActionStatus.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'ごほうびを引けませんでした。'
                '${userFacingErrorMessage(result.error!)}',
              ),
            ),
          );
        case AsyncActionStatus.skipped:
          break;
      }
    }

    // 「捕まえた」の処理(issue #140)。相手と場所を選ぶ→撮影画面で写真を
    // 撮って送る→そこで初めて捕獲を書く。撮らずに戻ったら選択からやり直す
    // (runCatchFlow)。onPressed直下に書くとネストが深くなりすぎるため
    // 独立した関数にしている。
    //
    // 選択シート・撮影画面を開いている間はcaptureOpenを立て、ゲーム終了の
    // 自動遷移を止める。最後の逃走者を捕まえた場合、reportCatchの書き込みは
    // RTDBのローカルリスナーへ即座に流れるため、撮影画面を閉じる前に
    // 結果画面へ飛ばないようにするため(issue #154)。同期的に立てるので
    // 二重押しもここで弾ける。
    Future<void> handleCatchPressed(List<CatchCandidate> candidates) async {
      if (captureOpen.value) return;
      captureOpen.value = true;

      // 捕獲を書き、分析用のイベントログ(鬼のそのときの位置・GPS精度・
      // 気圧)を添える(ログはfire-and-forget)。
      Future<String> reportCatch(CatchTargetChoice choice) async {
        final catchId = await ref
            .read(roomRepositoryProvider)
            .reportCatch(roomId, fugitiveUid: choice.uid);
        if (myUid != null) {
          unawaited(
            ref
                .read(eventLogRepositoryProvider)
                .log(
                  roomId,
                  type: GameEventType.caught,
                  uid: myUid,
                  targetUid: choice.uid,
                  lat: myLocation?.latitude,
                  lng: myLocation?.longitude,
                  accuracy: myLocation?.accuracy,
                  pressure: pressureState.myPressureHPa ?? myLocation?.pressure,
                  indoor: choice.indoor,
                ),
          );
        }
        return catchId;
      }

      Future<bool> capture(CatchTargetChoice choice) async {
        if (!context.mounted) return false;
        // 写真APIが未設定の環境(dart_defines無しの起動)では撮れないため、
        // 写真なしで捕獲を書く。撮影画面を出すと捕まえる手段が無くなる。
        if (!isPhotoFeatureConfigured) {
          try {
            await reportCatch(choice);
            return true;
          } on Object catch (e) {
            debugPrint('[GamePage] 捕獲の送信に失敗: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '「捕まえた」の送信に失敗しました。'
                    '${userFacingErrorMessage(e)}',
                  ),
                ),
              );
            }
            return false;
          }
        }
        final name = candidates
            .firstWhere(
              (c) => c.uid == choice.uid,
              orElse: () => (uid: choice.uid, name: '???'),
            )
            .name;
        final sent = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => CatchCapturePage(
              roomId: roomId,
              fugitiveUid: choice.uid,
              fugitiveName: name,
              onCatch: () => reportCatch(choice),
            ),
          ),
        );
        return sent ?? false;
      }

      try {
        await runCatchFlow(
          chooseTarget: () async {
            if (!context.mounted) return null;
            return showCatchTargetSheet(context, candidates: candidates);
          },
          capture: capture,
        );
      } finally {
        if (context.mounted) captureOpen.value = false;
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
            backgroundColor: gameBackground,
            // 役割文言と残り時間の帯。文字サイズなど見た目の細部は
            // GameHeaderBar側にある(widgetテストを書けるようにするため
            // 切り出している)。
            appBar: GameHeaderBar(
              roleTheme: headerRoleTheme,
              countdownSec: countdownSec,
              // 「?」で使ってよい場所の一覧(issue #108)を開く。手がかりの
              // 見方(モック04)は、手がかりカードの「?」から開ける。
              onHelp: () => unawaited(showAreaRulesDialog(context)),
              // デバッグビルド限定の、偽プレイヤーの表示/非表示トグル
              // (issue #67)。RTDBには一切書かず、この端末の画面にだけ
              // 偽の相手を足す。kDebugModeがfalseのリリースビルドでは
              // このボタン自体が存在しない。
              actions: const [
                if (kDebugMode) DebugMockPlayersToggle(),
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
                if (showMocks && myRole != null) {
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
                final beforeRelease = phase == GamePhase.beforeRelease;

                // BLEで3m以内にいる逃走者(issue #140)。「捕まえた」の帯は
                // これが1人以上のときだけ押せる。BLEの検知時刻
                // (detectedAtMillis)は端末ローカル時計で記録しているため、
                // サーバー時刻(now)ではなく端末ローカル時刻で比べる。
                // 帯自体は鬼なら放出前から出しておき、放出前は押せなくする。
                final showCatchStrip = shouldShowCatchButton(role: myRole);
                final catchWaitingForRelease = !canPressCatchButton(
                  role: myRole,
                  phase: phase,
                );
                final catchCandidates = !catchWaitingForRelease
                    ? [
                        for (final uid in fugitivesWithinCatchRange(
                          detections: bleDetections,
                          users: room.users,
                          myUid: myUid,
                          nowMillis: DateTime.now().millisecondsSinceEpoch,
                        ))
                          (uid: uid, name: catchPersonName(room.users, uid)),
                      ]
                    : const <CatchCandidate>[];

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
                // ごほうび「鬼の手がかりを止める」。効いている間、鬼の端末では
                // Wi-Fi・気圧の表示を隠す。
                final clueBlockedEffect = myRole == UserRole.demon
                    ? activeEffectOf(
                        roomEffects,
                        RewardType.blockClues,
                        serverNowMillis: now,
                      )
                    : null;
                final rosterUids = opponentRoster.map((u) => u.id).toSet();
                // 選択中のuidがまだ一覧に残っていればそれを使い、無ければ
                // (未選択・退室・可視性が外れた等)既定で最も近い相手に戻す。
                // 手がかりを止められている間は「Wi-Fiで最も近い相手」を既定に
                // しない(選ばれるチップで、誰が近いかが漏れるため)。
                final effectiveSelectedUid =
                    selectedOpponentUid.value != null &&
                        rosterUids.contains(selectedOpponentUid.value)
                    ? selectedOpponentUid.value
                    : (clueBlockedEffect == null
                              ? visibleNearestOpponentUid
                              : null) ??
                          (opponentRoster.isEmpty
                              ? null
                              : opponentRoster.first.id);
                final selectedComparisons = effectiveSelectedUid != null
                    ? ref.watch(
                        wifiComparisonsForProvider((
                          roomId,
                          effectiveSelectedUid,
                        )),
                      )
                    : const <WifiApComparison>[];

                // ごほうびの効果(ミッション)。「自分のアイコンを大きくする」は
                // 全員の地図で、引いた人のピンを2倍にする(鬼の手がかりを
                // 止める効果は、相手選びの前で見ている)。
                final enlargedUserUids = activeEnlargeSelfIconUids(
                  roomEffects,
                  serverNowMillis: now,
                );
                // 自分が引いていれば、本人向けの通知に使う。
                final myEnlargeSelfIconEffect = activeEnlargeSelfIconEffectFor(
                  roomEffects,
                  uid: myUid,
                  serverNowMillis: now,
                );
                final missionStatus = mission == null || missionReading == null
                    ? null
                    : missionCardStatusOf(
                        mission: mission,
                        myUid: myUid,
                        locationFailure: locationState.failure,
                        reading: missionReading,
                        progress: missionProgress,
                        targetSpotId: missionTargetSpot?.id,
                      );
                // ごほうびを受け取り直す地点(取ったのにごほうびが無いもの)。
                final myUnrewardedSpot = mission == null
                    ? null
                    : unrewardedSpotClaimedBy(mission, myUid);
                // 最後に取った地点。取り終わったカードに、そのごほうびを出す。
                final myLastClaimedSpot = mission == null
                    ? null
                    : (spotsClaimedBy(mission, myUid).toList()..sort(
                            (a, b) =>
                                (a.claimedAt ?? 0).compareTo(b.claimedAt ?? 0),
                          ))
                          .lastOrNull;
                // 地図の下寄せに「ごほうびガチャを引く/受け取る」が出ているか。
                final showsMissionButton =
                    (missionStatus == MissionCardStatus.arrived &&
                        missionTargetSpot != null) ||
                    (missionStatus == MissionCardStatus.claimedWithoutReward &&
                        myUnrewardedSpot != null &&
                        !claimAction.isRunning);

                final mapPageContent = Column(
                  children: [
                    // 効果が効いているあいだの細い帯(残り時間はサーバー時刻で数える)。
                    for (final effect in activeTimedEffects(
                      roomEffects,
                      serverNowMillis: now,
                    ))
                      EffectBand(
                        type: effect.type,
                        viewerRole: myRole,
                        remainingMillis: effectRemainingMillis(
                          effect,
                          serverNowMillis: now,
                        ),
                        // 誰が引いたかは逃走者にだけ伝える(鬼に伝えると
                        // 居場所の特定につながるため)。
                        drawerName: myRole == UserRole.fugitive
                            ? findUser(room.users, effect.byUid)?.displayName
                            : null,
                      ),
                    // 「自分のアイコンを大きくする」は本人にだけ出す
                    // 個人向けの帯(他の帯と違い全員共通では出さない)。
                    if (myEnlargeSelfIconEffect != null)
                      EffectBand(
                        type: RewardType.enlargeSelfIcon,
                        viewerRole: myRole,
                        remainingMillis: effectRemainingMillis(
                          myEnlargeSelfIconEffect,
                          serverNowMillis: now,
                        ),
                      ),
                    // 持っているごほうび(先に引いたものから1つずつ出す)。
                    // 同じ効果がいま効いているあいだは押せない(重ねても
                    // 長くならず、無駄になるため)。
                    if (heldRewards.firstOrNull case final held?)
                      HeldRewardBar(
                        type: held.type,
                        onUse:
                            useRewardAction.isRunning ||
                                activeEffectOf(
                                      roomEffects,
                                      held.type,
                                      serverNowMillis: now,
                                    ) !=
                                    null
                            ? null
                            : () => unawaited(handleUseHeldRewardPressed(held)),
                        disabledReason: useRewardAction.isRunning
                            ? '使っています…'
                            : 'いま効いているので、切れてから使える',
                      ),
                    // 鬼放出前、逃走者に「いまのうちに離れる」ことを促す
                    // バナー(UI改修モック2a-04)。鬼にはこの助言は無関係
                    // なので逃走者のみに出す。
                    if (myRole == UserRole.fugitive &&
                        phase == GamePhase.beforeRelease)
                      PreReleaseBanner(countdownSec: countdownSec),
                    // 撮影プロンプト。間隔が来た、またはアップロード失敗で
                    // 再送待ちの画像がある間だけ出す(PHOTO_API_BASE_URL
                    // 未設定の環境では機能ごと隠す)。鬼も逃走者も撮る
                    // (issue #140。photo_gallery_page.dartのshowBannerと
                    // 同じ判定)。
                    if (isPhotoFeatureConfigured &&
                        takesFootPhotos(myRole) &&
                        (photoCapture.state.isDue ||
                            photoCapture.state.pendingBytes != null))
                      PhotoCaptureBanner(
                        state: photoCapture.state,
                        onCapture: () {
                          unawaited(photoCapture.capture());
                        },
                        onResend: () {
                          unawaited(photoCapture.resend());
                        },
                      ),
                    // 位置が送れていないときの警告。原因によって直し方が
                    // 違う(設定で許可する/入り直す)ため文言を出し分ける。
                    if (locationWarningMessage(locationState)
                        case final message?)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          message,
                          style: const TextStyle(color: Color(0xFFE5484D)),
                        ),
                      ),
                    // エリア外アラート(赤帯・赤かぶせ・矢印・戻り方カード)は
                    // 地図の上に重ねる。Columnに足すと、その分だけ地図と
                    // 下のカードが押し出されて画面外へ消えるため
                    // (OutsideAreaAlertMapのコメント参照)。
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: OutsideAreaAlertMap(
                              alert: outsideAreaAlert,
                              // 偽プレイヤーのピンにも名前と役割色を出すため、
                              // 地図には表示用の一覧を渡す(issue #67)。
                              // ミッションのカードと「ごほうびガチャを引く」は地図の上に重ねる。
                              // エリア外アラートはさらにその上に出る(戻る方が優先)。
                              map: Stack(
                                children: [
                                  Positioned.fill(
                                    child: GameLocationMap(
                                      locations: visibleLocations,
                                      users: displayUsers,
                                      myUid: myUid,
                                      cachedPosition: cachedPosition.value,
                                      gameArea: room.setting.gameArea,
                                      enlargedUserUids: enlargedUserUids,
                                      // 地図に出し続ける地点を[visibleMissionSpots]
                                      // に任せる(issue #155。自分が取った
                                      // 地点を除き、ミッションが終わったら
                                      // 何も残さない判定はmission_rules.dart
                                      // 側の純粋関数でテストする)。
                                      missionPoints: [
                                        if (mission != null)
                                          for (final spot
                                              in visibleMissionSpots(
                                                mission,
                                                myUid: myUid,
                                              ))
                                            (
                                              lat: spot.lat,
                                              lng: spot.lng,
                                              radiusM: spot.radiusM,
                                              claimed: spot.claimedBy != null,
                                            ),
                                      ],
                                    ),
                                  ),
                                  if (mission != null &&
                                      missionReading != null &&
                                      missionStatus != null) ...[
                                    Positioned(
                                      left: 12,
                                      right: 12,
                                      top: 12,
                                      child: MissionCard(
                                        mission: mission,
                                        status: missionStatus,
                                        reading: missionReading,
                                        remainingMillis:
                                            mission.expiresAt - now,
                                        expanded: missionCardExpanded.value,
                                        onToggleExpanded: () =>
                                            missionCardExpanded.value =
                                                !missionCardExpanded.value,
                                        myReward: myLastClaimedSpot?.reward,
                                      ),
                                    ),
                                    if (missionStatus ==
                                            MissionCardStatus.arrived &&
                                        missionTargetSpot != null)
                                      Positioned(
                                        left: 12,
                                        right: 12,
                                        bottom: 14,
                                        child: MissionClaimButton(
                                          isClaiming: claimAction.isRunning,
                                          onPressed: () => unawaited(
                                            handleClaimPressed(
                                              mission,
                                              missionTargetSpot,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (missionStatus ==
                                            MissionCardStatus
                                                .claimedWithoutReward &&
                                        myUnrewardedSpot != null &&
                                        !claimAction.isRunning)
                                      Positioned(
                                        left: 12,
                                        right: 12,
                                        bottom: 14,
                                        child: MissionClaimButton(
                                          label: 'ごほうびを受け取る',
                                          isClaiming: false,
                                          onPressed: () => unawaited(
                                            handleCompleteClaimPressed(
                                              mission,
                                              myUnrewardedSpot,
                                            ),
                                          ),
                                        ),
                                      ),
                                    // デバッグ用(DEBUG_MISSION=trueのときだけ)。
                                    // 距離の判定を飛ばして、いちばん近い空いている
                                    // 地点(位置が無ければ最初の空き)を取りに行く。
                                    if (debugMissionArrivalEnabled &&
                                        missionStatus !=
                                            MissionCardStatus.takenByOther &&
                                        missionStatus !=
                                            MissionCardStatus.claimedByMe &&
                                        myUnrewardedSpot == null)
                                      if (missionTargetSpot ??
                                              openSpots(mission).firstOrNull
                                          case final debugSpot?)
                                        Positioned(
                                          left: 12,
                                          right: 12,
                                          bottom: 80,
                                          child: MissionDebugArrivalButton(
                                            onPressed: claimAction.isRunning
                                                ? null
                                                : () => unawaited(
                                                    handleClaimPressed(
                                                      mission,
                                                      debugSpot,
                                                      skipRangeCheck: true,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                  ],
                                  // デバッグ用(DEBUG_MISSION=trueのときだけ)。
                                  // ミッションが出ていなければ、カードの位置に
                                  // 「ミッションをいますぐ出す」を置く(放出から
                                  // 3分待たずに、回を選んで出せる)。
                                  if (debugMissionArrivalEnabled &&
                                      mission == null &&
                                      room.startedAt != null)
                                    Positioned(
                                      left: 12,
                                      right: 12,
                                      top: 12,
                                      child: MissionDebugCreateButton(
                                        onPressed: debugCreateAction.isRunning
                                            ? null
                                            : () => unawaited(
                                                handleDebugCreatePressed(room),
                                              ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // 目撃写真のボタン(地図の右下)。地図の帰属表示
                          // (右下の「i」)を隠さないよう、その上に置く。
                          // 「ごほうびガチャを引く」が出ている間は、そのボタンに
                          // 重ならないようさらに上へずらす。
                          // 写真機能が無効な環境と、鬼には出さない。
                          if (isPhotoFeatureConfigured &&
                              shouldShowSightingPhotoButton(role: myRole))
                            Positioned(
                              right: 14,
                              bottom: showsMissionButton ? 120 : 60,
                              child: SightingPhotoButton(
                                unreadCount: sightingBadge.unreadCount,
                                onPressed: () =>
                                    unawaited(sightingBadge.openSheet()),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // マップの下は、対象役割の相手をタップで選べるチップ一覧と、
                    // 選んだ1人だけの手がかりカード(モック01/02)。人数が
                    // 増えても見やすいよう、対象を常に1人だけに絞る
                    // (issue #29フォローアップ)。
                    //
                    // チップ一覧が出せないときは、その理由を明示するカードに
                    // 差し替える。「可視性ディレイでまだ見えない」「対象役割
                    // の相手がそもそも居ない」「居るがまだ検知できていない」
                    // の3つは、以前は一律「検知なし」と出していて区別が付か
                    // なかった(issue #30)。
                    //
                    // 差し替えや手がかりカードの状態(C1〜C5)で高さが変わる
                    // ため、AnimatedSizeで地図の伸び縮みを滑らかにする。
                    // 差し替え時の段差そのものはHiddenOpponentCardの最低の
                    // 高さで小さくしてある(issue #29フォローアップ)。
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child:
                          opponentRoster.isEmpty || effectiveSelectedUid == null
                          ? Padding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                beforeRelease ? 12 : 10,
                                16,
                                0,
                              ),
                              child: Column(
                                children: [
                                  HiddenOpponentCard(
                                    message: emptyOpponentMessage(
                                      // 役割がまだ確定していない間の扱いは
                                      // opponentRoleの既定と揃える(鬼と確定するまで
                                      // 逃走者側として扱う)。
                                      viewerRole: myRole ?? UserRole.fugitive,
                                      opponentCountInRoom: room.users
                                          .where((u) => u.role == opponentRole)
                                          .length,
                                      hiddenByVisibility:
                                          anyOpponentHiddenFromMe,
                                      beforeRelease: beforeRelease,
                                      revealRemainingSec:
                                          opponentRevealRemainingSec(
                                            viewerRole:
                                                myRole ?? UserRole.fugitive,
                                            releasedAt: room.releasedAt,
                                            fugitiveInfoDelaySec: room
                                                .setting
                                                .fugitiveInfoDelaySec,
                                            nowMillis: now,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: Column(
                                children: [
                                  OpponentSelectorChips(
                                    roster: opponentRoster,
                                    // 手がかりを止められている鬼には、Wi-Fiの
                                    // 判定もチップに出さない。
                                    entries: clueBlockedEffect != null
                                        ? const []
                                        : visibleWifiEntries,
                                    selectedUid: effectiveSelectedUid,
                                    onSelect: (uid) =>
                                        selectedOpponentUid.value = uid,
                                    leadingLabel:
                                        opponentRole == UserRole.fugitive
                                        ? '逃走者\nを選ぶ'
                                        : '鬼を選ぶ',
                                  ),
                                  const SizedBox(height: 8),
                                  if (clueBlockedEffect != null)
                                    ClueBlockedCard(
                                      remainingMillis: effectRemainingMillis(
                                        clueBlockedEffect,
                                        serverNowMillis: now,
                                      ),
                                    )
                                  else ...[
                                    _SelectedClueCard(
                                      roomId: roomId,
                                      room: room,
                                      myUid: myUid,
                                      uid: effectiveSelectedUid,
                                      users: displayUsers,
                                      wifiEntries: visibleWifiEntries,
                                      verticalPositions:
                                          visibleVerticalPositions,
                                      comparisons: selectedComparisons,
                                      pressureState: pressureState,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );

                // 地図↔写真一覧の切り替え(issue #107)。地図ページ自体は
                // 上のmapPageContentのまま変更せず、PageViewのもう一方の
                // ページとしてPhotoGalleryPageを足す(photo_gallery_page.dart
                // の設計コメント参照)。タブのタップとスワイプの両方で
                // pageIndexとpageControllerを揃える。
                return Column(
                  children: [
                    MapPhotoTabBar(
                      selectedIndex: pageIndex.value,
                      hasNewPhotos: hasNewPhotos,
                      onSelect: (index) {
                        pageIndex.value = index;
                        pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                    // 鬼だけに出す「捕まえた」の帯(issue #140)。地図と写真の
                    // どちらのタブでも押せるよう、タブの直下に置く。常に出し、
                    // 3m以内に逃走者がいない間はdisabledにする(出し入れすると
                    // レイアウトがガタつくため)。
                    if (showCatchStrip)
                      CatchButtonStrip(
                        nearestName: catchCandidates.firstOrNull?.name,
                        inRangeCount: catchCandidates.length,
                        isSubmitting: captureOpen.value,
                        waitingForRelease: catchWaitingForRelease,
                        onPressed: () =>
                            unawaited(handleCatchPressed(catchCandidates)),
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          PageView(
                            controller: pageController,
                            onPageChanged: (index) => pageIndex.value = index,
                            children: [
                              mapPageContent,
                              PhotoGalleryPage(
                                roomId: roomId,
                                room: room,
                                myUid: myUid,
                                photos: photos,
                                catchPhotos: galleryCatchPhotos,
                                nowMillis: now,
                                photoCapture: photoCapture,
                                skippedSlots: skippedPhotoSlots,
                              ),
                            ],
                          ),
                          // ミッションのお知らせ(逃走者だけ・アプリを開いて
                          // いるとき)。出してしばらくすると小さいアイコンに
                          // 畳む(issue #155)。展開したバナーをタップすると
                          // 地図のミッションのカードへ、畳んだアイコンを
                          // タップすると展開し直すだけ(Riverpod側は触らない)。
                          if (missionBanner case final notice?)
                            Positioned(
                              left: 12,
                              right: 12,
                              top: 8,
                              child: missionBannerCollapsed.value
                                  ? MissionNoticeIcon(
                                      onTap: () =>
                                          missionBannerCollapsed.value = false,
                                    )
                                  : MissionNoticeBanner(
                                      notice: notice,
                                      onTap: () {
                                        ref
                                            .read(
                                              missionBannerProvider.notifier,
                                            )
                                            .dismiss();
                                        pageIndex.value = 0;
                                        pageController.animateToPage(
                                          0,
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                                      // 右へスライドしたら、地図へは移らず
                                      // お知らせだけ片付ける。
                                      onDismissed: () => ref
                                          .read(missionBannerProvider.notifier)
                                          .dismiss(),
                                    ),
                            ),
                          // 取り消しの期限を過ぎた捕獲の全員への知らせ
                          // (issue #140)。地図の上に重ね、タップで写真タブを開く。
                          if (announcement.announced case final announced?)
                            Positioned(
                              left: 12,
                              right: 12,
                              top: 8,
                              child: CatchAnnouncementCard(
                                roomId: roomId,
                                message: catchAnnouncementText(
                                  room.users,
                                  announced,
                                  myUid,
                                ),
                                remainingFugitives: remainingFugitiveCount(
                                  room.users,
                                ),
                                photoId: (catchPhotosAsync.value ?? const [])
                                    .where((p) => p.catchId == announced.id)
                                    .firstOrNull
                                    ?.id,
                                onTap: () {
                                  announcement.dismiss();
                                  pageIndex.value = 1;
                                  pageController.animateToPage(
                                    1,
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => RoomStreamErrorView(roomId: roomId, error: e),
            ),
          ),
          // 鬼に捕まった本人の「あなたは鬼になった」(issue #140)。
          // 取り消されると捕獲が消えてshownCatchがnullになり、一緒に消える。
          if (caught.shownCatch case final shown? when room != null)
            Positioned.fill(
              child: CaughtByDemonOverlay(
                roomId: roomId,
                roomCatch: shown,
                demonName: catchPersonName(room.users, shown.demonUserId),
                canUndo: roleOf(room.users, myUid) == UserRole.demon,
                isUndoing: undoCatch.isRunning,
                onUndo: () => unawaited(undoCatch.run(shown)),
                onContinue: caught.dismiss,
              ),
            ),
        ],
      ),
    );
  }
}

/// [locations]から指定uidの位置を探す。uidがnull、またはまだ届いていなければnull。
///
/// GameLocationMapにも同名の非公開ヘルパーがあるが、あちらは地図の
/// 初期センターを決めるためのもの。こちらはエリア外判定に使う自分の位置を
/// 取るためのもので、使う場所も寿命も違うため共有していない。
UserLocation? _findLocation(List<UserLocation> locations, String? uid) {
  if (uid == null) return null;
  for (final location in locations) {
    if (location.uid == uid) return location;
  }
  return null;
}

/// 選んだ相手1人ぶんの手がかりカード(モックC1〜C5)。
///
/// メーターの傾向(近づいた/離れた)には過去の値が要るため、履歴を持つ
/// [ClueTrendScope]で包む。GamePage本体ではルームのデータを受け取った
/// 後でしか相手が決まらず、そこではhooksを呼べないため切り出している。
class _SelectedClueCard extends ConsumerWidget {
  const _SelectedClueCard({
    required this.roomId,
    required this.room,
    required this.myUid,
    required this.uid,
    required this.users,
    required this.wifiEntries,
    required this.verticalPositions,
    required this.comparisons,
    required this.pressureState,
  });

  final String roomId;
  final Room room;
  final String? myUid;
  final String uid;
  final List<RoomUser> users;
  final List<WifiProximityEntry> wifiEntries;
  final List<RelativeVerticalPosition> verticalPositions;
  final List<WifiApComparison> comparisons;
  final PressureState pressureState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 偽プレイヤー(issue #67)にはスキャン結果が無いので、メーターはnull
    // (=「まだ分からない」)になる。
    final meter = ref.watch(clueMeterForProvider((roomId, uid)));
    final vertical = verticalFor(verticalPositions, uid);

    // 途中からの高さ合わせ。条件は待機画面のキャリブレーションと同じ
    // (ホストが先に基準を取っていないと参加者は合わせられない)。
    final isHost = room.hostUserId == myUid;
    final canCalibrate =
        pressureState.sensorAvailability !=
            PressureSensorAvailability.checking &&
        pressureState.myPressureHPa != null &&
        !pressureState.isCalibrating &&
        (isHost || room.basePressure != null);

    return ClueTrendScope(
      uid: uid,
      meter: meter,
      builder: (context, trend) => ClueCard(
        name: findUser(users, uid)?.displayName ?? '',
        role: roleOf(users, uid),
        viewerRole: roleOf(users, myUid),
        verdict: clueVerdictOf(level: levelFor(wifiEntries, uid), meter: meter),
        meter: meter,
        matchCount: countMatchingSignals(comparisons),
        trend: trend,
        heightStatus: clueHeightStatusOf(
          availability: pressureState.sensorAvailability,
          isCalibrated: isCalibrated(room, myUid),
          hasOpponentHeight: vertical != null,
        ),
        opponentLowerHPa: vertical == null
            ? null
            : opponentLowerPressureHPaOf(vertical.deltaMeters),
        onHelp: () => unawaited(
          showClueGuide(context, viewerRole: roleOf(users, myUid)),
        ),
        onCalibrate: canCalibrate
            ? () {
                final notifier = ref.read(pressureViewModelProvider.notifier);
                if (isHost) {
                  unawaited(notifier.calibrateAsHost(roomId));
                } else {
                  unawaited(
                    notifier.calibrateAsParticipant(roomId, room.basePressure),
                  );
                }
              }
            : null,
        isCalibrating: pressureState.isCalibrating,
      ),
    );
  }
}
