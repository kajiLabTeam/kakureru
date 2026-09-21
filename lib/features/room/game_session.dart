import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/ble/view_model/ble_view_model.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/room/game_alerts.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/wifi/view_model/wifi_view_model.dart';

/// ゲーム画面に滞在している間だけ、センサー4種(位置情報・気圧・Wi-Fi・BLE)と
/// 時間で発火する判定([GameAlerts])を動かすフック。画面を離れたらすべて止める。
///
/// どれも「ゲーム画面の滞在に紐づけて開始/停止する」という同じライフ
/// サイクルなので1つのフックにまとめている。GamePage.build に並べていた
/// ときは、画面のレイアウトを読むために無関係なセンサー配線を毎回読み
/// 飛ばす必要があった(useLeftUserNotificationsと同じ切り出し方針)。
///
/// センサーの種類ごとに依存配列が違う点に注意:
/// - 位置情報・気圧・Wi-Fiは[roomId]が変わったときだけ貼り直す
/// - BLEは自分のuidを広告するため、[myUid]が確定するまで開始できない
void useGameSession(
  WidgetRef ref, {
  required String roomId,
  required String? myUid,
}) {
  // 位置の送信・購読。
  useEffect(() {
    ref.read(locationViewModelProvider.notifier).start(roomId);
    return () => ref.read(locationViewModelProvider.notifier).stop();
  }, [roomId]);

  // 位置送信に失敗していたら、アプリへ戻ってきたタイミングで貼り直す。
  useLocationRetryOnResume(ref, roomId: roomId);

  // 気圧の送信。センサー購読自体は待機画面のキャリブレーションで既に
  // 始まっている想定(PressureViewModel.initは判定済みなら再判定しない)。
  useEffect(() {
    ref.read(pressureViewModelProvider.notifier)
      ..init(roomId)
      ..startSendingToRoom(roomId);
    return () =>
        ref.read(pressureViewModelProvider.notifier).stopSendingAndDispose();
  }, [roomId]);

  // Wi-Fiスキャン。位置情報・気圧とは別の、`WifiScanRepository` が持つ
  // 独自の間隔(`_scanInterval`)のタイマーで動く(Androidのスキャン
  // スロットリング対策。具体的な秒数はここに書き写さない — 書き写すと
  // 実装側を変えたときに片方だけ腐るため)。
  useEffect(() {
    ref.read(wifiScanRepositoryProvider).startScanning(roomId);
    return () => ref.read(wifiScanRepositoryProvider).stopScanning();
  }, [roomId]);

  // 時間で発火する判定(鬼放出・ゲーム終了・エリア外)。**画面が消えていても
  // 進む**ように、ウィジェットの再描画ではなく自前のタイマーで回している
  // (issue #71)。センサー4種と同じく、ゲーム画面の滞在に紐づけて開始/停止する。
  useEffect(() {
    // 後始末で`ref.read`を呼ばないよう、生きているうちにnotifierを掴んで
    // おく。widgetのunmount中にrefへ触るのはhooks_riverpodでは不正
    // (「Using "ref" when a widget is about to or has been unmounted is
    // unsafe」)で、画面を離れるときに例外になる。
    final alerts = ref.read(gameAlertsProvider.notifier);
    alerts.start(roomId);
    return alerts.stop;
  }, [roomId]);

  // BLEの広告・スキャン(issue #16)。myUidが確定するまで
  // (FirebaseAuthの復元前など)は開始できない。
  useEffect(() {
    if (myUid == null) return null;
    ref.read(bleViewModelProvider.notifier).start(myUid);
    return () => ref.read(bleViewModelProvider.notifier).stop();
  }, [myUid]);
}

/// 位置送信に失敗した状態のままアプリを離れ、設定で許可して戻ってきたときに
/// 送信を貼り直すフック。
///
/// 「常に許可」を必須ゲートにしていた頃は初回だけ必ずここで詰まっていたが
/// (issue #66)、ゲートを外した後も、最初のダイアログで拒否した人・端末の
/// 位置情報がOFFだった人は同じ状態になる。[useGameSession]の位置のeffectは
/// 依存配列が[roomId]だけなので、同じ部屋に居る限り二度とstart()されない。
/// ゲームを抜けて入り直さないと直せないのでは対戦中に実質直せないため、
/// 復帰(resumed)を拾って1回だけ呼び直す。
///
/// 成功している間(failure が none)は何もしない。start()を無駄に呼ぶと
/// Foreground Serviceを止めて起動し直すことになり、送信が一瞬途切れるため。
///
/// **「アプリが実際に背面へ回ってから戻ってきた」ときだけ**再試行する。
/// Androidは権限ダイアログが手前に出ただけでも `inactive` を挟み、閉じた
/// 瞬間に `resumed` を投げる。これを拾ってしまうと、ユーザーが拒否した
/// 直後に同じダイアログをもう一度出すことになり、**2回連続の拒否でAndroidが
/// 「今後表示しない」扱いにする**ため、アプリ内で許可してもらう最後の機会を
/// 自分で潰す(issue #66のレビュー指摘)。
///
/// 直前の状態だけでは判別できない点に注意。Flutterは `paused` へ移るときに
/// `inactive`→`hidden`→`paused` を、戻るときに `hidden`→`inactive`→`resumed`
/// を合成して順に流すため、**`resumed` の直前は必ず `inactive`** になる。
/// そこで「背面まで回ったことがあるか」を覚えておき、復帰時にそれを見る。
void useLocationRetryOnResume(WidgetRef ref, {required String roomId}) {
  final wentToBackground = useRef(false);
  useOnAppLifecycleStateChange((previous, current) {
    if (current == AppLifecycleState.paused ||
        current == AppLifecycleState.hidden) {
      wentToBackground.value = true;
      return;
    }
    if (current != AppLifecycleState.resumed) return;
    if (!wentToBackground.value) return;
    wentToBackground.value = false;

    final location = ref.read(locationViewModelProvider);
    if (location.failure == LocationFailure.none) return;
    ref.read(locationViewModelProvider.notifier).start(roomId);
  });
}
