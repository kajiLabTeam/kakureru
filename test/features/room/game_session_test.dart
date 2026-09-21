import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/ble/model/ble_detection.dart';
import 'package:kakureru/features/ble/view_model/ble_view_model.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/room/game_alerts.dart';
import 'package:kakureru/features/room/game_session.dart';
import 'package:kakureru/features/wifi/repository/wifi_scan_repository.dart';
import 'package:kakureru/features/wifi/view_model/wifi_view_model.dart';

/// start()が呼ばれた回数だけを記録する差し替え。本物のstart()はGeolocatorや
/// Foreground Serviceへ触れるため、ここでは呼ばせない。
class _RecordingLocationViewModel extends LocationViewModel {
  _RecordingLocationViewModel(this._initialState);

  final LocationState _initialState;
  final startedRooms = <String>[];
  int stopCalls = 0;

  @override
  LocationState build() => _initialState;

  @override
  Future<void> start(String roomId) async {
    startedRooms.add(roomId);
  }

  @override
  void stop() {
    stopCalls++;
  }
}

/// 気圧の開始/停止の呼び出し回数だけを記録する差し替え。本物は
/// センサーとRTDBへ触れる。
class _RecordingPressureViewModel extends PressureViewModel {
  int stopCalls = 0;

  @override
  PressureState build() => const PressureState();

  @override
  Future<void> init(String roomId) async {}

  @override
  void startSendingToRoom(String roomId) {}

  @override
  void stopSendingAndDispose() {
    stopCalls++;
  }
}

/// Wi-Fiスキャンの開始/停止の呼び出し回数だけを記録する差し替え。本物は
/// プラグイン(WiFiScan)とRTDBへ触れる。
class _RecordingWifiScanRepository extends WifiScanRepository {
  int stopCalls = 0;

  @override
  void startScanning(String roomId) {}

  @override
  void stopScanning() {
    stopCalls++;
  }
}

/// BLEの開始/停止の呼び出し回数だけを記録する差し替え。本物は権限要求と
/// BLEの広告・スキャンへ触れる。
class _RecordingBleViewModel extends BleViewModel {
  int stopCalls = 0;

  @override
  Map<String, BleDetection> build() => const {};

  @override
  Future<void> start(String myUid) async {}

  @override
  void stop() {
    stopCalls++;
  }
}

/// [GameAlerts]の開始/停止の呼び出し回数だけを記録する差し替え。本物は
/// RTDB(部屋・サーバー時刻)を購読しに行く。
///
/// センサー4種ではないが、同じ[useGameSession]の中で同じ形で止めている
/// (issue #71)ので、一緒に見ておく。`game_alerts_test.dart`が見ているのは
/// [GameAlerts]単体の振る舞いで、**フックが停止を呼ぶこと**は見ていない。
class _RecordingGameAlerts extends GameAlerts {
  int stopCalls = 0;

  @override
  GameAlertsState build() => initialGameAlertsState;

  @override
  void start(String roomId) {}

  @override
  void stop() {
    stopCalls++;
  }
}

/// [useLocationRetryOnResume]だけを貼ったテスト用ウィジェット。
/// useGameSession 全体を貼ると復帰時の再試行以外の配線まで動くため、
/// ここだけを切り出して確認する。
class _RetryHarness extends HookConsumerWidget {
  const _RetryHarness({required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useLocationRetryOnResume(ref, roomId: roomId);
    return const SizedBox.shrink();
  }
}

/// アプリのライフサイクル変化を、実際と同じ経路(flutter/lifecycleチャンネル)
/// でフレームワークへ流し込む。
Future<void> _sendLifecycle(
  WidgetTester tester,
  AppLifecycleState state,
) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state.toString()),
    (_) {},
  );
}

Future<_RecordingLocationViewModel> _pumpHarness(
  WidgetTester tester,
  LocationState initialState,
) async {
  final viewModel = _RecordingLocationViewModel(initialState);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [locationViewModelProvider.overrideWith(() => viewModel)],
      child: const _RetryHarness(roomId: 'room-1'),
    ),
  );
  return viewModel;
}

/// ゲーム画面(GamePage)と同じように[useGameSession]を貼るだけのウィジェット。
/// GamePage本体は地図やRTDBの購読まで抱えているため、センサーの開始/停止の
/// 配線だけをここに切り出して確認する。
class _GameSessionHarness extends HookConsumerWidget {
  const _GameSessionHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useGameSession(ref, roomId: 'room-1', myUid: 'me');
    return const SizedBox.shrink();
  }
}

/// [useGameSession]が動かす4種のセンサーの差し替え一式。
typedef _Sensors = ({
  _RecordingLocationViewModel location,
  _RecordingPressureViewModel pressure,
  _RecordingWifiScanRepository wifi,
  _RecordingBleViewModel ble,
  _RecordingGameAlerts alerts,
});

/// [_GameSessionHarness]をマウントし、差し替えたセンサーを返す。
Future<_Sensors> _pumpGameSession(WidgetTester tester) async {
  final sensors = (
    location: _RecordingLocationViewModel(const LocationState()),
    pressure: _RecordingPressureViewModel(),
    wifi: _RecordingWifiScanRepository(),
    ble: _RecordingBleViewModel(),
    alerts: _RecordingGameAlerts(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        locationViewModelProvider.overrideWith(() => sensors.location),
        pressureViewModelProvider.overrideWith(() => sensors.pressure),
        wifiScanRepositoryProvider.overrideWithValue(sensors.wifi),
        bleViewModelProvider.overrideWith(() => sensors.ble),
        gameAlertsProvider.overrideWith(() => sensors.alerts),
      ],
      child: const _GameSessionHarness(),
    ),
  );
  return sensors;
}

