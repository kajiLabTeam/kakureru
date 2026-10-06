import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/core/utils/avatar_initial.dart';
import 'package:kakureru/features/pressure/model/calibration_failure.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/room/async_action.dart';
import 'package:kakureru/features/room/calibration_status.dart';
import 'package:kakureru/features/room/debug_mock_players.dart';
import 'package:kakureru/features/room/error_message.dart';
import 'package:kakureru/features/room/left_user_notifications.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/role_visibility.dart';
import 'package:kakureru/features/room/single_flight_action.dart';
import 'package:kakureru/features/room/view/game/area_rules_button.dart';
import 'package:kakureru/features/room/view/game/debug_mock_players_toggle.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';
import 'package:kakureru/features/room/view/game/game_tone_theme.dart';
import 'package:kakureru/features/room/view/game_page.dart';
import 'package:kakureru/features/room/view/room_setting_page.dart';
import 'package:kakureru/features/room/view/room_stream_error.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:kakureru/features/wifi/model/wifi_scan_status.dart';
import 'package:kakureru/features/wifi/view_model/wifi_view_model.dart';

const _demonColor = Color(0xFFE5484D);
const _doneColor = Color(0xFF3A8A4A);
// 未完了・要対応の注意色。ゲーム画面のお知らせ(からし色)に揃える。
const _pendingColor = gameNoticeAccent;

class RoomWaitingPage extends HookConsumerWidget {
  final String roomId;
  const RoomWaitingPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final pressureState = ref.watch(pressureViewModelProvider);
    final startGame = useAsyncAction(context);
    final randomNomination = useAsyncAction(context);
    final hasNavigated = useState(false);
    // 「鬼にする」「取り消す」の送信中フラグ。同時に1件までしか実行しない
    // ため、実行中の対象uidだけを持てば足りる。ここだけuseAsyncActionに
    // 寄せていないのは、どの参加者の行を送信中にするかという「キー付き」
    // の状態が要るため(汎用フック側に持たせると、この1箇所のために
    // 他の4箇所が使わない引数を抱えることになる)。SingleFlightActionは
    // リビルドを待たずに同期で多重発火を防ぐためのガード
    // (ランダム指名ボタンと同じ理由。上のコメント参照)。
    final demonActionUid = useState<String?>(null);
    final demonActionError = useState<Object?>(null);
    final demonActionGuard = useMemoized(SingleFlightAction.new);
    final myUid = ref.watch(myUidProvider);
    final roomRepo = ref.read(roomRepositoryProvider);
    // GPSのみモード(A/Bテスト)。気圧とWi-Fiに関わる処理・表示を丸ごと外す。
    // 気圧センサーの購読(下のuseEffect)はgpsOnlyでは外さない。gpsOnlyで
    // 作り直すと後始末のreleaseがビルド中に状態を書き換えて落ちる。待機画面
    // での購読は手元の表示用で、RTDBへの送信はゲーム画面側(useGameSession)
    // がgpsOnlyで止めている。
    final gpsOnly = roomAsync.value?.setting.gpsOnly ?? false;

    Future<void> runDemonAction(
      String uid,
      Future<void> Function() action,
    ) async {
      await demonActionGuard.run(() async {
        demonActionUid.value = uid;
        demonActionError.value = null;
        try {
          await action();
        } on Object catch (e) {
          // 画面にはuserFacingErrorMessageの1文しか出さないため、原因を追える
          // のはこのログだけになる(useAsyncActionと同じ方針。issue #95)。
          debugPrint('[RoomWaitingPage] 鬼の指名/取り消しに失敗: $e');
          demonActionError.value = e;
        } finally {
          demonActionUid.value = null;
        }
      });
    }

