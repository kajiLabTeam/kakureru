import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakureru/features/location/repository/location_task_handler.dart';

/// 測位を模擬する。[timestamp] で同じ測位かどうかを見分ける。
Position _position({
  required DateTime timestamp,
  double latitude = 35.681236,
  double accuracy = 5,
}) => Position(
  latitude: latitude,
  longitude: 139.767125,
  timestamp: timestamp,
  accuracy: accuracy,
  altitude: 12.5,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);

/// テスト用の組み立て。ストリームは `controllers` から流し、送信とログは
/// リストへ貯める。
({
  LocationTaskHandler handler,
  List<Map<String, Object?>> sent,
  List<String> logs,
  List<StreamController<Position>> controllers,
})
_setUp() {
  final sent = <Map<String, Object?>>[];
  final logs = <String>[];
  final controllers = <StreamController<Position>>[];
  final handler = LocationTaskHandler(
    positionStream: () {
      final controller = StreamController<Position>();
      controllers.add(controller);
      return controller.stream;
    },
    sendData: sent.add,
    log: logs.add,
  );
  return (handler: handler, sent: sent, logs: logs, controllers: controllers);
}

void main() {
  group('LocationTaskHandler(位置ストリームの購読)', () {
    test('まだ測位が1件も来ていなければ何も送らない', () async {
      final t = _setUp();
      t.handler.startListening();
      t.handler.sendLatestPosition();
      expect(t.sent, isEmpty);
    });

    test('送信時には、その時点で最新の測位だけを送る(途中の測位は送らない)', () async {
      final t = _setUp();
      t.handler.startListening();
      t.controllers.single
        ..add(_position(timestamp: DateTime.utc(2026)))
        ..add(
          _position(
            timestamp: DateTime.utc(2026, 1, 1, 0, 0, 2),
            latitude: 35.7,
          ),
        );
      await pumpEventQueue();

      t.handler.sendLatestPosition();

      expect(t.sent, hasLength(1));
      expect(t.sent.single['lat'], 35.7);
      expect(t.sent.single['accuracy'], 5);
      expect(
        t.sent.single['timestamp'],
        DateTime.utc(2026, 1, 1, 0, 0, 2).millisecondsSinceEpoch,
      );
    });

    test('新しい測位が来ていなければ、同じ測位を二重に送らない', () async {
      final t = _setUp();
      t.handler.startListening();
      t.controllers.single.add(_position(timestamp: DateTime.utc(2026)));
      await pumpEventQueue();

      t.handler
        ..sendLatestPosition()
        ..sendLatestPosition();
      expect(t.sent, hasLength(1));

      t.controllers.single.add(
        _position(timestamp: DateTime.utc(2026, 1, 1, 0, 0, 2)),
      );
      await pumpEventQueue();
      t.handler.sendLatestPosition();
      expect(t.sent, hasLength(2));
    });

    test('startListeningを何度呼んでも購読は1本だけ', () {
      final t = _setUp();
      t.handler
        ..startListening()
        ..startListening()
        ..startListening();
      expect(t.controllers, hasLength(1));
    });
  });

  group('LocationTaskHandler(失敗時)', () {
    test('エラーのたびに連続失敗回数が1→2→3と増え、購読を張り直す', () async {
      final t = _setUp();
      for (var i = 0; i < 3; i++) {
        t.handler.startListening();
        t.controllers.last.addError(Exception('GPSの失敗を模擬'));
        await pumpEventQueue();
      }

      expect(t.logs, hasLength(3));
      expect(t.logs[0], contains('1回連続'));
      expect(t.logs[1], contains('2回連続'));
      expect(t.logs[2], contains('3回連続'));
      // 失敗の内容も追えるよう、例外の文字列がログに含まれていること。
      expect(t.logs.last, contains('GPSの失敗を模擬'));
      // エラーのたびに購読を捨て、次のstartListeningで張り直している。
      expect(t.controllers, hasLength(3));
    });

    test('測位が届いたら連続失敗回数は0に戻り、その後の失敗は再び1回目から数える', () async {
      final t = _setUp();
      t.handler.startListening();
      t.controllers.last.addError(Exception('失敗'));
      await pumpEventQueue();
      t.handler.startListening();
      t.controllers.last.addError(Exception('失敗'));
      await pumpEventQueue();
      expect(t.logs.last, contains('2回連続'));

      t.handler.startListening();
      t.controllers.last.add(_position(timestamp: DateTime.utc(2026)));
      await pumpEventQueue();
      // 成功時はログを出さない(2件のまま)。
      expect(t.logs, hasLength(2));

      t.controllers.last.addError(Exception('失敗'));
      await pumpEventQueue();
      expect(t.logs, hasLength(3));
      expect(t.logs.last, contains('1回連続'));
    });

    test('ストリームの生成自体が例外を投げても、呼び出し側へ投げ返さない', () {
      final logs = <String>[];
      final handler = LocationTaskHandler(
        positionStream: () => throw Exception('購読できない'),
        sendData: (_) {},
        log: logs.add,
      );

      expect(handler.startListening, returnsNormally);
      expect(logs.single, contains('購読できない'));
    });

    test('ストリームが終了したら、次のstartListeningで張り直す', () async {
      final t = _setUp();
      t.handler.startListening();
      await t.controllers.single.close();
      await pumpEventQueue();

      t.handler.startListening();
      expect(t.controllers, hasLength(2));
    });
  });
}
