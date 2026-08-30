import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/ble/model/ble_detection.dart';
import 'package:kakureru/features/ble/repository/ble_permission.dart';
import 'package:kakureru/features/ble/repository/ble_scan_repository.dart';
import 'package:kakureru/features/ble/view_model/ble_view_model.dart';
import 'package:permission_handler/permission_handler.dart';

/// 実際のBLEプラグインを呼ばずに、広告/スキャンの開始・停止回数と
/// 検知結果ストリームだけを差し替えるテスト用サブクラス。
class _FakeBleScanRepository extends BleScanRepository {
  final _controller = StreamController<BleDetection>.broadcast();
  var startAdvertisingCalls = 0;
  var stopAdvertisingCalls = 0;
  var startScanningCalls = 0;
  var stopScanningCalls = 0;

  @override
  Stream<BleDetection> get detections => _controller.stream;

  @override
  Future<void> startAdvertising(String uid) async {
    startAdvertisingCalls++;
  }

  @override
  Future<void> stopAdvertising() async {
    stopAdvertisingCalls++;
  }

  @override
  void startScanning() {
    startScanningCalls++;
  }

  @override
  void stopScanning() {
    stopScanningCalls++;
  }

  void emit(BleDetection detection) => _controller.add(detection);
}

/// 実際の権限ダイアログを出さずに、指定した結果をそのまま返すテスト用サブクラス。
class _FakeBlePermissionService extends BlePermissionService {
  _FakeBlePermissionService({this.granted = true, this.resultFuture});

  final bool granted;

  /// nullでなければこのFutureの解決を待ってから結果を返す(権限確認中に
  /// stop()で追い越されるケースの再現用)。
  final Completer<bool>? resultFuture;

  @override
  Future<bool> ensureGranted() async {
    if (resultFuture != null) return resultFuture!.future;
    return granted;
  }
}

