import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/view/game/catch_button_strip.dart';
import 'package:kakureru/features/room/view/game/catch_target_sheet.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

FilledButton _button(WidgetTester tester, String label) => tester.widget(
  find.ancestor(of: find.text(label), matching: find.byType(FilledButton)),
);

void main() {
  group('CatchButtonStrip', () {
    testWidgets('3m以内に逃走者がいなければ、帯は出したまま押せない', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _wrap(
          CatchButtonStrip(
            nearestName: null,
            inRangeCount: 0,
            isSubmitting: false,
            onPressed: () => pressed++,
          ),
        ),
      );

      expect(find.text('3m以内に逃走者はいません'), findsOneWidget);
      expect(_button(tester, '捕まえた').onPressed, isNull);
      await tester.tap(find.text('捕まえた'));
      expect(pressed, 0);
    });

    testWidgets('3m以内に逃走者がいれば押せる', (tester) async {
      var pressed = 0;
      await tester.pumpWidget(
        _wrap(
          CatchButtonStrip(
            nearestName: 'はなこ',
            inRangeCount: 2,
            isSubmitting: false,
            onPressed: () => pressed++,
          ),
        ),
      );

      expect(find.text('はなこ ほか1人が3m以内にいます'), findsOneWidget);
      await tester.tap(find.text('捕まえた'));
      expect(pressed, 1);
      expect(
        tester.getSize(find.byType(CatchButtonStrip)).height,
        catchButtonStripHeight,
      );
    });
  });

  group('CatchTargetSheet', () {
    testWidgets('候補が1人なら選択済みで、屋内/屋外をすぐ押せる', (tester) async {
      CatchTargetChoice? choice;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                choice = await showCatchTargetSheet(
                  context,
                  candidates: const [(uid: 'u1', name: 'はなこ')],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.tap(find.text('屋外で捕まえた'));
      await tester.pumpAndSettle();

      expect(choice, (uid: 'u1', indoor: false));
    });

    testWidgets('候補が2人なら選ぶまで屋内/屋外を押せない', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CatchTargetSheet(
            candidates: [(uid: 'u1', name: 'はなこ'), (uid: 'u2', name: 'たろう')],
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(_button(tester, '屋内で捕まえた').onPressed, isNull);

      await tester.tap(find.text('たろう'));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(_button(tester, '屋内で捕まえた').onPressed, isNotNull);
    });
  });
}