    useEffect(() {
      final pressureNotifier = ref.read(pressureViewModelProvider.notifier);
      unawaited(pressureNotifier.init(roomId));
      // 前のルームで出たキャリブレーションの失敗表示を持ち越さない
      // (providerは画面をまたいで生き続ける)。ビルド中は状態を書き換え
      // られないので、このフレームが確定してから消す。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        pressureNotifier.clearCalibrationFailure();
      });
      // 画面を離れたら気圧の利用を返す。ゲーム画面と一瞬重なる遷移中も、
      // 最後に離れた画面でだけセンサーが止まる(PressureViewModel.release)。
      // 後始末でrefに触れないよう、生きているうちに掴んだnotifierを使う。
      return pressureNotifier.release;
    }, const []);

    // Wi-Fiスキャンが実際に通るかを画面を開いたときに1回だけ確かめる
    // (issue #98)。位置情報のON/OFFや権限、開発者オプションのスロットル
    // 解除は端末の設定側で変わるため、画面から検知する術がない。設定を
    // 直して戻ってきた人のために、表示側に「再確認」を置いてある。
    //
    // useEffectはビルド直後に同期実行され、refresh()は最初に状態を
    // 「確認中」へ書き換えるため、そのまま呼ぶと「ビルド中にproviderを
    // 書き換えた」エラーになる。このフレームが確定してから走らせる。
    useEffect(() {
      if (gpsOnly) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        unawaited(ref.read(wifiScanStatusProvider.notifier).refresh());
      });
      return null;
    }, [gpsOnly]);

    // ref.listenではなくuseEffect(roomAsync.value依存)にしているのは、
    // 既にゲームが進行中(room.status == playing)のルームに、コード入力
    // だけで新規参加してこのページに新規マウントされるケースがあるため
    // (joinRoomは終了済みのルームだけを弾き、進行中への途中参加は許可する)。最初のスナップショット
    // の時点で既にplayingだと、ref.listenは登録後の「変化」にしか反応しない
    // ので、GamePageへの遷移も鬼指名の自動受諾も発火しなかった(待機画面の
    // まま止まってしまう不具合の原因)。useEffectなら初回到達分の評価も
    // 行われる。
    useEffect(() {
      final room = roomAsync.value;
      if (room == null) return null;

      if (room.status == RoomStatus.playing && !hasNavigated.value) {
        hasNavigated.value = true;
        // useEffectはref.watchによるリビルドと同じフレーム内・ビルド直後に
        // 同期実行されるため、ここで即座にNavigatorを操作すると
        // 「ビルド中にNavigator操作をした」という一瞬のエラー画面が出る
        // (最終的には遷移自体は成功するが、ちらつきが起きる)。
        // addPostFrameCallbackでこのフレームの確定後まで遅延させる。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.of(
            context,
          ).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => GamePage(roomId: roomId)),
          );
        });
        return null;
      }

      // 自分が鬼に指名されたら、自分でroleを更新して受諾する
      // (docs/rtdb-schema.mdの「鬼の決定」参照。ホストは他人のroleを
      // 直接書けないため、指名された本人が自分で書く方式)。
      final myself = myUid == null ? null : _findUser(room.users, myUid);
      if (room.pendingDemonUid == myUid && myself?.role != UserRole.demon) {
        unawaited(
          ref
              .read(roomRepositoryProvider)
              .acceptDemonNomination(roomId, myUid!),
        );
      }

      // ホストが既に鬼になっている自分の指名を取り消したら、自分でroleを
      // 逃走者に書き戻して受諾する(上と同じ自己申告方式。
      // docs/rtdb-schema.mdの「鬼の取り消し」参照)。
      if (room.demonRevokeUid == myUid && myself?.role == UserRole.demon) {
        unawaited(
          ref.read(roomRepositoryProvider).acceptDemonRevoke(roomId, myUid!),
        );
      }
      return null;
    }, [roomAsync.value]);

    // 誰かが離脱したら「(名前)さんが抜けました」で明示的に知らせる(issue #11)。
    useLeftUserNotifications(ref, context, roomId);

    // 以前はPopScope.onPopInvokedWithResultのdidPopで判定していたが、
    // GamePage側でWithForegroundTaskのWillPopScopeと競合してdidPopの
    // 解釈が信頼できなくなる不具合があったため、ウィジェットが実際に
    // 破棄されるタイミング(dispose)で判定する方式に統一した。ゲーム開始に
    // 伴うGamePageへのpushReplacementでもこのウィジェットは破棄されるが、
    // それは離脱ではないのでhasNavigatedで区別する。
    useEffect(() {
      return () {
        if (!hasNavigated.value) {
          // 破棄中(unmount中)はrefがもう使えず、ここでref.readすると
          // StateErrorになってleaveRoomが呼ばれないままになる
          // (widgetテストで発覚)。build時に取得しておいたroomRepoを使う。
          unawaited(roomRepo.leaveRoom(roomId));
        }
      };
    }, const []);

    // ホーム・設定・ゲーム画面と同じトーン(生成りの地・白い行・丸い黒ボタン)。
    return Theme(
      data: buildGameToneTheme(Theme.of(context)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('待機中'),
          // 1つめはデバッグ用の偽プレイヤーを足すトグル(issue #67)。実機1台
          // では参加者が自分だけで開始条件を満たせず、ゲーム画面まで到達
          // できないため。kDebugModeがfalseのリリースビルドではこのボタン
          // 自体が存在しない。
          // 2つめは使ってよい場所の一覧(issue #108)。こちらはリリース
          // ビルドでも常に出る。
          actions: const [
            if (kDebugMode) DebugMockPlayersToggle(),
            AreaRulesButton(),
          ],
        ),
        body: roomAsync.when(
          data: (room) {
            final isHost = room.hostUserId == myUid;
            final hostCalibrated = room.basePressure != null;

            // デバッグ用の偽プレイヤー(issue #67)。実機1台では参加者が自分
            // だけになり、開始条件(鬼と逃走者が1人以上ずつ)を満たせず
            // ゲーム画面まで到達できないため、1台でも通せるようにする。
            //
            // **一覧への表示だけに使う**。人数・役割・キャリブレーションの
            // 判定や、RTDBへ書き込むボタン(鬼の指名・取り消し)は、すべて
            // RTDB由来のroom.usersのまま見る。判定側にまで混ぜると、複数人
            // でプレー中に押したときに「鬼0人のまま開始できる」「全員鬼で
            // 開始して全員が即結果画面へ飛ばされる」といった事故になる。
            // 開始条件の迂回だけは下のmockBypassStartで明示的に行う。
            final showMocks =
                kDebugMode && ref.watch(showDebugMockPlayersProvider);
            final displayUsers = showMocks
                ? [...room.users, ...debugMockWaitingUsers()]
                : room.users;

            final demonCandidates = room.users
                .where((u) => u.role != UserRole.demon)
                .toList();
            final demonCount = room.users
                .where((u) => u.role == UserRole.demon)
                .length;
            // 1台で通すための迂回。開始条件そのものは本物の参加者で判定し、
            // デバッグ時だけ明示的に上書きする(どこで緩めているかを1箇所に
            // 集めるため)。
            final canStartWithRoleComposition =
                hasStartableRoleComposition(
                  demonCount: demonCount,
                  totalUserCount: room.users.length,
                ) ||
                showMocks;

            final calibrationStatuses = {
              for (final u in room.users)
                u.id: calibrationStatusFor(
                  isHost: u.id == room.hostUserId,
                  sensorAvailable: u.pressureSensorAvailable,
                  basePressure: room.basePressure,
                  pressureOffset: u.pressureOffset,
                ),
            };
            final requiredCount = calibrationStatuses.values
                .where((s) => s != CalibrationStatus.unavailable)
                .length;
            final doneCount = calibrationStatuses.values
                .where((s) => s == CalibrationStatus.done)
                .length;
            // GPSのみモードは気圧を使わないので、キャリブレーションを待たない。
            final allCalibrated =
                room.setting.gpsOnly ||
                isCalibrationComplete(calibrationStatuses.values);
            final pendingNames = room.setting.gpsOnly
                ? const <String>[]
                : room.users
                      .where(
                        (u) =>
                            calibrationStatuses[u.id] ==
                            CalibrationStatus.pending,
                      )
                      .map((u) => u.displayName)
                      .toList();
            final myCalibrated =
                myUid != null &&
                calibrationStatuses[myUid] == CalibrationStatus.done;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Row(
                    children: [
                      const Text(
                        'ルームコード',
                        style: TextStyle(
                          color: gameMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: gameInk, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          room.roomCode,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isHost && room.status == RoomStatus.waiting)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.settings),
                      label: const Text('設定'),
                      onPressed: () =>
                          Navigator.of(
                            context,
                          ).push(
                            MaterialPageRoute<void>(
                              builder: (_) => RoomSettingPage(roomId: roomId),
                            ),
                          ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        // 偽プレイヤーは本物と分けて数える。混ぜて数えると
                        // トグルを入れたままの部屋を「6人集まっている」と
                        // 読み違える。
                        showMocks
                            ? '参加者 ${room.users.length}人 '
                                  '(+ デバッグ$debugMockPlayerCount人)'
                            : '参加者 ${room.users.length}人',
                        style: const TextStyle(color: gameMuted, fontSize: 12),
                      ),
                      if (requiredCount > 0)
                        Text(
                          'キャリブレーション $doneCount/$requiredCount人 完了',
                          style: TextStyle(
                            color: doneCount == requiredCount
                                ? _doneColor
                                : _pendingColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                if (room.setting.gpsOnly)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                    child: Text(
                      'GPSのみモード(Wi-Fiと気圧は使いません)',
                      style: TextStyle(
                        color: gameMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                    child: _WifiScanStatusRow(),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 2,
                  ),
                  child: _TetheringRow(
                    roomId: roomId,
                    usesTethering: room.users.any(
                      (u) => u.id == myUid && u.isTethering,
                    ),
                  ),
                ),
                if (isHost)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        onPressed:
                            randomNomination.isRunning ||
                                room.pendingDemonUid != null ||
                                demonCandidates.isEmpty
                            ? null
                            : () {
                                // 連打対策: RTDBへの反映(room.pendingDemonUidの更新)には
                                // ネットワーク往復の遅延があり、その間はボタンがまだ有効な
                                // ままなので、useAsyncActionが内側で持つ
                                // SingleFlightActionで同一フレーム内の連打も含めて
                                // 多重発火を防ぐ。
                                unawaited(
                                  randomNomination.run(() {
                                    final target =
                                        demonCandidates[Random().nextInt(
                                          demonCandidates.length,
                                        )];
                                    return ref
                                        .read(roomRepositoryProvider)
                                        .nominateDemon(roomId, target.id);
                                  }),
                                );
                              },
                        child: const Text('鬼をランダムで決める'),
                      ),
                    ),
                  ),
                if (demonActionError.value != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      userFacingErrorMessage(demonActionError.value!),
                      style: const TextStyle(
                        color: gameNewBadge,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    children: displayUsers.map((u) {
                      // showMocksで短絡させる。無条件に呼ぶと、リリース
                      // ビルドでも判定と偽プレイヤーのuid一覧が参照され、
                      // 「偽プレイヤーのコードを配布物に含めない」という
                      // 前提が崩れる。1行に1回だけ計算して使い回す。
                      final isMock = showMocks && isDebugMockPlayer(u.id);
                      // calibrationStatusesはroom.usersだけで作っているので、
                      // 偽プレイヤーは既定のpendingに落ちる。センサー非対応
                      // (pressureSensorAvailable: false)として作っているのに
                      // 未完了アイコンが出てしまうため、ここで補う。
                      final status = room.setting.gpsOnly
                          // 気圧を使わないので、未完了の強調を出さない。
                          ? CalibrationStatus.unavailable
                          : calibrationStatuses[u.id] ??
                                (isMock
                                    ? CalibrationStatus.unavailable
                                    : CalibrationStatus.pending);
                      final isPending =
                          room.pendingDemonUid == u.id &&
                          u.role != UserRole.demon;
                      final avatarColor = u.role == UserRole.demon
                          ? _demonColor
                          : _doneColor;
                      final borderColor = u.role == UserRole.demon
                          ? _demonColor
                          : status == CalibrationStatus.pending
                          ? _pendingColor
                          : gameBorder;
                      final subtitleColor = u.role == UserRole.demon
                          ? _demonColor
                          : status == CalibrationStatus.pending
                          ? _pendingColor
                          : gameMuted;

                      // 偽プレイヤーは薄く出して本物と見分けが付くようにする。
                      // 区別が付かないと、トグルを入れたままの部屋を「6人
                      // 集まっている」と読み違えたまま開始してしまう。
                      return Opacity(
                        opacity: isMock ? 0.45 : 1,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          // ゲーム画面のカードと同じ白地+細枠。鬼・未完了の
                          // 人だけ色付きの枠と薄い地で目立たせる。
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: borderColor,
                              width: borderColor == gameBorder ? 1 : 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: u.role == UserRole.demon
                                ? Color.alphaBlend(
                                    _demonColor.withValues(alpha: 0.05),
                                    Colors.white,
                                  )
                                : status == CalibrationStatus.pending
                                ? gameNoticeBackground
                                : Colors.white,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: avatarColor,
                                child: Text(
                                  avatarInitial(u.displayName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u.displayName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      [
                                        if (u.role == UserRole.demon &&
                                            room.demonRevokeUid == u.id)
                                          '鬼(解除中...)'
                                        else if (u.role == UserRole.demon)
                                          '鬼'
                                        else if (isPending)
                                          '逃走者(鬼に指名中...)'
                                        else
                                          '逃走者',
                                        if (u.isHost) 'ホスト',
                                      ].join(' ・ '),
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!room.setting.gpsOnly)
                                _CalibrationStatusIcon(status: status),
                              // 偽プレイヤーの行にはホストの操作を出さない。
                              // 押すとRTDBへ実在しないuidが書き込まれ、誰も
                              // 受諾できないまま残って**部屋が鬼を指名できなく
                              // なる**(取り消しボタンも偽プレイヤーの行にしか
                              // 出ないので、トグルを戻すと復旧できない)。
                              if (isHost && !isMock)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: u.role == UserRole.demon
                                      ? ActionChip(
                                          label: demonActionUid.value == u.id
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Text('取り消す'),
                                          onPressed:
                                              demonActionUid.value != null
                                              ? null
                                              : () => unawaited(
                                                  runDemonAction(
                                                    u.id,
                                                    () => roomRepo.revokeDemon(
                                                      roomId,
                                                      u.id,
                                                    ),
                                                  ),
                                                ),
                                        )
                                      : room.pendingDemonUid == u.id
                                      ? ActionChip(
                                          label: demonActionUid.value == u.id
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Text('取り消す'),
                                          onPressed:
                                              demonActionUid.value != null
                                              ? null
                                              : () => unawaited(
                                                  runDemonAction(
                                                    u.id,
                                                    () => roomRepo
                                                        .cancelDemonNomination(
                                                          roomId,
                                                        ),
                                                  ),
                                                ),
                                        )
                                      : ActionChip(
                                          label: demonActionUid.value == u.id
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Text('鬼にする'),
                                          onPressed:
                                              demonActionUid.value != null ||
                                                  room.pendingDemonUid != null
                                              ? null
                                              : () => unawaited(
                                                  runDemonAction(
                                                    u.id,
                                                    () =>
                                                        roomRepo.nominateDemon(
                                                          roomId,
                                                          u.id,
                                                        ),
                                                  ),
                                                ),
                                        ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (!room.setting.gpsOnly)
                  _CalibrationSection(
                    roomId: roomId,
                    isHost: isHost,
                    hostCalibrated: hostCalibrated,
                    myCalibrated: myCalibrated,
                    basePressure: room.basePressure,
                    pressureState: pressureState,
                  ),
                if (isHost && demonCount == 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '鬼を1人以上指名してください',
                      style: TextStyle(color: _pendingColor, fontSize: 12),
                    ),
                  ),
                if (isHost && demonCount > 0 && !canStartWithRoleComposition)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '逃走者が1人以上必要です',
                      style: TextStyle(color: _pendingColor, fontSize: 12),
                    ),
                  ),
                if (isHost && room.setting.gameArea.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '「設定」でプレイエリアを指定してください',
                      style: TextStyle(color: _pendingColor, fontSize: 12),
                    ),
                  ),
                if (isHost && !allCalibrated && pendingNames.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'キャリブレーション未完了: ${pendingNames.join('、')}',
                      style: const TextStyle(
                        color: _pendingColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (isHost)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: FilledButton(
                      onPressed:
                          startGame.isRunning ||
                              !canStartWithRoleComposition ||
                              room.setting.gameArea.isEmpty ||
                              !allCalibrated
                          ? null
                          : () => startGame.run(
                              () => ref
                                  .read(roomRepositoryProvider)
                                  .startGame(roomId),
                            ),
                      child: const Text('ゲーム開始'),
                    ),
                  ),
                if (startGame.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      userFacingErrorMessage(startGame.error!),
                      style: const TextStyle(
                        color: gameNewBadge,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                // Android 15以降は画面がナビゲーションバーの下まで広がるので、
                // 最下部の文字・ボタンがバーに潜らないよう、バーの高さぶん
                // 空ける(issue #136)。他の画面のようにSafeAreaで包むと、
                // 入れ子の深い参加者の行が1行80字に収まらなくなるため。
                SizedBox(height: MediaQuery.paddingOf(context).bottom),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => RoomStreamErrorView(roomId: roomId, error: e),
        ),
      ),
    );
  }
}

RoomUser? _findUser(List<RoomUser> users, String uid) {
  for (final user in users) {
    if (user.id == uid) return user;
  }
  return null;
}

/// 参加者リストの行に出す、キャリブレーション状況アイコン。
/// done(緑のチェック)/pending(グレーの未チェック)/unavailable(非対応)の
/// 3状態を一目で区別できるようにする。
class _CalibrationStatusIcon extends StatelessWidget {
  const _CalibrationStatusIcon({required this.status});

  final CalibrationStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case CalibrationStatus.done:
        return const Icon(Icons.check_circle, color: _doneColor, size: 18);
      case CalibrationStatus.pending:
        return const Icon(
          Icons.radio_button_unchecked,
          color: _pendingColor,
          size: 18,
        );
      case CalibrationStatus.unavailable:
        return const Tooltip(
          message: '気圧センサー非対応',
          child: Icon(Icons.sensors_off, color: gameEmptyDot, size: 18),
        );
    }
  }
}

class _CalibrationSection extends ConsumerWidget {
  const _CalibrationSection({
    required this.roomId,
    required this.isHost,
    required this.hostCalibrated,
    required this.myCalibrated,
    required this.basePressure,
    required this.pressureState,
  });

  final String roomId;
  final bool isHost;
  final bool hostCalibrated;
  final bool myCalibrated;
  final double? basePressure;
  final PressureState pressureState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ホスト以外はこの欄が画面の最下部に来るので、ホストの「ゲーム開始」
    // ボタンと同じだけ下を空け、ナビゲーションバーに張り付かないようにする
    // (issue #167)。
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, isHost ? 8 : 24),
      child: _buildMyStatus(ref),
    );
  }

  Widget _buildMyStatus(WidgetRef ref) {
    if (pressureState.sensorAvailability ==
        PressureSensorAvailability.unavailable) {
      return const Row(
        children: [
          Icon(Icons.sensors_off, color: gameMuted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'この端末は気圧センサーに非対応です(キャリブレーション不要)',
              style: TextStyle(color: gameMuted, fontSize: 12),
            ),
          ),
        ],
      );
    }

    if (myCalibrated) {
      return const Row(
        children: [
          Icon(Icons.check_circle, color: _doneColor),
          SizedBox(width: 8),
          Text(
            'キャリブレーション完了',
            style: TextStyle(color: _doneColor, fontWeight: FontWeight.w700),
          ),
        ],
      );
    }

    final checking =
        pressureState.sensorAvailability == PressureSensorAvailability.checking;
    final myPressureReady = pressureState.myPressureHPa != null;
    final canCalibrate =
        !checking &&
        myPressureReady &&
        !pressureState.isCalibrating &&
        (isHost || hostCalibrated);

    String? hint;
    if (checking) {
      hint = 'センサーを確認中...';
    } else if (!myPressureReady) {
      hint = '気圧を取得中...';
    } else if (!isHost && !hostCalibrated) {
      hint = 'ホストのキャリブレーション待ち';
    }

    // 失敗の理由は押した本人にしか関係しないので、ボタンのすぐ下に出す。
    final failureMessage = calibrationFailureMessage(
      pressureState.calibrationFailure,
    );

    return Column(
      children: [
        FilledButton.icon(
          icon: pressureState.isCalibrating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.touch_app),
          onPressed: canCalibrate
              ? () {
                  final notifier = ref.read(pressureViewModelProvider.notifier);
                  if (isHost) {
                    unawaited(notifier.calibrateAsHost(roomId));
                  } else {
                    unawaited(
                      notifier.calibrateAsParticipant(roomId, basePressure),
                    );
                  }
                }
              : null,
          label: Text(
            pressureState.isCalibrating ? 'キャリブレーション中...' : 'キャリブレーションする(未実施)',
          ),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hint,
              style: const TextStyle(color: gameMuted, fontSize: 12),
            ),
          ),
        if (failureMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              failureMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: gameNewBadge,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

/// 待機画面に出す「Wi-Fiスキャン: 〜」の1行(issue #98)。
///
/// Wi-Fiでの距離感は鬼の主要な情報源なのに、スキャンが空振りしていても
/// 以前は誰も気づけなかった。OK以外のときは直し方を1行で添え、設定を
/// 直してから押し直せるよう「再確認」を出す。
class _WifiScanStatusRow extends ConsumerWidget {
  const _WifiScanStatusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(wifiScanStatusProvider);
    final isProblem = isWifiScanProblem(status);
    // 非対応の端末は直しようがないので、警告色にも「再確認」の対象にもしない
    // (押しても永久に変わらないボタンを出さない)。
    final isFixable = isWifiScanFixable(status);
    final hint = wifiScanStatusHint(status);
    final color = isFixable ? _pendingColor : gameMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(isProblem ? Icons.wifi_off : Icons.wifi, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Wi-Fiスキャン: ${wifiScanStatusLabel(status)}',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: isFixable ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    hint,
                    style: const TextStyle(color: gameMuted, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
        if (isFixable)
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: () =>
                unawaited(ref.read(wifiScanStatusProvider.notifier).refresh()),
            child: const Text('再確認'),
          ),
      ],
    );
  }
}

