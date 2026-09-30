import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/ble/model/ble_detection.dart';
import 'package:kakureru/features/ble/repository/ble_permission.dart';
import 'package:kakureru/features/ble/repository/ble_scan_repository.dart';

/// BLEのリポジトリ。アプリ生存期間のシングルトンとして扱う。
///
/// 画面ごとの開始/停止は[BleViewModel]の start()/stop() が行い、
/// [BleScanRepository.dispose]は内部のStreamControllerまで閉じるため、
/// Providerが破棄されるとき(=アプリ終了時)にだけ呼ぶ。
/// 以前はdisposeの呼び出し経路自体が無くデッドコードになっていた
/// (issue #30)。
final bleScanRepositoryProvider = Provider((ref) {
  final repository = BleScanRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final blePermissionServiceProvider = Provider((ref) => BlePermissionService());

/// 直近のRSSI(dBm)を何件保持して中央値を取るか。BLEの単発RSSIは反射等で
/// 数dB〜十数dB振れることがあるため、単発の値だけで「3m以内」と即断すると
/// 誤検知しやすい(鬼の「捕まえた」ボタンを押せるかどうかに使うため)。
const _rssiWindowSize = 3;

/// 張り直し([BleViewModel.restart])を続けて行わない間隔。Androidはスキャンの
/// 開始が30秒に5回までで、超えるとスキャンが黙って失敗する(エラーも
/// 結果も返らない)ため、画面のON/OFFを繰り返しても超えないようにする。
const bleRestartMinInterval = Duration(seconds: 10);

/// 動いている間、この間隔で張り直す。Androidは30分を超えて続けたスキャンを
/// 弱いモード(opportunistic。他のアプリがスキャンしたときしか結果が来ない)
/// に落とすため、ゲーム(放出後30分)の終盤で相手が見えなくならないように
/// その前に張り直す。
const blePeriodicRestartInterval = Duration(minutes: 10);

/// 短縮uid→直近のBLE検知結果。継続的にストリームから更新されるため、
/// Wi-Fiの導出Providerとは違いNotifierで状態として持つ(Pressureと同じ方針)。
class BleViewModel extends Notifier<Map<String, BleDetection>> {
  @override
  Map<String, BleDetection> build() {
    ref.onDispose(() => _periodicRestart?.cancel());
    return const {};
  }

  StreamSubscription<BleDetection>? _sub;
  final Map<String, List<int>> _rssiHistory = {};

  /// start()/stop()の呼び出し世代を追うためのカウンタ。権限要求のawait中に
  /// stop()で追い越されていたら、権限が下りた後でも広告・スキャンを
  /// 始めない(LocationViewModelと同じ方針)。
  int _epoch = 0;

  /// 広告しているuid。[start]で権限が下りた後に入り、[stop]で消える。
  /// nullの間は動いていない([restart]は何もしない)。
  String? _myUid;

  /// 最後に張り直した(または開始した)時からの経過。`clock`経由なので
  /// テストの`fakeAsync`で進められる。
  Stopwatch? _sinceRestart;

  /// [blePeriodicRestartInterval]ごとに[restart]するタイマー。
  Timer? _periodicRestart;

  BleScanRepository get _repo => ref.read(bleScanRepositoryProvider);

  /// ゲーム画面に入った時に呼ぶ。権限を確認できたら、自分のuidの広告と
  /// 相手の広告のスキャンを両方始める。
  Future<void> start(String myUid) async {
    final epoch = ++_epoch;
    final granted = await ref
        .read(blePermissionServiceProvider)
        .ensureGranted();
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
    _myUid = myUid;
    _sinceRestart = clock.stopwatch()..start();
    _periodicRestart?.cancel();
    _periodicRestart = Timer.periodic(
      blePeriodicRestartInterval,
      (_) => restart(),
    );
  }

  /// 動いている間だけ、スキャンと広告を止めてから始め直す。
  ///
  /// ゲーム画面に入ったときに1回始めるだけだと、撮影(外部のカメラアプリ)
  /// でアプリが裏に回ったときなどにAndroid側でスキャン・広告が止まっても
  /// 戻らない。鬼が1人目を捕まえて写真を撮った後、2人目に近づいても
  /// 「捕まえた」が押せなかった(スキャンが止まっていた)。逃走者も足元の
  /// 写真を撮るので、広告が止まって鬼から見えなくなる経路も同じ。
  ///
  /// 検知の履歴と状態は消さない(直前の検知は数秒は有効なので、押せる状態を
  /// 張り直しのたびに一瞬消さない)。[bleRestartMinInterval]以内に続けて
  /// 呼ばれたら何もしない。
  void restart() {
    final uid = _myUid;
    final since = _sinceRestart;
    if (uid == null || since == null) return;
    if (since.elapsed < bleRestartMinInterval) return;
    since.reset();
    debugPrint('[BleViewModel] スキャンと広告を張り直します');
    // startScanning()は先頭で前のスキャンを止めてから始める。
    _repo.startScanning();
    final epoch = _epoch;
    Future<void> restartAdvertising() async {
      await _repo.stopAdvertising();
      // 止めている間にstop()された(ゲーム画面を離れた)ら始めない。
      if (epoch != _epoch) return;
      await _repo.startAdvertising(uid);
    }

    unawaited(restartAdvertising());
  }

  /// ゲーム画面を離れる時に呼ぶ。
  void stop() {
    _epoch++;
    _myUid = null;
    _sinceRestart = null;
    _periodicRestart?.cancel();
    _periodicRestart = null;
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

final bleViewModelProvider =
    NotifierProvider<BleViewModel, Map<String, BleDetection>>(
      BleViewModel.new,
    );
