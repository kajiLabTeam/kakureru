import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/ble/model/ble_detection.dart';
import 'package:kakureru/features/ble/repository/ble_permission.dart';
import 'package:kakureru/features/ble/repository/ble_scan_repository.dart';

final bleScanRepositoryProvider = Provider((ref) => BleScanRepository());

final blePermissionServiceProvider = Provider((ref) => BlePermissionService());

/// 直近のRSSI(dBm)を何件保持して中央値を取るか。BLEの単発RSSIは反射等で
/// 数dB〜十数dB振れることがあるため、単発の値だけで「3m以内」と即断すると
/// 誤検知しやすい(押すと取り消せないreportCaughtにつながるボタンのため)。
const _rssiWindowSize = 3;

/// 短縮uid→直近のBLE検知結果。継続的にストリームから更新されるため、
/// Wi-Fiの導出Providerとは違いNotifierで状態として持つ(Pressureと同じ方針)。
class BleViewModel extends Notifier<Map<String, BleDetection>> {
  @override
  Map<String, BleDetection> build() => const {};

  StreamSubscription<BleDetection>? _sub;
  final Map<String, List<int>> _rssiHistory = {};

  /// start()/stop()の呼び出し世代を追うためのカウンタ。権限要求のawait中に
  /// stop()で追い越されていたら、権限が下りた後でも広告・スキャンを
  /// 始めない(LocationViewModelと同じ方針)。
  int _epoch = 0;

  BleScanRepository get _repo => ref.read(bleScanRepositoryProvider);

  /// ゲーム画面に入った時に呼ぶ。権限を確認できたら、自分のuidの広告と
  /// 相手の広告のスキャンを両方始める。
  Future<void> start(String myUid) async {
    final epoch = ++_epoch;
    final granted = await ref.read(blePermissionServiceProvider).ensureGranted();
    if (epoch != _epoch || !granted) return;

    _sub?.cancel();
    _rssiHistory.clear();
    _sub = _repo.detections.listen((detection) {
      final history = _rssiHistory.putIfAbsent(detection.shortUid, () => []);
      history.add(detection.rssiDbm);
      if (history.length > _rssiWindowSize) history.removeAt(0);
      state = {
        ...state,
        detection.shortUid: detection.copyWith(rssiDbm: _median(history)),
      };
    });
    unawaited(_repo.startAdvertising(myUid));
    _repo.startScanning();
  }

  /// ゲーム画面を離れる時に呼ぶ。
  void stop() {
    _epoch++;
    _sub?.cancel();
    _sub = null;
    _rssiHistory.clear();
    _repo.stopScanning();
    unawaited(_repo.stopAdvertising());
    state = const {};
  }
}

int _median(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

final bleViewModelProvider = NotifierProvider<BleViewModel, Map<String, BleDetection>>(
  BleViewModel.new,
);
