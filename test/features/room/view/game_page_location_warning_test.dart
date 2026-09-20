import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/room/view/game_page.dart';

String? _messageFor(LocationFailure failure) =>
    locationWarningMessage(LocationState(failure: failure));

void main() {
  group('locationWarningMessage', () {
    test('送信できているときは警告を出さない', () {
      expect(
        locationWarningMessage(const LocationState(isSending: true)),
        isNull,
      );
    });

    test('原因ごとに別々の案内を出す', () {
      // 同じ「自分の位置が出ない」でも直し方が違うので、文言が被っていては
      // 案内にならない(issue #66の受け入れ条件)。
      final messages = [
        for (final failure in LocationFailure.values)
          if (failure != LocationFailure.none) _messageFor(failure),
      ];

      expect(messages, everyElement(isNotNull));
      expect(messages.toSet(), hasLength(messages.length));
    });

    // 通知を拒否したのに位置情報の許可を促すと、設定で位置情報が許可済みなのを
    // 確認して詰む(issue #66のレビュー指摘)。
    test('通知が拒否されたときは、位置情報ではなく通知の案内を出す', () {
      final message = _messageFor(LocationFailure.notificationPermission);

      expect(message, contains('通知'));
      expect(message, isNot(contains('位置情報を許可')));
    });

    test('位置情報の権限が無いときは、位置情報の許可を促す', () {
      final message = _messageFor(LocationFailure.locationPermission);

      expect(message, contains('位置情報'));
      expect(message, contains('許可'));
    });

    test('端末の位置情報がOFFのときは、権限ではなく端末の設定を案内する', () {
      final message = _messageFor(LocationFailure.serviceDisabled);

      expect(message, contains('ON'));
    });

    test('送信の開始に失敗したときは、権限とは別の案内を出す', () {
      final sending = _messageFor(LocationFailure.sendingFailed);

      expect(sending, contains('送信を開始できませんでした'));
      expect(sending, isNot(_messageFor(LocationFailure.locationPermission)));
    });
  });
}
