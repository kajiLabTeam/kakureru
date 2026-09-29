import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/repository/event_log_repository.dart';

import '../../../helpers/fake_rtdb.dart';

void main() {
  group('buildGameEventPayload', () {
    test('catchは位置・精度・気圧・屋内フラグをすべて含める', () {
      final payload = buildGameEventPayload(
        type: GameEventType.caught,
        uid: 'u1',
        timestamp: 123,
        lat: 35.1,
        lng: 136.9,
        accuracy: 8.5,
        pressure: 1008.2,
        indoor: true,
      );

      expect(payload, {
        'type': 'catch',
        'at': 123,
        'uid': 'u1',
        'lat': 35.1,
        'lng': 136.9,
        'accuracy': 8.5,
        'pressure': 1008.2,
        'indoor': true,
      });
    });

    test('値の無いフィールドはキーごと省く', () {
      final payload = buildGameEventPayload(
        type: GameEventType.gameStarted,
        uid: 'host',
        timestamp: 1,
      );

      expect(payload, {'type': 'game_started', 'at': 1, 'uid': 'host'});
    });

    test('屋外はindoor=falseとして残す(省略しない)', () {
      final payload = buildGameEventPayload(
        type: GameEventType.caught,
        uid: 'u1',
        timestamp: 1,
        indoor: false,
      );

      expect(payload['indoor'], false);
    });

    test('displayNameがあれば含める', () {
      final payload = buildGameEventPayload(
        type: GameEventType.caught,
        uid: 'u1',
        timestamp: 1,
        displayName: 'たろう',
      );

      expect(payload['displayName'], 'たろう');
    });

    test('targetUidがあれば含める', () {
      final payload = buildGameEventPayload(
        type: GameEventType.caught,
        uid: 'u1',
        timestamp: 1,
        targetUid: 'u2',
      );

      expect(payload['targetUid'], 'u2');
    });
  });

  test('typeのRTDB上の文字列が仕様どおり', () {
    expect(GameEventType.values.map((t) => t.raw), [
      'game_started',
      'released',
      'catch',
      'catch_undone',
      'became_demon',
      'game_ended',
      'photo_taken',
    ]);
  });

  group('EventLogRepository.log のdisplayName', () {
    Map<String, Object?> onlyEvent(FakeRtdb db) {
      final events = db.read('rooms/room-1/events')! as Map;
      return Map<String, Object?>.from(events.values.single as Map);
    }

    test('渡したdisplayNameをイベントに残す', () async {
      final db = FakeRtdb();

      await EventLogRepository(db: db).log(
        'room-1',
        type: GameEventType.caught,
        uid: 'u1',
        displayName: 'たろう',
      );

      expect(onlyEvent(db)['displayName'], 'たろう');
      expect(onlyEvent(db)['uid'], 'u1');
    });

    test('省略するとusers/{uid}/displayNameから引いて残す', () async {
      final db = FakeRtdb({
        'rooms': <String, Object?>{
          'room-1': <String, Object?>{
            'users': <String, Object?>{
              'u1': <String, Object?>{'displayName': 'はなこ'},
            },
          },
        },
      });

      await EventLogRepository(db: db).log(
        'room-1',
        type: GameEventType.photoTaken,
        uid: 'u1',
      );

      expect(onlyEvent(db)['displayName'], 'はなこ');
    });

    test('名前が引けなくてもイベント自体は記録する', () async {
      final db = FakeRtdb();

      await EventLogRepository(db: db).log(
        'room-1',
        type: GameEventType.gameStarted,
        uid: 'u1',
      );

      expect(onlyEvent(db), isNot(contains('displayName')));
      expect(onlyEvent(db)['type'], 'game_started');
    });
  });

  test('書き込みに失敗しても例外を投げずにログへ出す', () async {
    // Firebase未初期化のテスト環境ではinstanceの解決自体が失敗する。
    final messages = <String>[];

    await EventLogRepository().log(
      'room1',
      type: GameEventType.caught,
      uid: 'u1',
      onError: messages.add,
    );

    expect(messages, hasLength(1));
    expect(messages.single, startsWith('[EventLog] catchの記録に失敗'));
  });
}
