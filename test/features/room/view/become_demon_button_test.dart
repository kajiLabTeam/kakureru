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
        body: BecomeDemonButton(
          isDetected: isDetected,
          isSubmitting: isSubmitting,
          onPressed: onPressed ?? () {},
        ),
      ),
    );
  }

  testWidgets('BLEで検知していない間は常に表示されるがdisabledで、理由が出る', (tester) async {
    await tester.pumpWidget(pumpTarget(isDetected: false, isSubmitting: false));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text('鬼になる'), findsOneWidget);
    expect(find.text('鬼が3m以内に近づくと押せます'), findsOneWidget);

    final visibility = tester.widget<Visibility>(find.byType(Visibility));
    expect(visibility.visible, isTrue);
  });

  testWidgets('BLEで検知している間はenabledになり、理由は隠れる(領域は保持)', (tester) async {
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

    final visibility = tester.widget<Visibility>(find.byType(Visibility));
    expect(visibility.visible, isFalse);
    // maintainSize:trueなので、非表示でも理由テキスト自体はツリーに残る
    // (検知の有無でレイアウトの高さが変わらないことの担保)。
    expect(visibility.maintainSize, isTrue);
    expect(find.text('鬼が3m以内に近づくと押せます'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    expect(pressed, isTrue);
  });

  testWidgets('検知していてもisSubmittingならdisabledになりスピナーが出る', (tester) async {
    await tester.pumpWidget(pumpTarget(isDetected: true, isSubmitting: true));

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('detected/undetectedでボタン+理由テキスト全体の高さが変わらない', (tester) async {
    await tester.pumpWidget(pumpTarget(isDetected: false, isSubmitting: false));
    final heightWhenNotDetected = tester
        .getSize(find.byType(BecomeDemonButton))
        .height;

    await tester.pumpWidget(pumpTarget(isDetected: true, isSubmitting: false));
    final heightWhenDetected = tester
        .getSize(find.byType(BecomeDemonButton))
        .height;

    expect(heightWhenDetected, heightWhenNotDetected);
  });
}
