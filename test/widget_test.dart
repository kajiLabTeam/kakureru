import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/view/room_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('RoomHomePage shows create/join room controls', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RoomHomePage())),
    );

    expect(find.text('かくれんぼ'), findsOneWidget);
    expect(find.text('ルームを作る'), findsOneWidget);
    expect(find.text('ルームに参加'), findsOneWidget);
  });

  testWidgets('初期表示では名前が空でもエラーは出ずボタンも押せる', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RoomHomePage())),
    );
    await tester.pump();

    expect(find.text('名前を入力してください'), findsNothing);

    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'ルームを作る'),
    );
    final joinButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'ルームに参加'),
    );
    expect(createButton.onPressed, isNotNull);
    expect(joinButton.onPressed, isNotNull);
  });

  testWidgets('名前が空のまま「ルームを作る」を押すとエラーが表示される', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RoomHomePage())),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'ルームを作る'));
    await tester.pump();

    expect(find.text('名前を入力してください'), findsOneWidget);
  });

  testWidgets('空白のみの名前で「ルームに参加」を押してもエラーが表示される', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RoomHomePage())),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.tap(find.widgetWithText(OutlinedButton, 'ルームに参加'));
    await tester.pump();

    expect(find.text('名前を入力してください'), findsOneWidget);
  });

  testWidgets('エラー表示後に有効な名前を入力するとエラーが消える', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RoomHomePage())),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'ルームを作る'));
    await tester.pump();
    expect(find.text('名前を入力してください'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'たろう');
    await tester.pump();

    expect(find.text('名前を入力してください'), findsNothing);
  });
}
