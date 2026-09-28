import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/view/game/become_demon_button.dart';

/// [BecomeDemonButton]単体のテスト(issue #43)。
///
/// GamePage全体は位置情報・Wi-Fi・気圧・BLEなど多数のproviderに依存して
/// おりFirebase初期化なしではwidgetテストを組みにくいため、「鬼になる」
/// ボタンの表示ロジックはGamePageから[BecomeDemonButton]として切り出し、
/// providerに依存しない形で直接テストする。
void main() {
  Widget pumpTarget({
    required bool isDetected,
    required bool isSubmitting,
    VoidCallback? onPressed,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            BecomeDemonButton(
              isDetected: isDetected,
              isSubmitting: isSubmitting,
              onPressed: onPressed ?? () {},
            ),
          ],
        ),
      ),
    );
  }

  const hint = '鬼が3m以内に近づくと\n「鬼になる」が押せます';

  testWidgets('BLEで検知していない間は常に表示されるがdisabledで、鍵と条件が出る', (tester) async {
    await tester.pumpWidget(pumpTarget(isDetected: false, isSubmitting: false));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text('鬼になる'), findsOneWidget);
    expect(find.text(hint), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('BLEで検知している間はenabledになり、押すとonPressedを呼ぶ', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      pumpTarget(
        isDetected: true,
        isSubmitting: false,
        onPressed: () => pressed = true,
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    await tester.tap(find.byType(FilledButton));
    expect(pressed, isTrue);
  });

  testWidgets('検知していてもisSubmittingならdisabledになりスピナーが出る', (tester) async {
    await tester.pumpWidget(pumpTarget(isDetected: true, isSubmitting: true));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ボタンは高さ44dp以上ある', (tester) async {
    await tester.pumpWidget(pumpTarget(isDetected: false, isSubmitting: false));

    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('detected/undetectedで帯全体の高さが変わらない', (tester) async {
    await tester.pumpWidget(pumpTarget(isDetected: false, isSubmitting: false));
    final heightWhenNotDetected = tester
        .getSize(find.byType(BecomeDemonButton))
        .height;

    await tester.pumpWidget(pumpTarget(isDetected: true, isSubmitting: false));
    final heightWhenDetected = tester
        .getSize(find.byType(BecomeDemonButton))
        .height;

    expect(heightWhenDetected, heightWhenNotDetected);
    expect(heightWhenDetected, becomeDemonRowHeight);
  });
}
