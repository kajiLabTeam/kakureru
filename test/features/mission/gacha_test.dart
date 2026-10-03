import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/view/gacha/gacha_page.dart';
import 'package:kakureru/features/mission/view/gacha/gacha_phase.dart';
import 'package:kakureru/features/mission/view/gacha/gacha_sound.dart';
import 'package:kakureru/features/mission/view/reward_page.dart';

/// 鳴らした音・振動・停止を記録するだけの[GachaFeedback]。
class _FakeFeedback implements GachaFeedback {
  final played = <GachaCue>[];
  final vibrations = <int>[];
  var stopCount = 0;

  @override
  Future<void> play(GachaCue cue) async => played.add(cue);

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<void> vibrate(int durationMillis) async =>
      vibrations.add(durationMillis);
}

/// 本物の音は鳴らさず、[feedback]で記録する。
Widget _withFeedback(_FakeFeedback feedback, Widget child) => ProviderScope(
  overrides: [gachaFeedbackProvider.overrideWithValue(feedback)],
  child: child,
);

Future<_FakeFeedback> _pumpGacha(
  WidgetTester tester, {
  RewardType reward = RewardType.blockClues,
}) async {
  await tester.binding.setSurfaceSize(const Size(393, 852));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final feedback = _FakeFeedback();
  await tester.pumpWidget(
    _withFeedback(feedback, MaterialApp(home: GachaPage(reward: reward))),
  );
  return feedback;
}

/// ゲーム画面と同じく[GachaPage.show]で重ねて開く。返す関数は
/// showのFutureが完了したかどうか。
Future<bool Function()> _openGachaViaShow(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(393, 852));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  var completed = false;
  await tester.pumpWidget(
    _withFeedback(
      _FakeFeedback(),
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              await GachaPage.show(context, RewardType.blockClues);
              completed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(GachaPage), findsOneWidget);
  return () => completed;
}

