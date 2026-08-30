import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/single_flight_action.dart';

void main() {
  group('SingleFlightAction', () {
    test('前の呼び出しが完了していない間に呼ばれた分は無視する(二重押し対策)', () async {
      final guard = SingleFlightAction();
      var runCount = 0;
      final firstActionResult = Completer<void>();

      // 1回目: まだ完了しない(RTDBへの書き込み待ちを模擬)。
      final firstCall = guard.run(() async {
        runCount++;
        await firstActionResult.future;
      });

      expect(guard.isRunning, isTrue);

      // 2回目: 1回目が完了する前に呼ばれる(連打を模擬)。無視されるべき。
      final secondCall = guard.run(() async {
        runCount++;
      });
      await secondCall;

      expect(runCount, 1, reason: '実行中の呼び出しがある間は新しい呼び出しを無視する');

      firstActionResult.complete();
      await firstCall;

      expect(guard.isRunning, isFalse);
    });

    test('前の呼び出しが完了した後は、新しい呼び出しを実行できる', () async {
      final guard = SingleFlightAction();
      var runCount = 0;

      await guard.run(() async => runCount++);
      await guard.run(() async => runCount++);

      expect(runCount, 2);
    });

    test('実行中の処理が例外を投げても、実行中フラグは解除される', () async {
      final guard = SingleFlightAction();

      await expectLater(
        guard.run(() async => throw Exception('模擬エラー')),
        throwsException,
      );

      expect(guard.isRunning, isFalse);

      var ranAfterError = false;
      await guard.run(() async => ranAfterError = true);
      expect(ranAfterError, isTrue);
    });
  });
}
