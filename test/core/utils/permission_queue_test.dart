import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/core/utils/permission_queue.dart';
import 'package:kakureru/features/ble/repository/ble_permission.dart';
import 'package:kakureru/features/location/repository/location_permission.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('PermissionQueue', () {
    test('並走して積まれた要求でも、前が終わるまで次は始まらない', () async {
      final queue = PermissionQueue();
      final log = <String>[];
      final first = Completer<String>();
      final second = Completer<String>();

      // 2つの要求を「同じフレームで」積む(ゲーム画面に入った瞬間に
      // 位置情報とBLEの権限要求が同時に走る状況)。
      final firstCall = queue.add(() async {
        log.add('1:start');
        final result = await first.future;
        log.add('1:end');
        return result;
      });
      final secondCall = queue.add(() async {
        log.add('2:start');
        final result = await second.future;
        log.add('2:end');
        return result;
      });

      await pumpEventQueue();
      expect(log, ['1:start'], reason: '1つ目が終わる前に2つ目が始まってはいけない');

      first.complete('a');
      await pumpEventQueue();
      expect(log, ['1:start', '1:end', '2:start']);

      second.complete('b');
      expect(await firstCall, 'a');
      expect(await secondCall, 'b');
      expect(log, ['1:start', '1:end', '2:start', '2:end']);
    });

    test('要求は捨てられず、積んだ順にすべて実行される', () async {
      final queue = PermissionQueue();
      final executed = <int>[];

      await Future.wait([
        for (var i = 0; i < 5; i++)
          queue.add(() async {
            await Future<void>.delayed(Duration.zero);
            executed.add(i);
            return i;
          }),
      ]);

      expect(executed, [0, 1, 2, 3, 4]);
    });

    test('例外は呼び出し元へ伝わり、後続の要求は止まらない', () async {
      final queue = PermissionQueue();

      final failing = queue.add<void>(
        () async => throw Exception('権限要求の失敗を模擬'),
      );
      final following = queue.add(() async => 'ok');

      await expectLater(failing, throwsException);
      expect(await following, 'ok');
    });
  });

  group('位置情報とBLEの権限要求の直列化(issue #66)', () {
    test('同じフレームで両方が要求しても、ダイアログは1つずつ順番に出る', () async {
      // 共有キューに相当するものをテスト用に1つ作り、両サービスへ渡す。
      // 実行時は既定の PermissionQueue.shared が同じ役割を果たす。
      final queue = PermissionQueue();
      final requested = <Permission>[];
      var inFlight = false;

      Future<PermissionStatus> fakeRequest(Permission permission) async {
        // permission_handler が例外を返す条件(前の要求が返る前に次を
        // 要求する)をここで検知する。
        expect(inFlight, isFalse, reason: '前の権限要求が終わる前に次が始まった');
        inFlight = true;
        requested.add(permission);
        await Future<void>.delayed(Duration.zero);
        inFlight = false;
        return PermissionStatus.granted;
      }

      final location = LocationPermissionService(
        requestPermission: fakeRequest,
        checkNotificationPermission: () async => NotificationPermission.granted,
        requestNotificationPermission: () async =>
            NotificationPermission.granted,
        queue: queue,
      );
      final ble = BlePermissionService(
        requestPermission: fakeRequest,
        queue: queue,
      );

      final results = await Future.wait([
        location.ensureGranted(),
        ble.ensureGranted(),
      ]);

      expect(results, [true, true]);
      // 位置情報の要求がすべて終わってからBLEの要求が始まっている
      // (2つの機能の要求が入り混じらない)。
      expect(requested, [
        Permission.locationWhenInUse,
        Permission.locationAlways,
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ]);
    });
  });
}
