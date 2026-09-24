import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/repository/event_log_repository.dart';

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
      'became_demon',
      'game_ended',
      'photo_taken',
    ]);
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