/// 画面の切り替え(演出のフェード200ms・MaterialPageRoute)を終わらせる。
/// 演出は繰り返しアニメーションがあるのでpumpAndSettleは使えない。
Future<void> _pumpTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
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

    test('ハズレ(isMiss)は激熱を出さず、ハンドルのあとすぐカプセルに進む', () {
      expect(
        gachaPhaseAt(const Duration(milliseconds: 1499), isMiss: true),
        GachaPhase.turning,
      );
      expect(
        gachaPhaseAt(const Duration(milliseconds: 1500), isMiss: true),
        GachaPhase.capsule,
      );
      // 当たりなら同じ時刻はまだ激熱のはず(ハズレとの違いの確認)。
      expect(
        gachaPhaseAt(const Duration(milliseconds: 1500)),
        GachaPhase.heat,
      );
    });

    test('missedの段もタップで最後まで飛ばせる', () {
      expect(gachaTapAction(GachaPhase.missed), GachaTapAction.skipToEnd);
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

    testWidgets('ハズレは激熱を出さず、短い演出で赤い「残念」になる', (tester) async {
      await _pumpGacha(tester, reward: RewardType.miss);
      expect(find.text('まわしてる…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1600));
      // ハズレは激熱を出さない。
      expect(find.text('激熱'), findsNothing);
      expect(find.text('カプセルを開ける'), findsOneWidget);

      await tester.tap(find.text('カプセルを開ける'));
      await tester.pump();
      expect(find.text('確定'), findsNothing);
      expect(find.text('残念'), findsOneWidget);

      await tester.pump(gachaMissedDuration);
      expect(find.text('なにも起きない'), findsOneWidget);
      // 何も起きないので、時間のタグも「効果はもう出ている」も出さない。
      expect(find.text('1回'), findsNothing);
      expect(find.text('効果はもう出ている'), findsNothing);
    });

    testWidgets('ハンドルの途中でタップ1回すると、ごほうびカードまで飛ばせる', (tester) async {
      await _pumpGacha(tester);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tapAt(const Offset(200, 400));
      await tester.pump();

      expect(find.text('確定'), findsOneWidget);
      expect(find.text('鬼の手がかりを止める'), findsOneWidget);
      expect(find.text('鬼をジャマする'), findsNothing);
      expect(find.text('3分'), findsOneWidget);
      // 持っておくごほうびなので、まだ効いていない。
      expect(find.text('地図の「つかう」で好きなときに使える'), findsOneWidget);
      expect(find.text('効果はもう出ている'), findsNothing);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'ごほうびの中身を見る'),
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

    testWidgets('「ごほうびの中身を見る」でごほうびの画面に移る', (tester) async {
      final done = await _openGachaViaShow(tester);
      await tester.tapAt(const Offset(200, 400));
      await tester.pump();

      await tester.tap(find.text('ごほうびの中身を見る'));
      await _pumpTransition(tester);

      expect(find.byType(RewardPage), findsOneWidget);
      expect(find.byType(GachaPage), findsNothing);
      expect(done(), isFalse);
    });

    testWidgets('showのFutureはごほうびの画面を閉じるまで完了しない', (tester) async {
      final done = await _openGachaViaShow(tester);
      await tester.tapAt(const Offset(200, 400));
      await tester.pump();
      await tester.tap(find.text('ごほうびの中身を見る'));
      await _pumpTransition(tester);
      // 演出は閉じたがごほうびの画面を見ている間(=ゲーム終了の遷移を止める間)。
      expect(done(), isFalse);

      await tester.tap(find.text('地図にもどる'));
      await _pumpTransition(tester);

      expect(find.byType(RewardPage), findsNothing);
      expect(done(), isTrue);
    });

    testWidgets('演出を戻るで閉じたらごほうびの画面は出さずに完了する', (tester) async {
      final done = await _openGachaViaShow(tester);
      await tester.tapAt(const Offset(200, 400));
      await _pumpTransition(tester);

      await tester.binding.handlePopRoute();
      await _pumpTransition(tester);

      expect(find.byType(GachaPage), findsNothing);
      expect(find.byType(RewardPage), findsNothing);
      expect(done(), isTrue);
    });
  });

  group('音と振動(gacha_sound)', () {
    test('段ごとに決まった音を鳴らす', () {
      expect(gachaCueFor(GachaPhase.turning), GachaCue.turning);
      expect(gachaCueFor(GachaPhase.heat), GachaCue.heat);
      expect(gachaCueFor(GachaPhase.capsule), GachaCue.drop);
      expect(gachaCueFor(GachaPhase.confirmed), GachaCue.fanfare);
      expect(gachaCueFor(GachaPhase.missed), GachaCue.miss);
    });

    test('振動は確定で長く1回、ハズレは短く、ほかの段は振動しない', () {
      expect(gachaVibrationMillisFor(GachaPhase.confirmed), 700);
      expect(
        gachaVibrationMillisFor(GachaPhase.missed),
        lessThan(gachaVibrationMillisFor(GachaPhase.confirmed)!),
      );
      expect(gachaVibrationMillisFor(GachaPhase.turning), isNull);
      expect(gachaVibrationMillisFor(GachaPhase.heat), isNull);
      expect(gachaVibrationMillisFor(GachaPhase.capsule), isNull);
    });

    testWidgets('当たりはハンドル → 激熱 → コロン → ファンファーレの順に鳴る', (tester) async {
      final feedback = await _pumpGacha(tester);
      await tester.pump();
      expect(feedback.played, [GachaCue.turning]);

      await tester.pump(const Duration(milliseconds: 1600));
      expect(feedback.played, [GachaCue.turning, GachaCue.heat]);

      await tester.pump(const Duration(milliseconds: 1400));
      expect(feedback.played.last, GachaCue.drop);
      expect(feedback.vibrations, isEmpty);

      await tester.tap(find.text('カプセルを開ける'));
      await tester.pump();
      expect(feedback.played, [
        GachaCue.turning,
        GachaCue.heat,
        GachaCue.drop,
        GachaCue.fanfare,
      ]);
      expect(feedback.vibrations, [700]);
    });

    testWidgets('ハズレは激熱の音を出さず、短く低い音で終わる', (tester) async {
      final feedback = await _pumpGacha(tester, reward: RewardType.miss);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.tap(find.text('カプセルを開ける'));
      await tester.pump();

      expect(feedback.played, [GachaCue.turning, GachaCue.drop, GachaCue.miss]);
      expect(feedback.vibrations, [gachaVibrationMillisFor(GachaPhase.missed)]);
    });

    testWidgets('途中で飛ばすと、ファンファーレだけ鳴らして振動する', (tester) async {
      final feedback = await _pumpGacha(tester);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tapAt(const Offset(200, 400));
      await tester.pump();

      expect(feedback.played, [GachaCue.turning, GachaCue.fanfare]);
      expect(feedback.vibrations, [700]);
    });

    testWidgets('閉じたら鳴っている音を止める', (tester) async {
      final feedback = await _pumpGacha(tester);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());

      expect(feedback.stopCount, 1);
    });
  });
}
