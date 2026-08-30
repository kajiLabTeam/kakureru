import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/view/caught_transition_overlay.dart';

void main() {
  testWidgets('鬼のテーマ(色・文言・アイコン)で全画面表示される', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaughtTransitionOverlay(onContinue: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('あなたは 鬼'), findsOneWidget);
    expect(find.text('逃走者の位置が見えるようになります'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department), findsOneWidget);

    final material = tester.widget<Material>(find.byType(Material).first);
    expect(material.color, const Color(0xFFE5484D));
  });

  testWidgets('「鬼の画面へ」を押すとonContinueが呼ばれる', (tester) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CaughtTransitionOverlay(onContinue: () => continued = true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '鬼の画面へ'));
    await tester.pump();

    expect(continued, isTrue);
  });
}
