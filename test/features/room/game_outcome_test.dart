import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/game_outcome.dart';

void main() {
  group('determineGameOutcome', () {
    test('逃走者が1人でも残っていれば逃げ切り', () {
      expect(
        determineGameOutcome(survivedFugitiveCount: 1),
        GameOutcome.fugitivesEscaped,
      );
    });

    test('逃走者が0人なら鬼の勝ち', () {
      expect(
        determineGameOutcome(survivedFugitiveCount: 0),
        GameOutcome.demonsWon,
      );
    });
  });

  group('describeGameOutcome', () {
    test('逃げ切りは人数つきで出す', () {
      final text = describeGameOutcome(
        outcome: GameOutcome.fugitivesEscaped,
        survivedFugitiveCount: 2,
      );
      expect(text.title, 'タイムアップ');
      expect(text.summary, '逃走者 2人 が逃げ切り');
    });

    test('鬼の勝ちは人数を出さない', () {
      final text = describeGameOutcome(
        outcome: GameOutcome.demonsWon,
        survivedFugitiveCount: 0,
      );
      expect(text.title, '全員捕まりました');
      expect(text.summary, '鬼の勝ち');
    });
  });
}
