import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakureru/features/location/repository/location_task_handler.dart';

/// 位置取得の成功を模擬するための値。中身は使われないので固定でよい。
Position _somePosition() => Position(
  latitude: 35.681236,
  longitude: 139.767125,
  timestamp: DateTime.utc(2026),
  accuracy: 5,
  altitude: 12.5,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);

void main() {
  group('LocationTaskHandler.sendCurrentPosition', () {
    test('連続で失敗するたびに、ログの連続失敗回数が1→2→3と増える', () async {
      final logs = <String>[];
      final handler = LocationTaskHandler(
        getCurrentPosition: () async => throw Exception('GPSの失敗を模擬'),
        log: logs.add,
      );

      await handler.sendCurrentPosition();
      await handler.sendCurrentPosition();
      await handler.sendCurrentPosition();

      expect(logs, hasLength(3));
      expect(logs[0], contains('1回連続'));
      expect(logs[1], contains('2回連続'));
      expect(logs[2], contains('3回連続'));
      // 失敗の内容も追えるよう、例外の文字列がログに含まれていること。
      expect(logs.last, contains('GPSの失敗を模擬'));
    });

    test('失敗は例外として呼び出し側へ投げ返さない(次の周期で再試行するため)', () async {
      final handler = LocationTaskHandler(
        getCurrentPosition: () async => throw Exception('GPSの失敗を模擬'),
        log: (_) {},
      );

      await expectLater(handler.sendCurrentPosition(), completes);
    });

    test('取得に成功したら連続失敗回数は0に戻り、その後の失敗は再び1回目から数える', () async {
      final logs = <String>[];
      var shouldFail = true;
      final handler = LocationTaskHandler(
        getCurrentPosition: () async {
          if (shouldFail) throw Exception('GPSの失敗を模擬');
          return _somePosition();
        },
        log: logs.add,
      );

      await handler.sendCurrentPosition();
      await handler.sendCurrentPosition();
      expect(logs.last, contains('2回連続'));

      shouldFail = false;
      await handler.sendCurrentPosition();
      // 成功時はログを出さない(2件のまま)。
      expect(logs, hasLength(2));

      shouldFail = true;
      await handler.sendCurrentPosition();
      expect(logs, hasLength(3));
      expect(logs.last, contains('1回連続'));
    });
  });
}
