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
