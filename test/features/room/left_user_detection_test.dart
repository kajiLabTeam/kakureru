import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/left_user_detection.dart';
import 'package:kakureru/features/room/model/room_user.dart';

void main() {
  group('detectLeftUsers', () {
    const alice = RoomUser(id: 'alice', displayName: 'アリス');
    const bob = RoomUser(id: 'bob', displayName: 'ボブ');

    test('currentから消えたユーザーをpreviousの情報のまま返す', () {
      final result = detectLeftUsers(
        previous: const [alice, bob],
        current: const [alice],
      );
      expect(result, [bob]);
    });

    test('誰も抜けていなければ空', () {
      final result = detectLeftUsers(
        previous: const [alice, bob],
        current: const [alice, bob],
      );
      expect(result, isEmpty);
    });

    test('全員抜けていれば全員返す', () {
      final result = detectLeftUsers(
        previous: const [alice, bob],
        current: const [],
      );
      expect(result, [alice, bob]);
    });

    test('previousが空なら誰も抜けていない扱い', () {
      final result = detectLeftUsers(
        previous: const [],
        current: const [alice],
      );
      expect(result, isEmpty);
    });

    test('新規参加者(currentにのみ存在)は無視する', () {
      final result = detectLeftUsers(
        previous: const [alice],
        current: const [alice, bob],
      );
      expect(result, isEmpty);
    });

    test('leftAtが新たに立ったユーザーを離脱扱いにする(ソフト離脱)', () {
      final bobLeft = bob.copyWith(leftAt: 1000);
      final result = detectLeftUsers(
        previous: const [alice, bob],
        current: [alice, bobLeft],
      );
      expect(result, [bob]);
    });

    test('leftAtが立ったまま変化がなければ再通知しない', () {
      final bobLeft = bob.copyWith(leftAt: 1000);
      final result = detectLeftUsers(
        previous: [alice, bobLeft],
        current: [alice, bobLeft],
      );
      expect(result, isEmpty);
    });
  });

  group('detectRejoinedUsers', () {
    const alice = RoomUser(id: 'alice', displayName: 'アリス');
    const bob = RoomUser(id: 'bob', displayName: 'ボブ');

    test('leftAtが消えたユーザーを復帰扱いにする', () {
      final bobLeft = bob.copyWith(leftAt: 1000);
      final result = detectRejoinedUsers(
        previous: [alice, bobLeft],
        current: const [alice, bob],
      );
      expect(result, [bob]);
    });

    test('誰も復帰していなければ空', () {
      final result = detectRejoinedUsers(
        previous: const [alice, bob],
        current: const [alice, bob],
      );
      expect(result, isEmpty);
    });

    test('previousに存在しない(新規参加)ユーザーは復帰扱いにしない', () {
      final result = detectRejoinedUsers(
        previous: const [alice],
        current: const [alice, bob],
      );
      expect(result, isEmpty);
    });

    test('離脱したまま(leftAtが消えていない)なら復帰扱いにしない', () {
      final bobLeft = bob.copyWith(leftAt: 1000);
      final result = detectRejoinedUsers(
        previous: [alice, bobLeft],
        current: [alice, bobLeft],
      );
      expect(result, isEmpty);
    });
  });
}
