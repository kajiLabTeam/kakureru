import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/ble/model/ble_detection.dart';
import 'package:kakureru/features/ble/repository/ble_scan_repository.dart';

final bleScanRepositoryProvider = Provider((ref) => BleScanRepository());

/// 短縮uid→直近のBLE検知結果。継続的にストリームから更新されるため、
/// Wi-Fiの導出Providerとは違いNotifierで状態として持つ(Pressureと同じ方針)。
class BleViewModel extends Notifier<Map<String, BleDetection>> {
  @override
  Map<String, BleDetection> build() => const {};

  StreamSubscription<BleDetection>? _sub;

  BleScanRepository get _repo => ref.read(bleScanRepositoryProvider);

  /// ゲーム画面に入った時に呼ぶ。自分のuidの広告と、相手の広告のスキャンを
  /// 両方始める。
  void start(String myUid) {
    _sub?.cancel();
    _sub = _repo.detections.listen((detection) {
      state = {...state, detection.shortUid: detection};
    });
    unawaited(_repo.startAdvertising(myUid));
    _repo.startScanning();
  }

  /// ゲーム画面を離れる時に呼ぶ。
  void stop() {
    _sub?.cancel();
    _sub = null;
    _repo.stopScanning();
    unawaited(_repo.stopAdvertising());
    state = const {};
  }
}

final bleViewModelProvider = NotifierProvider<BleViewModel, Map<String, BleDetection>>(
  BleViewModel.new,
);
