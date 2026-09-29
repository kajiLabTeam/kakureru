import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/clue_guide_page.dart';

/// [ClueGuidePage]のテスト(ゲーム画面モック04)。
void main() {
  Widget host({UserRole? viewerRole = UserRole.demon}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showClueGuide(context, viewerRole: viewerRole),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(
    WidgetTester tester, {
    UserRole? viewerRole = UserRole.demon,
  }) async {
    await tester.pumpWidget(host(viewerRole: viewerRole));
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

  group('2項目めの説明は見ている人の役割で変える (issue #135)', () {
    testWidgets('鬼には、進む向きの確かめ方を出す', (tester) async {
      await open(tester);
      expect(find.textContaining('反対方向へ行ってみてください'), findsOneWidget);
    });

    testWidgets('逃走者には、鬼が近づいているか離れているかが分かるとだけ出す', (
      tester,
    ) async {
      await open(tester, viewerRole: UserRole.fugitive);
      expect(find.text('鬼が近づいているのか、離れているのかが分かります。'), findsOneWidget);
      expect(find.textContaining('反対方向へ'), findsNothing);
    });

    testWidgets('役割が分からないときは鬼と同じ説明にする', (tester) async {
      await open(tester, viewerRole: null);
      expect(find.textContaining('反対方向へ行ってみてください'), findsOneWidget);
    });
  });
}
