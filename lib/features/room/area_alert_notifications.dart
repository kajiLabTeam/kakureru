import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kakureru/core/utils/local_notifications.dart';
import 'package:kakureru/features/room/area_alert.dart';
import 'package:vibration/vibration.dart';

/// エリア外にいる間、振動を繰り返す間隔。
///
/// 鳴らしっぱなしにはせず、短い振動を一定間隔で打つ。ポケットに入れたまま
/// 遊ぶ運用でも気づけて、かつバッテリーを食いつぶさない間隔として8秒にした。
const outsideAreaVibrationInterval = Duration(seconds: 8);

/// 1回あたりの振動の長さ(ミリ秒)。鬼放出の通知(800ms)より少し短くして、
/// 繰り返し鳴ってもうるさくなりすぎないようにしている。
const _vibrationDurationMillis = 600;

/// エリア外警告を出すかどうかを、猶予距離・猶予時間を通して持ち越すフック。
///
/// 判定そのものは純粋関数(`applyOutsideAreaHysteresis`)側にあり、ここは
/// 「前回の判定結果」をウィジェットの寿命のあいだ持つだけ。GamePageが
/// 破棄されたら一緒に消えてよい一時状態なのでhooksで持つ(AGENTS.mdの
/// 状態管理規約)。
///
/// [observation]には`observeOutsideArea`が作った観測をそのまま渡す
/// (エリア内/エリア外/判定に使える位置が無い、の3状態)。
///
/// [tick]には毎秒更新されるカウンタを渡すこと。猶予時間の経過も、位置が
/// 分からない状態が続いている時間も、GPSの更新とは無関係に進むため、
/// これが無いと観測が変わらない間の時間経過が判定に反映されない。
///
/// [clock]は現在時刻の取得元。既定は`DateTime.now`で、テストから猶予時間の
/// 経過を実時間を待たずに再現するための差し替え口として開けている
/// (widgetテストの`pump`は`DateTime.now`を進めないため)。
bool useOutsideAreaWarning({
  required OutsideAreaObservation observation,
  required int tick,
  DateTime Function() clock = DateTime.now,
}) {
  final state = useRef(initialOutsideAreaWarningState);

  // 同じ秒のうちに複数回リビルドされても判定がぶれないよう、時刻は
  // tick(と観測)が変わったときにだけ取り直す。
  final now = useMemoized(clock, [tick, observation]);

  final next = applyOutsideAreaHysteresis(
    observation: observation,
    previous: state.value,
    now: now,
  );
  state.value = next;
  return next.isWarning;
}

/// エリア外の警告を出している間だけ、振動と通知を出し続けるフック
/// (issue #61)。
///
/// 外に出た瞬間に1回振動して通知を出し、そのあとは
/// [outsideAreaVibrationInterval]ごとに振動と通知を繰り返す。エリア内に
/// 戻るか、ゲーム画面を離れたら通知を消して振動も止める。
///
/// 通知を毎回出し直すのは、Android 14(API 34)以降は`ongoing`の通知でも
/// ユーザーがスワイプで消せるようになったため(`showOutsideAreaNotification`
/// のコメント参照)。消されたまま振動だけが続く状態をなくす。同じIDの
/// `show`は更新扱いなので、繰り返しても通知が増えることはない。
///
/// [isOutside]には、**画面にアラートを出しているのと同じ条件**を渡すこと。
/// 判定だけを見て振動させると、RTDBが一瞬こけて画面がスピナーやエラーに
/// 切り替わっている間も、バナーが無いまま振動と通知だけが続く。
///
/// **役割による出し分けはしない**。隠れている逃走者の居場所が振動で
/// 周囲にバレうる点は議論のうえで、エリア外はルール違反なのでペナルティ
/// として意図的に継続すると決めている(issue #61の検討メモ)。
void useOutsideAreaNotifications({required bool isOutside}) {
  useEffect(() {
    if (!isOutside) return null;

    // エリア内に戻った/画面を離れた後に、遅れて届いた`hasVibrator()`の
    // 結果で振動してしまわないためのガード。
    var isCancelled = false;
    void pulse() {
      if (isCancelled) return;
      _vibrateOnce(() => isCancelled);
      showOutsideAreaNotification();
    }

    pulse();
    final timer = Timer.periodic(
      outsideAreaVibrationInterval,
      (_) => pulse(),
    );
    // エリア内に戻った / ゲーム画面を離れたときの後始末。
    return () {
      isCancelled = true;
      timer.cancel();
      cancelOutsideAreaNotification();
    };
  }, [isOutside]);
}

/// 振動できる端末なら1回振動させる。
///
/// 書き方は`game_notifications.dart`と揃えているが、こちらは周期実行なので
/// 後始末と例外処理を足している。[isCancelled]がtrueを返したら振動しない
/// (エリア内に戻った後・画面を離れた後に遅れて鳴るのを防ぐ)。対応して
/// いない端末では`hasVibrator()`自体が失敗しうるため、8秒ごとに未処理の
/// 非同期エラーを出さないよう捕まえてログに落とす。
Future<void> _vibrateOnce(bool Function() isCancelled) async {
  try {
    if (!await Vibration.hasVibrator()) return;
    if (isCancelled()) return;
    await Vibration.vibrate(duration: _vibrationDurationMillis);
  } on Object catch (e) {
    debugPrint('[useOutsideAreaNotifications] 振動に失敗: $e');
  }
}
