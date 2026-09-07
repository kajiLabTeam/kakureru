import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/core/utils/rtdb_write.dart';

void main() {
  group('writeOrLogFailure', () {
    test('書き込みが失敗したら、例外を投げ返さずタグ付きでログに残す', () async {
      final logs = <String>[];

      await expectLater(
        writeOrLogFailure(
          () async => throw Exception('permission denied を模擬'),
          tag: 'WifiScanRepository',
          field: 'wifiScan',
          log: logs.add,
        ),
        completes,
      );

      expect(logs, hasLength(1));
      expect(logs.single, contains('[WifiScanRepository]'));
      expect(logs.single, contains('wifiScanの書き込みに失敗'));
      expect(logs.single, contains('permission denied を模擬'));
    });

    test('書き込みが成功したらログを出さない', () async {
      final logs = <String>[];

      await writeOrLogFailure(
        () async {},
        tag: 'PressureRepository',
        field: 'pressure',
        log: logs.add,
      );

      expect(logs, isEmpty);
    });

    test('書き込みの完了を待ち合わせる(投げっぱなしにしない)', () async {
      // awaitしていなければ、writeOrLogFailureが返った時点では
      // まだ完了していない(=失敗も検知できない)ことになる。
      var completed = false;

      await writeOrLogFailure(
        () async {
          await Future<void>.delayed(Duration.zero);
          completed = true;
        },
        tag: 'PressureRepository',
        field: 'pressure',
        log: (_) {},
      );

      expect(completed, isTrue);
    });
  });
}