/// ゲーム画面を離れた状態(unmount)を作る。ProviderScopeごと差し替えるので、
/// 実際に別画面へ遷移したときと同じ順序で後始末が走る。
Future<void> _leaveGameScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  // 画面を離れたら4種のセンサーが止まることの再発防止。以前は後始末の中で
  // `ref.read`を呼んでおり、unmount中のrefは使えない(StateError)ため
  // stop()が一度も走らず、位置情報のForeground Service・気圧の送信・
  // Wi-Fiスキャン・BLEの発信が残り続けていた(issue #93)。例外はhooksが
  // 握るので画面には何も出ず、気づけるのはこの形のテストだけ。
  //
  // **4種を1つのテストにまとめない。** stopの呼び出しを消す・別のものを
  // 返すといった回帰が起きたときに、どのセンサーが止まらなくなったのかが
  // テスト名で分かるようにするため(上の`ref.read`のやり方に戻した場合は、
  // 例外が同じpumpの中でまとめて流れるので4本とも落ちる)。
  group('useGameSession: 画面を離れたら止まる', () {
    testWidgets('位置情報の送信を止める', (tester) async {
      final sensors = await _pumpGameSession(tester);
      expect(sensors.location.stopCalls, 0);

      await _leaveGameScreen(tester);

      expect(sensors.location.stopCalls, 1);
    });

    testWidgets('気圧の送信を止める', (tester) async {
      final sensors = await _pumpGameSession(tester);
      expect(sensors.pressure.stopCalls, 0);

      await _leaveGameScreen(tester);

      expect(sensors.pressure.stopCalls, 1);
    });

    testWidgets('Wi-Fiスキャンを止める', (tester) async {
      final sensors = await _pumpGameSession(tester);
      expect(sensors.wifi.stopCalls, 0);

      await _leaveGameScreen(tester);

      expect(sensors.wifi.stopCalls, 1);
    });

    testWidgets('BLEの広告・スキャンを止める', (tester) async {
      final sensors = await _pumpGameSession(tester);
      expect(sensors.ble.stopCalls, 0);

      await _leaveGameScreen(tester);

      expect(sensors.ble.stopCalls, 1);
    });

    testWidgets('時間で発火する判定(GameAlerts)を止める', (tester) async {
      final sensors = await _pumpGameSession(tester);
      expect(sensors.alerts.stopCalls, 0);

      await _leaveGameScreen(tester);

      expect(sensors.alerts.stopCalls, 1);
    });
  });

  group('useLocationRetryOnResume', () {
    testWidgets('権限を拒否したままアプリへ戻ってきたら、位置送信を始め直す', (tester) async {
      final viewModel = await _pumpHarness(
        tester,
        const LocationState(failure: LocationFailure.locationPermission),
      );

      await _sendLifecycle(tester, AppLifecycleState.paused);
      await tester.pump();
      expect(viewModel.startedRooms, isEmpty, reason: '離脱しただけでは始め直さない');

      // 設定画面で許可して戻ってきた、に相当する。
      await _sendLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();

      expect(viewModel.startedRooms, ['room-1']);
    });

    testWidgets('送信の開始に失敗したままでも、戻ってきたら始め直す', (tester) async {
      final viewModel = await _pumpHarness(
        tester,
        const LocationState(failure: LocationFailure.sendingFailed),
      );

      await _sendLifecycle(tester, AppLifecycleState.paused);
      await _sendLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();

      expect(viewModel.startedRooms, ['room-1']);
    });

    // Androidは権限ダイアログが手前に出ただけでも inactive を挟み、閉じた
    // 瞬間に resumed を投げる。これで始め直すと、拒否した直後に同じ
    // ダイアログをもう一度出すことになり、2回連続の拒否でAndroidが
    // 「今後表示しない」扱いにしてしまう(issue #66のレビュー指摘)。
    testWidgets('権限ダイアログを閉じただけ(inactive→resumed)では始め直さない', (tester) async {
      final viewModel = await _pumpHarness(
        tester,
        const LocationState(failure: LocationFailure.locationPermission),
      );

      await _sendLifecycle(tester, AppLifecycleState.inactive);
      await _sendLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();

      expect(viewModel.startedRooms, isEmpty);
    });

    testWidgets('hiddenを経由した復帰では始め直す', (tester) async {
      final viewModel = await _pumpHarness(
        tester,
        const LocationState(failure: LocationFailure.locationPermission),
      );

      await _sendLifecycle(tester, AppLifecycleState.hidden);
      await _sendLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();

      expect(viewModel.startedRooms, ['room-1']);
    });

    testWidgets('正常に送信できているときは、戻ってきても始め直さない', (tester) async {
      // 無駄に始め直すとForeground Serviceを止めて起動し直すことになり、
      // 送信が一瞬途切れてしまう。
      final viewModel = await _pumpHarness(
        tester,
        const LocationState(isSending: true),
      );

      await _sendLifecycle(tester, AppLifecycleState.paused);
      await _sendLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();

      expect(viewModel.startedRooms, isEmpty);
    });
  });
}