void main() {
  group('BleViewModel', () {
    test('start()で権限確認後に広告とスキャンの両方を始める', () async {
      final repo = _FakeBleScanRepository();
      final container = ProviderContainer(
        overrides: [
          bleScanRepositoryProvider.overrideWithValue(repo),
          blePermissionServiceProvider.overrideWithValue(
            _FakeBlePermissionService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(bleViewModelProvider.notifier);

      await notifier.start('my-uid');

      expect(repo.startAdvertisingCalls, 1);
      expect(repo.startScanningCalls, 1);
    });

    test('権限が拒否されたら広告もスキャンも始めない', () async {
      final repo = _FakeBleScanRepository();
      final container = ProviderContainer(
        overrides: [
          bleScanRepositoryProvider.overrideWithValue(repo),
          blePermissionServiceProvider.overrideWithValue(
            _FakeBlePermissionService(granted: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(bleViewModelProvider.notifier);

      await notifier.start('my-uid');

      expect(repo.startAdvertisingCalls, 0);
      expect(repo.startScanningCalls, 0);
    });

    test('権限確認中にstop()で追い越されたら、権限が下りても開始しない', () async {
      final repo = _FakeBleScanRepository();
      final permissionResult = Completer<bool>();
      final container = ProviderContainer(
        overrides: [
          bleScanRepositoryProvider.overrideWithValue(repo),
          blePermissionServiceProvider.overrideWithValue(
            _FakeBlePermissionService(resultFuture: permissionResult),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(bleViewModelProvider.notifier);

      final startFuture = notifier.start('my-uid');
      notifier.stop();
      permissionResult.complete(true);
      await startFuture;

      expect(repo.startAdvertisingCalls, 0);
      expect(repo.startScanningCalls, 0);
    });

    test('検知結果を受け取ると短縮uidをキーにstateへ反映する', () async {
      final repo = _FakeBleScanRepository();
      final container = ProviderContainer(
        overrides: [
          bleScanRepositoryProvider.overrideWithValue(repo),
          blePermissionServiceProvider.overrideWithValue(
            _FakeBlePermissionService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(bleViewModelProvider.notifier);
      await notifier.start('my-uid');

      repo.emit(
        const BleDetection(
          shortUid: 'demon1',
          rssiDbm: -60,
          detectedAtMillis: 1000,
        ),
      );
      await pumpEventQueue();

      final state = container.read(bleViewModelProvider);
      expect(state['demon1']?.rssiDbm, -60);
    });

    test('直近3件のRSSIの中央値をstateへ反映する(単発ノイズの吸収)', () async {
      final repo = _FakeBleScanRepository();
      final container = ProviderContainer(
        overrides: [
          bleScanRepositoryProvider.overrideWithValue(repo),
          blePermissionServiceProvider.overrideWithValue(
            _FakeBlePermissionService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(bleViewModelProvider.notifier);
      await notifier.start('my-uid');

      // -55 → -90(反射等による単発の外れ値) → -58 と続いても、
      // 中央値は3件目の時点で-58になり、外れ値1つに引きずられない。
      for (final rssi in [-55, -90, -58]) {
        repo.emit(
          BleDetection(
            shortUid: 'demon1',
            rssiDbm: rssi,
            detectedAtMillis: 1000,
          ),
        );
        await pumpEventQueue();
      }

      final state = container.read(bleViewModelProvider);
      expect(state['demon1']?.rssiDbm, -58);
    });

    test('4件目以降は古い値を捨てて直近3件だけで中央値を取る', () async {
      final repo = _FakeBleScanRepository();
      final container = ProviderContainer(
        overrides: [
          bleScanRepositoryProvider.overrideWithValue(repo),
          blePermissionServiceProvider.overrideWithValue(
            _FakeBlePermissionService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(bleViewModelProvider.notifier);
      await notifier.start('my-uid');

      for (final rssi in [-90, -90, -55, -56, -57]) {
        repo.emit(
          BleDetection(
            shortUid: 'demon1',
            rssiDbm: rssi,
            detectedAtMillis: 1000,
          ),
        );
        await pumpEventQueue();
      }

      // 直近3件は[-55, -56, -57] → 中央値-56。古い-90 2件はもう影響しない。
      final state = container.read(bleViewModelProvider);
      expect(state['demon1']?.rssiDbm, -56);
    });

    test('別々の相手のRSSI履歴は混ざらない', () async {
      final repo = _FakeBleScanRepository();
      final container = ProviderContainer(
        overrides: [
          bleScanRepositoryProvider.overrideWithValue(repo),
          blePermissionServiceProvider.overrideWithValue(
            _FakeBlePermissionService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(bleViewModelProvider.notifier);
      await notifier.start('my-uid');

      repo.emit(
        const BleDetection(
          shortUid: 'demon1',
          rssiDbm: -60,
          detectedAtMillis: 1000,
        ),
      );
      await pumpEventQueue();
      repo.emit(
        const BleDetection(
          shortUid: 'demon2',
          rssiDbm: -90,
          detectedAtMillis: 1000,
        ),
      );
      await pumpEventQueue();

      final state = container.read(bleViewModelProvider);
      expect(state['demon1']?.rssiDbm, -60);
      expect(state['demon2']?.rssiDbm, -90);
    });

    test('stop()で広告とスキャンを止め、stateと履歴をクリアする', () async {
      final repo = _FakeBleScanRepository();
      final container = ProviderContainer(
        overrides: [
          bleScanRepositoryProvider.overrideWithValue(repo),
          blePermissionServiceProvider.overrideWithValue(
            _FakeBlePermissionService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(bleViewModelProvider.notifier);
      await notifier.start('my-uid');
      repo.emit(
        const BleDetection(
          shortUid: 'demon1',
          rssiDbm: -60,
          detectedAtMillis: 1000,
        ),
      );
      await pumpEventQueue();

      notifier.stop();

      expect(repo.stopAdvertisingCalls, 1);
      expect(repo.stopScanningCalls, 1);
      expect(container.read(bleViewModelProvider), isEmpty);
    });

    test('start()を連続で呼んでも古い購読が残らず二重反映しない', () async {
      final repo = _FakeBleScanRepository();
      final container = ProviderContainer(
        overrides: [
          bleScanRepositoryProvider.overrideWithValue(repo),
          blePermissionServiceProvider.overrideWithValue(
            _FakeBlePermissionService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(bleViewModelProvider.notifier);

      await notifier.start('my-uid');
      await notifier.start('my-uid');

      expect(repo.startAdvertisingCalls, 2);
      expect(repo.startScanningCalls, 2);

      repo.emit(
        const BleDetection(
          shortUid: 'demon1',
          rssiDbm: -60,
          detectedAtMillis: 1000,
        ),
      );
      await pumpEventQueue();

      // 古い購読が残っていて二重に処理されると履歴が[-60, -60]になり
      // 中央値の挙動が変わってしまう。1件だけ反映されていることを確認する。
      final state = container.read(bleViewModelProvider);
      expect(state['demon1']?.rssiDbm, -60);
    });
  });

  group('BlePermissionService', () {
    test('BLUETOOTH_SCANが拒否されたら残りは要求せずfalseを返す', () async {
      final requestedPermissions = <Permission>[];
      final service = BlePermissionService(
        requestPermission: (permission) async {
          requestedPermissions.add(permission);
          return PermissionStatus.denied;
        },
      );

      final granted = await service.ensureGranted();

      expect(granted, isFalse);
      expect(requestedPermissions, [Permission.bluetoothScan]);
    });

    test('3つとも許可されたらtrueを返す', () async {
      final service = BlePermissionService(
        requestPermission: (permission) async => PermissionStatus.granted,
      );

      final granted = await service.ensureGranted();

      expect(granted, isTrue);
    });
  });
}
