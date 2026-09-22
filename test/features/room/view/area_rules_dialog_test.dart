import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/area_rules.dart';
import 'package:kakureru/features/room/view/game/area_rules_button.dart';

/// 「使用していい範囲」ボタンとモーダル(issue #108)のテスト。
///
/// GamePage / RoomWaitingPage 全体はFirebaseやセンサー系のproviderを丸ごと
/// 差し替えないと立ち上がらないため、`become_demon_button_test.dart`と同じ
/// く、providerに依存しない部品だけを直接pumpする。
void main() {
  Widget pumpTarget() =>
      const MaterialApp(home: Scaffold(body: AreaRulesButton()));

  testWidgets('押すまではモーダルは出ていない', (tester) async {
    await tester.pumpWidget(pumpTarget());

    expect(find.text('使用していい範囲'), findsNothing);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);
  });

  testWidgets('押すと使ってよい場所・ダメな場所がすべて出る', (tester) async {
    await tester.pumpWidget(pumpTarget());
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(find.text('使用していい範囲'), findsOneWidget);
    expect(find.text('使ってよい'), findsOneWidget);
    expect(find.text('使用不可'), findsOneWidget);
    for (final place in [...allowedAreaRules, ...forbiddenAreaRules]) {
      expect(find.text('・$place'), findsOneWidget, reason: place);
    }
  });

  testWidgets('項目が画面に収まらなくてもスクロールして読める', (tester) async {
    await tester.pumpWidget(pumpTarget());
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });

  testWidgets('「閉じる」でモーダルが閉じる', (tester) async {
    await tester.pumpWidget(pumpTarget());
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    expect(find.text('使用していい範囲'), findsNothing);
  });
}
