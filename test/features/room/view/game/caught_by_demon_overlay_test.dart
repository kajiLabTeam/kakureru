import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/error_message.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/view/game/caught_by_demon_overlay.dart';

void main() {
  group('undoCatchErrorMessage', () {
    test('期限切れは、その理由をそのまま出す', () {
      expect(
        undoCatchErrorMessage(const CatchUndoExpiredException()),
        '取り消せる時間が過ぎました',
      );
    });

    test('通信できないときは、その理由をそのまま出す', () {
      expect(
        undoCatchErrorMessage(const CatchUndoUnavailableException()),
        '通信できないため取り消せませんでした',
      );
    });

    // Firebaseの英語のエラー文などを、そのまま画面に出さない。
    test('それ以外の例外は利用者向けの文言に置き換える', () {
      final error = FirebaseException(
        plugin: 'database',
        code: 'permission-denied',
        message: "Client doesn't have permission",
      );

      final message = undoCatchErrorMessage(error);

      expect(message, userFacingErrorMessage(error));
      expect(message, isNot(contains('permission')));
    });
  });
}
