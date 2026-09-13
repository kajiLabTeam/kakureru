import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/view/room_home_page.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

FilledButton _createRoomButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'ルームを作る'));

OutlinedButton _joinRoomButton(WidgetTester tester) => tester
    .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'ルームに参加'));

Future<void> _pumpHomePage(
  WidgetTester tester, {
  required String? savedDisplayName,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        savedDisplayNameProvider.overrideWith((ref) => savedDisplayName),
      ],
      child: const MaterialApp(home: RoomHomePage()),
    ),
  );
  // savedDisplayNameProviderはFutureProviderなので、1回目のbuildは
  // AsyncLoadingで、値が解決されるのはその後のbuild。
  await tester.pump();
  await tester.pump();
}

void main() {
  group('名前の復元とボタンの有効/無効', () {
    testWidgets('保存済みの名前がある場合、入力欄に触れなくてもボタンが押せる', (tester) async {
      await _pumpHomePage(tester, savedDisplayName: 'たろう');

      expect(find.text('たろう'), findsOneWidget);
      expect(_createRoomButton(tester).onPressed, isNotNull);
      expect(_joinRoomButton(tester).onPressed, isNotNull);
      // 復元直後でも赤字のエラー表示は出ない。
      expect(find.text('名前を入力してください'), findsNothing);
    });

    testWidgets('保存済みの名前が無い(初回起動)場合、ボタンは無効のまま', (tester) async {
      await _pumpHomePage(tester, savedDisplayName: null);

      expect(_createRoomButton(tester).onPressed, isNull);
      expect(_joinRoomButton(tester).onPressed, isNull);
    });

    testWidgets('保存済みの名前が空文字の場合、ボタンは無効のまま', (tester) async {
      await _pumpHomePage(tester, savedDisplayName: '');

      expect(_createRoomButton(tester).onPressed, isNull);
      expect(_joinRoomButton(tester).onPressed, isNull);
    });

    testWidgets('保存済みの名前が文字数上限を超えている場合、ボタンは無効のまま', (tester) async {
      await _pumpHomePage(tester, savedDisplayName: 'あ' * 11);

      expect(_createRoomButton(tester).onPressed, isNull);
      expect(_joinRoomButton(tester).onPressed, isNull);
    });

    testWidgets('ユーザーが既に入力し始めていたら保存名で上書きしない', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedDisplayNameProvider.overrideWith((ref) => 'たろう'),
          ],
          child: const MaterialApp(home: RoomHomePage()),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'じろう');
      await tester.pump();
      // savedDisplayNameProviderの値が解決されるフレームをまたぐ。
      await tester.pump();

      expect(find.text('じろう'), findsOneWidget);
      expect(find.text('たろう'), findsNothing);
    });
  });
}
