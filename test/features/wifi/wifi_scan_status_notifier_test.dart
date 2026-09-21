import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/wifi/model/wifi_scan_status.dart';
import 'package:kakureru/features/wifi/repository/wifi_scan_repository.dart';
import 'package:kakureru/features/wifi/view_model/wifi_view_model.dart';

/// Wi-Fiプラグインを触らずに、スキャン要求の結果だけをテストから決める
/// リポジトリの差し替え。
///
/// `WifiScanRepository`のFirebaseハンドルは遅延初期化なので、このサブクラスが
/// 暗黙の`super()`を通っても`.instance`は解決されない(Firebase未初期化でも
/// インスタンス化できる)。
class _FakeWifiScanRepository extends WifiScanRepository {
  _FakeWifiScanRepository({this.result = WifiScanStatus.ok, this.error});

  WifiScanStatus result;
  Exception? error;
  int triggerCalls = 0;

  /// 結果を返すタイミングをテストから制御したいときに使う。
  Completer<void>? gate;

  @override
  Future<WifiScanStatus> triggerScan() async {
    triggerCalls++;
    await gate?.future;
    final e = error;
    if (e != null) throw e;
    return result;
  }
}

ProviderContainer _container(_FakeWifiScanRepository repo) {
  final container = ProviderContainer(
    overrides: [wifiScanRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('WifiScanStatusNotifier', () {
    test('初期状態はchecking', () {
      final container = _container(_FakeWifiScanRepository());
      expect(container.read(wifiScanStatusProvider), WifiScanStatus.checking);
    });

    test('スキャンできればokになる', () async {
      final repo = _FakeWifiScanRepository();
      final container = _container(repo);

      await container.read(wifiScanStatusProvider.notifier).refresh();

      expect(container.read(wifiScanStatusProvider), WifiScanStatus.ok);
      expect(repo.triggerCalls, 1);
    });

    test('スロットル中ならthrottledがそのまま状態になる', () async {
      final repo = _FakeWifiScanRepository(result: WifiScanStatus.throttled);
      final container = _container(repo);

      await container.read(wifiScanStatusProvider.notifier).refresh();

      expect(container.read(wifiScanStatusProvider), WifiScanStatus.throttled);
    });

    test('確認中はcheckingに戻る(前の結果が残り続けない)', () async {
      final repo = _FakeWifiScanRepository(result: WifiScanStatus.throttled);
      final container = _container(repo);
      await container.read(wifiScanStatusProvider.notifier).refresh();
      expect(container.read(wifiScanStatusProvider), WifiScanStatus.throttled);

      repo
        ..result = WifiScanStatus.ok
        ..gate = Completer<void>();
      final refreshing = container
          .read(wifiScanStatusProvider.notifier)
          .refresh();
      expect(container.read(wifiScanStatusProvider), WifiScanStatus.checking);

      repo.gate!.complete();
      await refreshing;
      expect(container.read(wifiScanStatusProvider), WifiScanStatus.ok);
    });

    test('プラグインが例外を投げてもfailedとして表示できる(確認中で固まらない)', () async {
      final repo = _FakeWifiScanRepository(error: Exception('plugin error'));
      final container = _container(repo);

      await container.read(wifiScanStatusProvider.notifier).refresh();

      expect(container.read(wifiScanStatusProvider), WifiScanStatus.failed);
    });

    test('確認中に再度呼ばれても、スキャン要求は1回にまとめる', () async {
      final repo = _FakeWifiScanRepository()..gate = Completer<void>();
      final container = _container(repo);
      final notifier = container.read(wifiScanStatusProvider.notifier);

      // 画面のマウントと「再確認」の連打が重なった状況。
      final first = notifier.refresh();
      final second = notifier.refresh();
      expect(repo.triggerCalls, 1);

      repo.gate!.complete();
      await Future.wait([first, second]);

      expect(repo.triggerCalls, 1);
      expect(container.read(wifiScanStatusProvider), WifiScanStatus.ok);
    });

    test('1回目が終われば2回目は実際に確認し直す', () async {
      final repo = _FakeWifiScanRepository(
        result: WifiScanStatus.locationServiceDisabled,
      );
      final container = _container(repo);
      final notifier = container.read(wifiScanStatusProvider.notifier);

      await notifier.refresh();
      expect(
        container.read(wifiScanStatusProvider),
        WifiScanStatus.locationServiceDisabled,
      );

      // 設定で位置情報をONにして戻ってきて「再確認」を押した状況。
      repo.result = WifiScanStatus.ok;
      await notifier.refresh();

      expect(repo.triggerCalls, 2);
      expect(container.read(wifiScanStatusProvider), WifiScanStatus.ok);
    });

    test('確認中に画面を離れても(providerが破棄されても)例外にならない', () async {
      final repo = _FakeWifiScanRepository()..gate = Completer<void>();
      // このテストだけは自分でdisposeするので、_container(後片付け付き)は使わない。
      final container = ProviderContainer(
        overrides: [wifiScanRepositoryProvider.overrideWithValue(repo)],
      );

      final refreshing = container
          .read(wifiScanStatusProvider.notifier)
          .refresh();
      container.dispose();
      repo.gate!.complete();

      await expectLater(refreshing, completes);
    });
  });
}
