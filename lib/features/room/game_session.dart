import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/ble/view_model/ble_view_model.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/wifi/view_model/wifi_view_model.dart';

/// ゲーム画面に滞在している間だけセンサー4種(位置情報・気圧・Wi-Fi・BLE)を
/// 動かすフック。画面を離れたらすべて止める。
///
/// 4つとも「ゲーム画面の滞在に紐づけて開始/停止する」という同じライフ
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

  // BLEの広告・スキャン(issue #16)。myUidが確定するまで
  // (FirebaseAuthの復元前など)は開始できない。
  useEffect(() {
    if (myUid == null) return null;
    ref.read(bleViewModelProvider.notifier).start(myUid);
    return () => ref.read(bleViewModelProvider.notifier).stop();
  }, [myUid]);
}
