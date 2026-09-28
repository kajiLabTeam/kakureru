import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/view/game/clue_guide_page.dart';

/// [ClueGuidePage]のテスト(ゲーム画面モック04)。
void main() {
  Widget host() {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showClueGuide(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('3つの見方と注意書きを出す', (tester) async {
    await open(tester);

    expect(find.text('手がかりの見方'), findsOneWidget);
    expect(find.text('1. バーが右にのびるほど近い'), findsOneWidget);
    expect(find.text('2. 歩きながら「近づいた」を見る'), findsOneWidget);
    expect(find.text('3. 高さは「階」で出ます'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('どれも推定なので'),
      100,
    );
    expect(find.textContaining('どれも推定なので'), findsOneWidget);
  });

  testWidgets('「わかった」で閉じる', (tester) async {
    await open(tester);

    await tester.tap(find.text('わかった'));
    await tester.pumpAndSettle();
    expect(find.byType(ClueGuidePage), findsNothing);
  });

  testWidgets('スキップ・場所の一覧へのリンクは出さない', (tester) async {
    await open(tester);

    expect(find.text('スキップ'), findsNothing);
    expect(find.text('使ってよい場所を見る'), findsNothing);
  });
}