/// 待機画面の「テザリングで接続している」の自己申告(issue #142)。
///
/// スマホのテザリングでこの端末をつないでいると、そのホットスポットが
/// 常に最強のAPとしてスキャンに入り、Wi-Fiの手がかりがブレる。ONにした
/// 人だけが接続先のBSSIDを共有し、全員の計算から除かれる。構内Wi-Fiに
/// つないでいる人の接続先は固定APなので、自動では除かずに本人に選んでもらう。
///
/// 値の持ち主はRTDB(`users/{uid}/usesTethering`)で、ここは表示と書き込み
/// だけを行う。
///
/// 送信中もスイッチは押せるままにする(useAsyncActionを使わない)。RTDBの
/// `update()`はサーバーが受け取るまで完了しないが、値自体は手元へすぐ
/// 反映される。電波が弱い場所で押し間違えたとき、完了を待たせると戻せない
/// ため。書き込みは後勝ちで順番どおりに届くので、連打しても最後の値が残る。
class _TetheringRow extends HookConsumerWidget {
  const _TetheringRow({required this.roomId, required this.usesTethering});

  final String roomId;
  final bool usesTethering;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = useState<Object?>(null);

    Future<void> save({required bool value}) async {
      error.value = null;
      try {
        await ref
            .read(roomRepositoryProvider)
            .setUsesTethering(roomId, value: value);
      } on Object catch (e) {
        debugPrint('[RoomWaitingPage] テザリングの自己申告の保存に失敗: $e');
        if (context.mounted) error.value = e;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.wifi_tethering, size: 14, color: gameMuted),
            const SizedBox(width: 6),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'テザリングで接続している',
                    style: TextStyle(color: gameMuted, fontSize: 12),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'スマホのテザリングでこの端末をつないでいるならON',
                      style: TextStyle(color: gameMuted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: usesTethering,
              onChanged: (value) => unawaited(save(value: value)),
            ),
          ],
        ),
        if (error.value != null)
          Text(
            userFacingErrorMessage(error.value!),
            style: const TextStyle(color: gameNewBadge, fontSize: 11),
          ),
      ],
    );
  }
}
