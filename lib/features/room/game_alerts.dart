import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/core/utils/local_notifications.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/room/area_alert.dart';
import 'package:kakureru/features/room/debug_mock_players.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/role_visibility.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:vibration/vibration.dart';

/// 時間で発火する判定(鬼放出・ゲーム終了・エリア外)を、**画面が消えていても**
/// 進める駆動役(issue #71)。
///
/// 以前はこの3つをGamePageのフックに置き、毎秒進む`tick`を`useEffect`の
/// 依存配列に入れて回していた。しかし**画面が消えるとFlutterはフレームを
/// 止める**ため、タイマーが動いていても`build`が走らず、判定そのものが
/// 進まなかった。「ポケットに入れたまま遊ぶ」運用なので、画面が消えている
/// 時間の方がむしろ長い。鬼放出の通知は「振動だけだと画面を見ていないと
/// 気づけない」という理由で作ったのに、まさにその状況で動いていなかった。
///
/// providerもTimerも**フレームではなくDartのイベントループで動く**ので、
/// ここへ移すと画面と無関係に進む。ゲーム画面にいる間はForeground Service
/// が動いていてプロセスが生かされるため、タイマーも止まらない。
///
/// ウィジェット側は[GameAlertsState]を`ref.watch`して**表示するだけ**に
/// する(表示は画面が点いているときだけ意味があるので、それで正しい)。
///
/// **判定ロジック自体はここに書かない。** 既存の純粋関数
/// (`isGameOver` / `observeOutsideArea` / `applyOutsideAreaHysteresis`)を
/// 呼ぶだけにして、判定のテストはそちらに任せる。
class GameAlerts extends Notifier<GameAlertsState> {
  /// [elapsedMillis]はテストから単調増加の時計を差し替えるためだけの口。
  /// 本番は省略して[Stopwatch]を使う。
  GameAlerts({@visibleForTesting int Function()? elapsedMillis})
    : _elapsedMillisOverride = elapsedMillis;

  /// 判定の周期。以前のGamePageの`tick`と同じ1秒。
  static const _evaluateInterval = Duration(seconds: 1);

  /// 1秒ごとに[_evaluate]を回すタイマー。[start]で張り、[stop]で畳む。
  Timer? _evaluateTimer;

  /// エリア外の振動・通知を繰り返すタイマー。警告に入ったときだけ張る。
  Timer? _vibrationTimer;

  /// いま判定している部屋。[stop]後はnull。
  String? _roomId;

  /// 部屋の購読。**持っておくことに意味がある。**
  ///
  /// `roomStreamProvider`は`autoDispose`なので、`ref.read`で覗くだけだと
  /// 読んだ直後に破棄され、ストリームが最初の値を出す前に消えてしまう
  /// (毎回`AsyncLoading`が返る)。GamePageが`ref.watch`している間はたまたま
  /// 生き残るが、**判定が画面の都合に依存してしまう**。それではこの
  /// クラスを作った意味が無いので、ここで自分の購読を持つ。
  ProviderSubscription<AsyncValue<Room>>? _roomSub;

  /// 猶予時間の計測に使う単調増加の時計。
  ///
  /// `DateTime.now()`を使うと、NTP補正で時刻が巻き戻ったときに猶予が進まず、
  /// 進みすぎたときは一気に飛ぶ。[applyOutsideAreaHysteresis]は渡した時刻を
  /// **差分にしか使わない**ので、原点がいつであろうと構わない。
  ///
  /// なお`Stopwatch`は端末のディープスリープ中は進まないが、その状況では
  /// そもそも[_evaluateTimer]が発火していないので実害は無い。ずれても
  /// 「猶予が長めに出る=誤報が減る」安全側に倒れる。
  final _elapsed = Stopwatch();

  /// [_elapsed]の代わりに使う経過ミリ秒の取得元。テスト専用の差し替え口。
  ///
  /// `fakeAsync`で`Timer`を進めても`Stopwatch`は進まないため、猶予時間の
  /// 経過をテストから再現するにはここを差し替える必要がある。
  final int Function()? _elapsedMillisOverride;

  int get _elapsedMillis =>
      _elapsedMillisOverride?.call() ?? _elapsed.elapsedMilliseconds;

  /// 鬼放出・ゲーム終了の通知を出したか。どちらも一度きりの合図なので、
  /// 毎秒の判定で繰り返し発火させない。
  var _notifiedDemonRelease = false;
  var _notifiedGameOver = false;

