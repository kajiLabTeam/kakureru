import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/view/gacha/gacha_page.dart';
import 'package:kakureru/features/mission/view/gacha/gacha_phase.dart';
import 'package:kakureru/features/mission/view/reward_page.dart';

Future<void> _pumpGacha(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(393, 852));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    const MaterialApp(home: GachaPage(reward: RewardType.blockClues)),
  );
}

/// 紙吹雪の数(`gacha-confetti-N` のキーが付いたもの)。
int _confettiCount(WidgetTester tester) => tester
    .widgetList(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('gacha-confetti-'),
      ),
    )
    .length;

void main() {
  group('段の進み方(gacha_phase)', () {
    test('ハンドル1.5秒 → 激熱1.4秒 → カプセル', () {
      expect(gachaPhaseAt(Duration.zero), GachaPhase.turning);
      expect(
        gachaPhaseAt(const Duration(milliseconds: 1499)),
        GachaPhase.turning,
      );
      expect(gachaPhaseAt(const Duration(milliseconds: 1500)), GachaPhase.heat);
      expect(gachaPhaseAt(const Duration(milliseconds: 2899)), GachaPhase.heat);
      expect(
        gachaPhaseAt(const Duration(milliseconds: 2900)),
        GachaPhase.capsule,
      );
      // カプセルから先は時間では進まない(タップを待つ)。
      expect(gachaPhaseAt(const Duration(minutes: 5)), GachaPhase.capsule);
    });

    test('どの段でもタップで最後まで飛ばせる。カプセルだけは「開ける」', () {
      expect(gachaTapAction(GachaPhase.turning), GachaTapAction.skipToEnd);
      expect(gachaTapAction(GachaPhase.heat), GachaTapAction.skipToEnd);
      expect(gachaTapAction(GachaPhase.capsule), GachaTapAction.open);
      expect(gachaTapAction(GachaPhase.confirmed), GachaTapAction.skipToEnd);
    });

    test('きたい度のランプは 青 → 緑(0.15秒) → 赤(0.55秒)', () {
      expect(gachaLitLamps(Duration.zero), 1);
      expect(gachaLitLamps(const Duration(milliseconds: 149)), 1);
      expect(gachaLitLamps(const Duration(milliseconds: 150)), 2);
      expect(gachaLitLamps(const Duration(milliseconds: 549)), 2);
      expect(gachaLitLamps(const Duration(milliseconds: 550)), 3);
    });

    test('紙吹雪は10枚まで', () {
      expect(gachaConfettiCount, lessThanOrEqualTo(10));
    });
  });

  group('GachaPage', () {
    testWidgets('時間でハンドル → 激熱 → カプセルと進み、カプセルでタップを待つ', (tester) async {
      await _pumpGacha(tester);
      expect(find.text('まわしてる…'), findsOneWidget);
      expect(find.text('激熱'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('激熱'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1400));
      expect(find.text('激熱'), findsNothing);
      expect(find.text('カプセルを開ける'), findsOneWidget);
      expect(find.text('開けろ'), findsOneWidget);

      // 待っていても確定には進まない。
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('確定'), findsNothing);

      await tester.tap(find.text('カプセルを開ける'));
      await tester.pump();
      expect(find.text('確定'), findsOneWidget);
      await tester.pump(gachaConfirmDuration);
      expect(find.text('鬼の手がかりを止める'), findsOneWidget);
    });

    testWidgets('ハンドルの途中でタップ1回すると、特典カードまで飛ばせる', (tester) async {
      await _pumpGacha(tester);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tapAt(const Offset(200, 400));
      await tester.pump();

      expect(find.text('確定'), findsOneWidget);
      expect(find.text('鬼の手がかりを止める'), findsOneWidget);
      expect(find.text('鬼に効く'), findsOneWidget);
      expect(find.text('30秒'), findsOneWidget);
      expect(find.text('効果はもう出ている'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '特典の中身を見る'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('激熱の途中でもタップで飛ばせる', (tester) async {
      await _pumpGacha(tester);
      await tester.pump(const Duration(milliseconds: 1800));
      expect(find.text('激熱'), findsOneWidget);

      await tester.tapAt(const Offset(200, 400));
      await tester.pump();

      expect(find.text('激熱'), findsNothing);
      expect(find.text('確定'), findsOneWidget);
    });

    testWidgets('紙吹雪は10枚まで', (tester) async {
      await _pumpGacha(tester);
      await tester.tapAt(const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_confettiCount(tester), gachaConfettiCount);
      expect(_confettiCount(tester), lessThanOrEqualTo(10));
    });

    testWidgets('「特典の中身を見る」で特典の画面に差し替わる', (tester) async {
      await _pumpGacha(tester);
      await tester.tapAt(const Offset(200, 400));
      await tester.pump();

      await tester.tap(find.text('特典の中身を見る'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(RewardPage), findsOneWidget);
      expect(find.byType(GachaPage), findsNothing);
    });
  });
}
