import 'dart:async';

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
/// [outsideMeters]にはエリア外なら境界までの距離(m)、内側ならnullを渡す
/// (`describeReturnToArea`の戻り値の`meters`をそのまま渡せる)。
///
/// [tick]には毎秒更新されるカウンタを渡すこと。猶予時間の経過はGPSの
/// 更新とは無関係に進むため、これが無いと「猶予距離を超えたまま位置が
/// 一度も更新されない」間に警告へ切り替わらない。
bool useOutsideAreaWarning({
  required double? outsideMeters,
  required int tick,
}) {
  final outsideSince = useRef<DateTime?>(null);
  final wasWarning = useRef(false);

  // 同じ秒のうちに複数回リビルドされても判定がぶれないよう、時刻は
  // tick(と距離)が変わったときにだけ取り直す。
  final now = useMemoized(DateTime.now, [tick, outsideMeters]);

  final result = applyOutsideAreaHysteresis(
    outsideMeters: outsideMeters,
    wasWarning: wasWarning.value,
    outsideSince: outsideSince.value,
    now: now,
  );
  outsideSince.value = result.outsideSince;
  wasWarning.value = result.isWarning;
  return result.isWarning;
}

/// エリア外にいる間だけ、振動と「戻るまで消えない通知」を出し続けるフック
/// (issue #61)。
///
/// 外に出た瞬間に1回振動して通知を出し、そのあとは
/// [outsideAreaVibrationInterval]ごとに振動を繰り返す。エリア内に戻るか、
/// ゲーム画面を離れたら通知を消して振動も止める。
///
/// **役割による出し分けはしない**。隠れている逃走者の居場所が振動で
/// 周囲にバレうる点は議論のうえで、エリア外はルール違反なのでペナルティ
/// として意図的に継続すると決めている(issue #61の検討メモ)。
void useOutsideAreaNotifications({required bool isOutside}) {
  useEffect(() {
    if (!isOutside) return null;

    _vibrateOnce();
    showOutsideAreaNotification();
    final timer = Timer.periodic(
      outsideAreaVibrationInterval,
      (_) => _vibrateOnce(),
    );
    // エリア内に戻った / ゲーム画面を離れたときの後始末。通知は
    // ongoing なので、明示的に消さないと残り続ける。
    return () {
      timer.cancel();
      cancelOutsideAreaNotification();
    };
  }, [isOutside]);
}

/// 振動できる端末なら1回振動させる。書き方は`game_notifications.dart`と揃える。
void _vibrateOnce() {
  Vibration.hasVibrator().then((hasVibrator) {
    if (hasVibrator) Vibration.vibrate(duration: _vibrationDurationMillis);
  });
}