  /// エリア外の猶予判定が持ち越す状態。
  var _warning = initialOutsideAreaWarningState;

  @override
  GameAlertsState build() {
    ref.onDispose(_disposeTimers);
    return initialGameAlertsState;
  }

  /// ゲーム画面に入った時に呼ぶ。1秒ごとの判定を始める。
  ///
  /// 同じ部屋で二重に呼ばれても安全なように、必ず前のタイマーを畳んでから
  /// 張り直す。部屋が変わったら発火済みフラグと猶予の状態も捨てる
  /// (前の試合の「通知済み」を持ち越すと、次の試合の鬼放出が鳴らない)。
  void start(String roomId) {
    stop();
    _roomId = roomId;
    _elapsed
      ..reset()
      ..start();
    _roomSub = ref.listen(roomStreamProvider(roomId), (_, _) {});
    _evaluateTimer = Timer.periodic(_evaluateInterval, (_) => _evaluate());
    // タイマーの初回発火は1秒後。画面に入った瞬間に既に終了している
    // (再入場した等)場合にその1秒を待たせないよう、ここで1回打つ。
    _evaluate();
  }

  /// ゲーム画面を離れた時に呼ぶ。タイマーを畳み、エリア外の通知も消す。
  ///
  /// 発火済みフラグと猶予の状態もここで捨てる。このproviderはアプリの
  /// 生存期間ずっと生きているので、残すと次の部屋へそのまま持ち越される
  /// (`LocationViewModel.stop`と同じ理由)。
  void stop() {
    _disposeTimers();
    _roomId = null;
    _elapsed
      ..stop()
      ..reset();
    _notifiedDemonRelease = false;
    _notifiedGameOver = false;
    _warning = initialOutsideAreaWarningState;
    state = initialGameAlertsState;
  }

  void _disposeTimers() {
    _evaluateTimer?.cancel();
    _evaluateTimer = null;
    _roomSub?.close();
    _roomSub = null;
    _stopVibration();
  }

  /// 毎秒ここに来る。入力を集めて既存の純粋関数に渡し、結果に応じて
  /// 副作用(振動・通知)を打つ。
  @visibleForTesting
  void evaluateForTest() => _evaluate();

  void _evaluate() {
    final roomId = _roomId;
    if (roomId == null) return;

    // roomがnullなのはRTDBがまだ届いていない/一時的にこけているとき。
    // 以前はGamePage側で「本文がdataを描いているか」を見て発火を止めて
    // いたが、画面が消えている間はそもそも本文が無い。ここではroomが
    // 無いことをそのまま「判定に使える情報が無い」として扱う。
    final room = _roomSub?.read().value;
    final offset = ref.read(serverTimeOffsetProvider).value ?? 0;
    final nowMillis = serverNowMillis(offset);

    _evaluateDemonRelease(room, nowMillis);
    _evaluateGameOver(room, nowMillis);
    _evaluateOutsideArea(room, nowMillis);
  }

  /// 鬼放出の瞬間に一度だけ振動+通知する。
  void _evaluateDemonRelease(Room? room, int nowMillis) {
    if (_notifiedDemonRelease) return;
    final releasedAt = room?.releasedAt;
    if (releasedAt == null || nowMillis < releasedAt) return;

    _notifiedDemonRelease = true;
    unawaited(_vibrateOnce(_demonReleaseVibrationMillis));
    unawaited(showDemonReleasedNotification());
  }

  /// ゲーム終了を検知したら一度だけ通知し、状態に立てる。
  ///
  /// 結果画面への遷移はここではやらない。Navigator操作にはフレームが要り、
  /// 画面が消えている間はそもそも遷移させる意味が無いため、検知(ここ)と
  /// 遷移(`useGameOverNavigation`)を分けている。
  void _evaluateGameOver(Room? room, int nowMillis) {
    if (_notifiedGameOver || room == null) return;
    final gameOver = isGameOver(
      status: room.status,
      endsAt: room.endsAt,
      nowMillis: nowMillis,
      // デバッグ用の偽プレイヤーを出している間は、逃走者が居る扱いにする。
      // 実機1台で自分が鬼になって開始すると、RTDB上の逃走者は0人なので
      // ゲーム画面に入った瞬間に終了扱いになる(issue #67)。
      hasFugitives:
          ref.read(showDebugMockPlayersProvider) ||
          room.users.any((u) => u.role == UserRole.fugitive),
    );
    if (!gameOver) return;

    _notifiedGameOver = true;
    unawaited(showGameOverNotification());
    state = (
      isOutsideAreaWarning: state.isOutsideAreaWarning,
      isGameOver: true,
    );
  }

