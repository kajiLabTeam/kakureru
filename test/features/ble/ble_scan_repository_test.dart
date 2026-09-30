import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/ble/repository/ble_proximity_calculator.dart';
import 'package:kakureru/features/ble/repository/ble_scan_repository.dart';
import 'package:kakureru/features/ble/view_model/ble_view_model.dart';

/// 広告の停止(flutter_ble_peripheral)はプラグインの実装が要るため、
/// テストではメソッドチャネルを差し替えて「成功した」ことにする。
/// これをしないと dispose 内の stopAdvertising が
/// MissingPluginException を投げ、テスト完了後の未処理例外になる。
const _peripheralChannel = MethodChannel(
  'dev.steenbakker.flutter_ble_peripheral/ble_state',
);

void main() {
  // プラグインの静的メソッド(FlutterBluePlus.stopScan等)を呼ぶため、
  // バインディングを先に立てる。スキャンを始めていない状態のstopScanは
  // 「already stopped」で素通りするので、実機なしでも通る。
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_peripheralChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_peripheralChannel, null);
  });

  group('bleScanRepositoryProvider', () {
    // BleScanRepository.dispose() は定義されているのにどこからも呼ばれず
    // デッドコードになっていた(issue #30)。Providerの破棄に繋いだので、
    // その配線が外れていないことをここで担保する。
    test('Providerを破棄すると、検知ストリームが閉じる', () async {
      final container = ProviderContainer();
      final repository = container.read(bleScanRepositoryProvider);
      final closed = expectLater(repository.detections, emitsDone);

      container.dispose();
      await closed;
      // 破棄の中で走る非同期処理(広告停止)が例外を投げていないことも
      // ここで確かめる(投げるとテスト完了後の未処理例外になる)。
      await Future<void>.delayed(Duration.zero);
    });

    test('破棄していない間は、検知ストリームは開いたまま', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repository = container.read(bleScanRepositoryProvider);

      var done = false;
      repository.detections.listen(null, onDone: () => done = true);
      await Future<void>.delayed(Duration.zero);

      expect(done, isFalse);
    });
  });

  group('freshDetections(スキャン結果の累積リストから流す検知を作る)', () {
    BleScanSample sample(String uid, {required int at, int rssi = -60}) => (
      payload: encodeAdvertisePayload(uid),
      rssi: rssi,
      receivedAtMillis: at,
    );

    test('時刻は「いま」ではなく、その相手を実際に受信した時刻にする', () {
      final detections = freshDetections([
        sample('mana', at: 1000),
      ], lastEmittedAtMillis: {});
      expect(detections.single.detectedAtMillis, 1000);
    });

    test('圏外に出た相手は、ほかの相手の受信で累積リストが流れても新しくならない', () {
      final last = <String, int>{};
      freshDetections([sample('mana', at: 1000)], lastEmittedAtMillis: last);

      // 10秒後、近くの鬼(oni)の広告を受け取ったので累積リストが流れてきた。
      // manaは1000のあと受信していない。
      final detections = freshDetections([
        sample('mana', at: 1000),
        sample('oni', at: 11000),
      ], lastEmittedAtMillis: last);

      expect(detections.map((d) => d.shortUid), ['oni']);
      expect(
        isDetectionFresh(detectedAtMillis: 1000, nowMillis: 11000),
        isFalse,
        reason: '流さなければ、manaの検知は1000のまま古くなる',
      );
    });

    test('同じ相手をもう一度受信したら流す', () {
      final last = <String, int>{};
      freshDetections([sample('mana', at: 1000)], lastEmittedAtMillis: last);
      final detections = freshDetections([
        sample('mana', at: 2000, rssi: -55),
      ], lastEmittedAtMillis: last);
      expect(detections.single.detectedAtMillis, 2000);
      expect(detections.single.rssiDbm, -55);
    });

    test('自分たちの広告でない・読めないものは捨てる', () {
      final detections = freshDetections([
        (payload: null, rssi: -60, receivedAtMillis: 1000),
        (payload: const [0xff, 0xfe], rssi: -60, receivedAtMillis: 1000),
      ], lastEmittedAtMillis: {});
      expect(detections, isEmpty);
    });
  });
}
