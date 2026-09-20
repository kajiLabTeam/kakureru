import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/room/view/game_page.dart';

void main() {
  group('locationWarningMessage', () {
    test('送信できているときは警告を出さない', () {
      expect(
        locationWarningMessage(const LocationState(isSending: true)),
        isNull,
      );
    });

    test('権限が無いときは、設定で許可する案内を出す', () {
      final message = locationWarningMessage(
        const LocationState(permissionDenied: true),
      );

      expect(message, isNotNull);
      expect(message, contains('許可'));
    });

    test('送信の開始に失敗したときは、権限とは別の案内を出す', () {
      final permission = locationWarningMessage(
        const LocationState(permissionDenied: true),
      );
      final sending = locationWarningMessage(
        const LocationState(sendingFailed: true),
      );

      expect(sending, contains('送信を開始できませんでした'));
      // 「権限が無い」のか「送信の開始に失敗した」のかが画面で区別できること
      // (issue #66の受け入れ条件)。
      expect(sending, isNot(permission));
    });

    test('権限が無い状態が優先される(どちらも立っているとき)', () {
      // 権限が無ければ送信も始められないので、先に直すべき方を案内する。
      expect(
        locationWarningMessage(
          const LocationState(permissionDenied: true, sendingFailed: true),
        ),
        locationWarningMessage(const LocationState(permissionDenied: true)),
      );
    });
  });
}