  /// エリア外の判定。警告に入ったら振動と通知を繰り返し、戻ったら止める。
  void _evaluateOutsideArea(Room? room, int nowMillis) {
    final observation = observeOutsideArea(
      area: room?.setting.gameArea,
      location: _myLocation(),
      // updatedAtはServerValue.timestampで書かれるのでサーバー時刻で比べる。
      nowMillis: nowMillis,
    );
    _warning = applyOutsideAreaHysteresis(
      observation: observation,
      previous: _warning,
      // 猶予の経過だけは単調増加の時計で測る(上の_elapsedのコメント参照)。
      now: DateTime.fromMillisecondsSinceEpoch(_elapsedMillis),
    );

    final wasWarning = state.isOutsideAreaWarning;
    if (_warning.isWarning == wasWarning) return;

    state = (
      isOutsideAreaWarning: _warning.isWarning,
      isGameOver: state.isGameOver,
    );
    if (_warning.isWarning) {
      _startVibration();
    } else {
      _stopVibration();
    }
  }

  UserLocation? _myLocation() {
    final myUid = ref.read(myUidProvider);
    if (myUid == null) return null;
    for (final location in ref.read(locationViewModelProvider).locations) {
      if (location.uid == myUid) return location;
    }
    return null;
  }

  /// エリア外にいる間の振動と通知を始める。
  ///
  /// 通知を毎回出し直すのは、Android 14(API 34)以降は`ongoing`の通知でも
  /// ユーザーがスワイプで消せるため(`showOutsideAreaNotification`のコメント
  /// 参照)。消されたまま振動だけが続く状態をなくす。同じIDの`show`は更新
  /// 扱いなので、繰り返しても通知が増えることはない。
  void _startVibration() {
    _vibrationTimer?.cancel();
    void pulse() {
      unawaited(_vibrateOnce(_outsideAreaVibrationMillis));
      unawaited(showOutsideAreaNotification());
    }

    pulse();
    _vibrationTimer = Timer.periodic(
      outsideAreaVibrationInterval,
      (_) => pulse(),
    );
  }

  void _stopVibration() {
    if (_vibrationTimer == null) return;
    _vibrationTimer!.cancel();
    _vibrationTimer = null;
    unawaited(cancelOutsideAreaNotification());
  }

  /// 振動できる端末なら1回振動させる。
  ///
  /// 対応していない端末では`hasVibrator()`自体が失敗しうるため、8秒ごとに
  /// 未処理の非同期エラーを出さないよう捕まえてログに落とす。
  Future<void> _vibrateOnce(int durationMillis) async {
    try {
      if (!await Vibration.hasVibrator()) return;
      await Vibration.vibrate(duration: durationMillis);
    } on Object catch (e) {
      debugPrint('[GameAlerts] 振動に失敗: $e');
    }
  }
}

/// エリア外にいる間、振動を繰り返す間隔。
///
/// 鳴らしっぱなしにはせず、短い振動を一定間隔で打つ。ポケットに入れたまま
/// 遊ぶ運用でも気づけて、かつバッテリーを食いつぶさない間隔として8秒にした。
const outsideAreaVibrationInterval = Duration(seconds: 8);

/// 鬼放出の振動の長さ(ミリ秒)。一度きりの合図なので長めに取る。
const _demonReleaseVibrationMillis = 800;

/// エリア外の振動1回あたりの長さ(ミリ秒)。鬼放出(800ms)より少し短くして、
/// 繰り返し鳴ってもうるさくなりすぎないようにしている。
const _outsideAreaVibrationMillis = 600;

/// ウィジェットが表示に使う、時間で発火する判定の結果。
///
/// 振動・通知は[GameAlerts]が直接打つので、ここには**画面に出すために要る
/// ものだけ**を置く。
typedef GameAlertsState = ({
  /// エリア外の警告を出しているか(赤帯・地図の赤かぶせの表示条件)。
  bool isOutsideAreaWarning,

  /// ゲームの終了を検知したか(結果画面への遷移の条件)。
  bool isGameOver,
});

/// 何も検知していない初期状態。
const GameAlertsState initialGameAlertsState = (
  isOutsideAreaWarning: false,
  isGameOver: false,
);

final gameAlertsProvider = NotifierProvider<GameAlerts, GameAlertsState>(
  GameAlerts.new,
);
