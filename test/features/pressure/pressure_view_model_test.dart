import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/pressure/model/calibration_failure.dart';
import 'package:kakureru/features/pressure/model/pressure_sensor_availability.dart';
import 'package:kakureru/features/pressure/repository/pressure_repository.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';

/// センサー・RTDBを触らずに、呼ばれた回数だけ数えるリポジトリ。
///
/// [checkSensorAvailable]は実機では最大3秒のタイムアウトを待つ処理なので、
/// 「判定済みなら二度と呼ばれない」ことがそのまま待ち時間の削減になる。
class _FakePressureRepository extends PressureRepository {
  _FakePressureRepository({required this.available});

  final bool available;
  int checkCalls = 0;
  int watchCalls = 0;
  final List<bool> reported = [];

  /// 判定の完了をテストから制御したいときに使う(同時呼び出しの検証用)。
  Completer<void>? gate;

  @override
  Future<bool> checkSensorAvailable({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    checkCalls++;
    await gate?.future;
    return available;
  }

  @override
  Future<void> reportSensorAvailability(
    String roomId, {
    required bool available,
  }) async {
    reported.add(available);
  }

  /// 気圧センサーの値。既定では1件も流れない(取得できていない状態)。
  Stream<double> pressureStream = const Stream<double>.empty();

  @override
  Stream<double> watchMyPressure() {
    watchCalls++;
    return pressureStream;
  }

  /// キャリブレーション時に投げさせたい例外(nullなら成功する)。
  Object? calibrateError;
  final List<double> calibratedBasePressures = [];
  final List<double> calibratedOffsetSources = [];

  @override
  Future<void> calibrateAsHost(String roomId, double myPressureHPa) async {
    final error = calibrateError;
    if (error != null) throw error;
    calibratedBasePressures.add(myPressureHPa);
  }

  @override
  Future<void> calibrateAsParticipant(
    String roomId,
    double myPressureHPa,
    double basePressureHPa,
  ) async {
    final error = calibrateError;
    if (error != null) throw error;
    calibratedOffsetSources.add(myPressureHPa - basePressureHPa);
  }
}

ProviderContainer _container(_FakePressureRepository repo) {
  final container = ProviderContainer(
    overrides: [pressureRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

/// センサーの購読を始め、気圧が1件届いたところまで進めたViewModelを返す。
Future<PressureViewModel> readyNotifier(
  ProviderContainer container,
  _FakePressureRepository repo,
) async {
  repo.pressureStream = Stream<double>.value(1013);
  final notifier = container.read(pressureViewModelProvider.notifier);
  await notifier.init('room1');
  // watchMyPressureの1件目が状態に反映されるまで待つ。
  await pumpEventQueue();
  expect(container.read(pressureViewModelProvider).myPressureHPa, 1013);
  return notifier;
}

void main() {
  group('PressureViewModel.init', () {
    // 9/24のプレイテストで、2回目のゲームでは初参加の1人しか気圧を
    // 送れていなかった(issue #121)。ゲーム画面を離れるとセンサー購読を
    // 止めるのに、判定済みの2回目以降のinitが購読を張り直していなかった。
    test('ゲーム画面を離れた後に入り直すと、センサーの購読を張り直す', () async {
      final repo = _FakePressureRepository(available: true);
      final container = _container(repo);
      final notifier = await readyNotifier(container, repo);
      expect(repo.watchCalls, 1);

      notifier.stopSendingAndDispose();
      repo.pressureStream = Stream<double>.value(1000);
      await notifier.init('room2');
      await pumpEventQueue();

      expect(repo.watchCalls, 2);
      expect(container.read(pressureViewModelProvider).myPressureHPa, 1000);
      // 判定は済んでいるので、センサーの有無は調べ直さない。
      expect(repo.checkCalls, 1);
    });

    // Copilotのレビュー指摘(PR #125)。「もう一回」でゲーム画面から待機
    // 画面へ戻るとき、古いゲーム画面は新しい待機画面より後に破棄される。
    // そこで購読を止めると、待機画面は購読の無いまま残っていた。
    test('ゲーム画面が待機画面より後に離れても、待機画面の購読は止めない', () async {
      final repo = _FakePressureRepository(available: true);
      final controller = StreamController<double>.broadcast();
      addTearDown(controller.close);
      repo.pressureStream = controller.stream;
      final container = _container(repo);
      final notifier = container.read(pressureViewModelProvider.notifier);

      // ゲーム画面が気圧を使っている。
      await notifier.init('room1');
      // 待機画面が開く(ゲーム画面はまだ破棄されていない)。
      await notifier.init('room1');
      // 遅れてゲーム画面が破棄される。
      notifier.stopSendingAndDispose();

      controller.add(1005);
      await pumpEventQueue();
      expect(container.read(pressureViewModelProvider).myPressureHPa, 1005);
      expect(repo.watchCalls, 1);
    });

    test('気圧を使う画面が全部離れたら、購読を止める', () async {
      final repo = _FakePressureRepository(available: true);
      final container = _container(repo);
      final notifier = await readyNotifier(container, repo);

      // readyNotifierのinit(待機画面)に加えてゲーム画面もinitする。
      await notifier.init('room1');
      notifier.stopSendingAndDispose();
      expect(container.read(pressureViewModelProvider).myPressureHPa, 1013);

      // 待機画面も離れる。
      notifier.release();
      expect(container.read(pressureViewModelProvider).myPressureHPa, isNull);
    });

    test('initしていない画面のreleaseは何もしない', () async {
      final repo = _FakePressureRepository(available: true);
      final container = _container(repo);
      final notifier = await readyNotifier(container, repo);

      notifier
        ..release()
        ..release();

      // 1回目のreleaseで止まり、2回目は数が負にならず何も起きない。
      repo.pressureStream = Stream<double>.value(1000);
      await notifier.init('room1');
      expect(repo.watchCalls, 2);
      notifier.release();
      expect(container.read(pressureViewModelProvider).myPressureHPa, isNull);
    });

    test('購読中に何度initしても、購読は1本だけ', () async {
      final repo = _FakePressureRepository(available: true);
      final container = _container(repo);
      final notifier = await readyNotifier(container, repo);

      // 待機画面→ゲーム画面の遷移で続けて呼ばれる状況。
      await notifier.init('room1');
      await notifier.init('room1');

      expect(repo.watchCalls, 1);
    });

    test('ゲーム画面を離れたら、古い気圧の値を捨てる', () async {
      final repo = _FakePressureRepository(available: true);
      final container = _container(repo);
      final notifier = await readyNotifier(container, repo);

      notifier.stopSendingAndDispose();

      // 残すと、止まったセンサーの古い値でキャリブレーションが通ってしまう。
      expect(container.read(pressureViewModelProvider).myPressureHPa, isNull);
      expect(
        container.read(pressureViewModelProvider).sensorAvailability,
        PressureSensorAvailability.available,
      );
    });

    test('センサー非搭載なら、入り直しても判定も購読もしない', () async {
      final repo = _FakePressureRepository(available: false);
      final container = _container(repo);
      final notifier = container.read(pressureViewModelProvider.notifier);

      await notifier.init('room1');
      notifier.stopSendingAndDispose();
      await notifier.init('room2');

      expect(repo.checkCalls, 1);
      expect(repo.watchCalls, 0);
    });

    test('センサー非搭載なら、2回目以降は再判定しない', () async {
      final repo = _FakePressureRepository(available: false);
      final container = _container(repo);
      final notifier = container.read(pressureViewModelProvider.notifier);

      await notifier.init('room1');
      expect(
        container.read(pressureViewModelProvider).sensorAvailability,
        PressureSensorAvailability.unavailable,
      );
      expect(repo.checkCalls, 1);

      // 待機画面→ゲーム画面の遷移で再度呼ばれる状況。以前はunavailableの
      // ときガードが効かず、最大3秒のタイムアウトを待ち直していた。
      await notifier.init('room1');
      expect(repo.checkCalls, 1);
    });

    test('センサー搭載でも、2回目以降は再判定しない', () async {
      final repo = _FakePressureRepository(available: true);
      final container = _container(repo);
      final notifier = container.read(pressureViewModelProvider.notifier);

      await notifier.init('room1');
      await notifier.init('room1');
      expect(repo.checkCalls, 1);
    });

    test('判定済みでも、RTDBへの記録は呼ぶたびに行う(ルームごとに要るため)', () async {
      final repo = _FakePressureRepository(available: false);
      final container = _container(repo);
      final notifier = container.read(pressureViewModelProvider.notifier);

      await notifier.init('room1');
      await notifier.init('room2');

      expect(repo.reported, [false, false]);
    });

    test('判定中に二重に呼ばれても、判定は1回にまとめる', () async {
      final repo = _FakePressureRepository(available: true)
        ..gate = Completer<void>();
      final container = _container(repo);
      final notifier = container.read(pressureViewModelProvider.notifier);

      // 待機画面とゲーム画面が一瞬同時にマウントされる遷移中の状況。
      final first = notifier.init('room1');
      final second = notifier.init('room1');
      expect(repo.checkCalls, 1);

      repo.gate!.complete();
      await Future.wait([first, second]);

      expect(repo.checkCalls, 1);
      expect(
        container.read(pressureViewModelProvider).sensorAvailability,
        PressureSensorAvailability.available,
      );
    });

    // センサーの有無の判定は実機で最大3秒かかる。その間にゲーム画面を離れる
    // と、以前は待ちが明けた後にセンサー購読が始まり、**それを止める人が
    // もう居ない**状態で残っていた(画面を離れてもセンサーが止まらない、
    // issue #93と同じ症状)。
    test('判定を待っている間に画面を離れたら、センサー購読を始めない', () async {
      final repo = _FakePressureRepository(available: true)
        ..gate = Completer<void>();
      final container = _container(repo);
      final notifier = container.read(pressureViewModelProvider.notifier);

      final initializing = notifier.init('room1');
      notifier.stopSendingAndDispose();
      repo.gate!.complete();
      await initializing;

      expect(repo.watchCalls, 0);
      // ローカルの判定結果も残さない。残すと次にゲームへ入ったとき再判定が走らず、
      // 購読が始まらないまま気圧が永久に取れなくなる。
      expect(
        container.read(pressureViewModelProvider).sensorAvailability,
        PressureSensorAvailability.checking,
      );
    });

    // CodeRabbitのレビュー指摘(PR #125)。判定中に離れてすぐ入り直すと、
    // 新しいinitが古い判定(離脱で無効になったもの)に相乗りし、状態が
    // checkingのまま購読も始まらなかった。
    test('判定中に画面を離れてすぐ入り直しても、新しい判定で購読を始める', () async {
      final repo = _FakePressureRepository(available: true)
        ..gate = Completer<void>();
      final container = _container(repo);
      final notifier = container.read(pressureViewModelProvider.notifier);

      final first = notifier.init('room1');
      notifier.stopSendingAndDispose();
      final second = notifier.init('room1');
      // 古い判定には相乗りせず、判定をやり直す。
      expect(repo.checkCalls, 2);

      repo.gate!.complete();
      await Future.wait([first, second]);

      expect(
        container.read(pressureViewModelProvider).sensorAvailability,
        PressureSensorAvailability.available,
      );
      expect(repo.watchCalls, 1);
    });

    test('古い判定が後から終わっても、進行中の新しい判定を忘れない', () async {
      final repo = _FakePressureRepository(available: true)
        ..gate = Completer<void>();
      final container = _container(repo);
      final notifier = container.read(pressureViewModelProvider.notifier);

      final first = notifier.init('room1');
      notifier.stopSendingAndDispose();
      final oldGate = repo.gate!;
      repo.gate = Completer<void>();
      final second = notifier.init('room1');

      // 古い判定だけ先に終わる。
      oldGate.complete();
      await first;

      // 新しい判定はまだ進行中なので、ここで呼ばれたinitは相乗りする。
      final third = notifier.init('room1');
      expect(repo.checkCalls, 2);

      repo.gate!.complete();
      await Future.wait([second, third]);
      expect(repo.watchCalls, 1);
    });

    test('画面を離れた後でも、入り直せば判定と購読をやり直す', () async {
      final repo = _FakePressureRepository(available: true)
        ..gate = Completer<void>();
      final container = _container(repo);
      final notifier = container.read(pressureViewModelProvider.notifier);

      final initializing = notifier.init('room1');
      notifier.stopSendingAndDispose();
      repo.gate!.complete();
      await initializing;

      repo.gate = null;
      await notifier.init('room1');

      expect(repo.checkCalls, 2);
      expect(repo.watchCalls, 1);
      expect(
        container.read(pressureViewModelProvider).sensorAvailability,
        PressureSensorAvailability.available,
      );
    });
  });

  group('PressureViewModel.calibrate (失敗を状態に残す)', () {
    test('ホスト: 気圧がまだ無ければnoPressureを残す', () async {
      final repo = _FakePressureRepository(available: true);
      final container = _container(repo);

      // myPressureHPaがnullのまま(センサーの値が1件も来ていない)。
      await container
          .read(pressureViewModelProvider.notifier)
          .calibrateAsHost('room1');

      final state = container.read(pressureViewModelProvider);
      expect(state.calibrationFailure, CalibrationFailure.noPressure);
      expect(state.isCalibrating, isFalse);
      expect(repo.calibratedBasePressures, isEmpty);
    });

    test('ホスト: 書き込みが失敗したらwriteFailedを残し、例外は投げない', () async {
      final repo = _FakePressureRepository(available: true)
        ..calibrateError = Exception('RTDBの失敗を模擬');
      final container = _container(repo);

      final notifier = await readyNotifier(container, repo);
      await notifier.calibrateAsHost('room1');

      final state = container.read(pressureViewModelProvider);
      expect(state.calibrationFailure, CalibrationFailure.writeFailed);
      expect(state.isCalibrating, isFalse);
    });

    test('ホスト: 成功すれば失敗は残らない', () async {
      final repo = _FakePressureRepository(available: true);
      final container = _container(repo);

      final notifier = await readyNotifier(container, repo);
      await notifier.calibrateAsHost('room1');

      final state = container.read(pressureViewModelProvider);
      expect(state.calibrationFailure, CalibrationFailure.none);
      expect(repo.calibratedBasePressures, [1013]);
    });

    test('ホスト: 一度失敗しても、やり直して成功すれば失敗は消える', () async {
      final repo = _FakePressureRepository(available: true)
        ..calibrateError = Exception('RTDBの失敗を模擬');
      final container = _container(repo);
      final notifier = await readyNotifier(container, repo);

      await notifier.calibrateAsHost('room1');
      expect(
        container.read(pressureViewModelProvider).calibrationFailure,
        CalibrationFailure.writeFailed,
      );

      repo.calibrateError = null;
      await notifier.calibrateAsHost('room1');

      expect(
        container.read(pressureViewModelProvider).calibrationFailure,
        CalibrationFailure.none,
      );
    });

    test('参加者: 気圧がまだ無ければnoPressureを残す', () async {
      final repo = _FakePressureRepository(available: true);
      final container = _container(repo);

      await container
          .read(pressureViewModelProvider.notifier)
          .calibrateAsParticipant('room1', 1013);

      expect(
        container.read(pressureViewModelProvider).calibrationFailure,
        CalibrationFailure.noPressure,
      );
    });

    test('参加者: ホストの基準値がまだ無ければnoBasePressureを残す', () async {
      final repo = _FakePressureRepository(available: true);
      final container = _container(repo);

      final notifier = await readyNotifier(container, repo);
      await notifier.calibrateAsParticipant('room1', null);

      expect(
        container.read(pressureViewModelProvider).calibrationFailure,
        CalibrationFailure.noBasePressure,
      );
      expect(repo.calibratedOffsetSources, isEmpty);
    });

    test('参加者: 書き込みが失敗したらwriteFailedを残し、例外は投げない', () async {
      final repo = _FakePressureRepository(available: true)
        ..calibrateError = Exception('RTDBの失敗を模擬');
      final container = _container(repo);

      final notifier = await readyNotifier(container, repo);
      await notifier.calibrateAsParticipant('room1', 1010);

      final state = container.read(pressureViewModelProvider);
      expect(state.calibrationFailure, CalibrationFailure.writeFailed);
      expect(state.isCalibrating, isFalse);
    });

    test('参加者: 成功すれば失敗は残らない', () async {
      final repo = _FakePressureRepository(available: true);
      final container = _container(repo);

      final notifier = await readyNotifier(container, repo);
      await notifier.calibrateAsParticipant('room1', 1010);

      expect(
        container.read(pressureViewModelProvider).calibrationFailure,
        CalibrationFailure.none,
      );
      expect(repo.calibratedOffsetSources, [closeTo(3, 0.0001)]);
    });
  });

  group('PressureViewModel.clearCalibrationFailure', () {
    test('別のルームに入り直したときに、前の失敗表示を持ち越さない', () async {
      final repo = _FakePressureRepository(available: true)
        ..calibrateError = Exception('write failed');
      final container = _container(repo);
      final notifier = await readyNotifier(container, repo);

      await notifier.calibrateAsHost('room1');
      expect(
        container.read(pressureViewModelProvider).calibrationFailure,
        CalibrationFailure.writeFailed,
      );

      notifier.clearCalibrationFailure();

      expect(
        container.read(pressureViewModelProvider).calibrationFailure,
        CalibrationFailure.none,
      );
    });

    test('失敗していなければ何も変えない', () async {
      final repo = _FakePressureRepository(available: true);
      final container = _container(repo);
      final notifier = await readyNotifier(container, repo);
      final before = container.read(pressureViewModelProvider);

      notifier.clearCalibrationFailure();

      expect(container.read(pressureViewModelProvider), before);
    });
  });

  group('calibrationFailureMessage', () {
    test('失敗していなければ文言は出さない', () {
      expect(calibrationFailureMessage(CalibrationFailure.none), isNull);
    });

    test('理由ごとに、次に何をすればよいかが分かる文言を返す', () {
      expect(
        calibrationFailureMessage(CalibrationFailure.noPressure),
        contains('気圧'),
      );
      expect(
        calibrationFailureMessage(CalibrationFailure.noBasePressure),
        contains('ホスト'),
      );
      expect(
        calibrationFailureMessage(CalibrationFailure.writeFailed),
        contains('もう一度'),
      );
    });

    test('none以外は必ず文言がある', () {
      for (final failure in CalibrationFailure.values) {
        if (failure == CalibrationFailure.none) continue;
        expect(
          calibrationFailureMessage(failure),
          isNotEmpty,
          reason: '$failure',
        );
      }
    });
  });
}
