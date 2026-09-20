import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
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

  @override
  Stream<double> watchMyPressure() => const Stream<double>.empty();
}

ProviderContainer _container(_FakePressureRepository repo) {
  final container = ProviderContainer(
    overrides: [pressureRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
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
  });
}
