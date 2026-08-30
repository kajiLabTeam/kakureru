import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/ble/model/ble_detection.dart';
import 'package:kakureru/features/ble/repository/ble_scan_repository.dart';
import 'package:kakureru/features/ble/view_model/ble_view_model.dart';

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

void main() {
  group('BleViewModel', () {
    test('start()で広告とスキャンの両方を始める', () {
      final repo = _FakeBleScanRepository();
      final container = ProviderContainer(
        overrides: [bleScanRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(bleViewModelProvider.notifier);

      notifier.start('my-uid');

      expect(repo.startAdvertisingCalls, 1);
      expect(repo.startScanningCalls, 1);
    });

    test('検知結果を受け取ると短縮uidをキーにstateへ反映する', () async {
      final repo = _FakeBleScanRepository();
      final container = ProviderContainer(
        overrides: [bleScanRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(bleViewModelProvider.notifier);
      notifier.start('my-uid');

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

    test('同じ相手の新しい検知結果は古い値を上書きする', () async {
      final repo = _FakeBleScanRepository();
      final container = ProviderContainer(
        overrides: [bleScanRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(bleViewModelProvider.notifier);
      notifier.start('my-uid');

      repo.emit(
        const BleDetection(
          shortUid: 'demon1',
          rssiDbm: -80,
          detectedAtMillis: 1000,
        ),
      );
      await pumpEventQueue();
      repo.emit(
        const BleDetection(
          shortUid: 'demon1',
          rssiDbm: -50,
          detectedAtMillis: 2000,
        ),
      );
      await pumpEventQueue();

      final state = container.read(bleViewModelProvider);
      expect(state['demon1']?.rssiDbm, -50);
      expect(state.length, 1);
    });

    test('stop()で広告とスキャンを止め、stateをクリアする', () async {
      final repo = _FakeBleScanRepository();
      final container = ProviderContainer(
        overrides: [bleScanRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(bleViewModelProvider.notifier);
      notifier.start('my-uid');
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
  });
}
