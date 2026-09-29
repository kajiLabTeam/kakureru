import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/opponent_roster_status.dart';
import 'package:kakureru/features/room/view/game/clue_card.dart';
import 'package:kakureru/features/room/view/game/game_status_cards.dart';
import 'package:kakureru/features/room/view/game/opponent_selector_chips.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';
import 'package:kakureru/features/wifi/wifi_clue_math.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('PreReleaseBanner', () {
    testWidgets('残り時間をMM:SSで出し、離れるよう促す', (tester) async {
      await tester.pumpWidget(_wrap(const PreReleaseBanner(countdownSec: 150)));
      expect(find.text('鬼の放出まで 02:30'), findsOneWidget);
      expect(find.text('いまのうちに、鬼から離れておきましょう'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });

    testWidgets('残り時間が未確定なら「計算中...」', (tester) async {
      await tester.pumpWidget(
        _wrap(const PreReleaseBanner(countdownSec: null)),
      );
      expect(find.text('鬼の放出まで 計算中...'), findsOneWidget);
    });
  });

  group('HiddenOpponentCard', () {
    testWidgets('見出し・補足・残り時間とアイコンを出す', (tester) async {
      final message = emptyOpponentMessage(
        viewerRole: UserRole.fugitive,
        opponentCountInRoom: 1,
        hiddenByVisibility: true,
        beforeRelease: true,
        revealRemainingSec: 150,
      );
      await tester.pumpWidget(_wrap(HiddenOpponentCard(message: message)));
      expect(find.text('鬼の手がかりはまだ出ません'), findsOneWidget);
      expect(find.textContaining('放出されると'), findsOneWidget);
      expect(find.text('あと 02:30 で表示されます'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('pillが無ければ出さない', (tester) async {
      const message = (
        icon: GameStatusIcon.allCaught,
        headline: '逃走者は全員捕まりました',
        detail: null,
        pill: null,
      );
      await tester.pumpWidget(
        _wrap(const HiddenOpponentCard(message: message)),
      );
      expect(find.text('逃走者は全員捕まりました'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_outlined), findsOneWidget);
      expect(find.textContaining('で表示されます'), findsNothing);
    });

    testWidgets('中身が短くても最低の高さを保ち、中身は縦の真ん中に置く', (tester) async {
      const message = (
        icon: GameStatusIcon.allCaught,
        headline: '逃走者は全員捕まりました',
        detail: null,
        pill: null,
      );
      await tester.pumpWidget(
        _wrap(const HiddenOpponentCard(message: message)),
      );
      final card = tester.getRect(find.byType(HiddenOpponentCard));
      expect(card.height, hiddenOpponentCardMinHeight);
      final headline = tester.getCenter(find.text('逃走者は全員捕まりました'));
      expect(headline.dy, greaterThan(card.top + card.height / 3));
    });

    testWidgets(
      '最低の高さは、差し替え先(チップ一覧+間隔8+手がかりカード)の最小と揃う',
      (tester) async {
        // 差し替え先と高さがずれると、相手が見えるようになった瞬間に地図が
        // ガタつく(issue #29フォローアップ)。ClueCardやチップの見た目を
        // 変えたらここが落ちるので、hiddenOpponentCardMinHeightを合わせ直す。
        final clueHeights = <double>[];
        for (final viewerRole in [UserRole.demon, UserRole.fugitive]) {
          for (final verdict in ClueVerdict.values) {
            for (final heightStatus in ClueHeightStatus.values) {
              await tester.pumpWidget(
                _wrap(
                  SizedBox(
                    width: 328,
                    child: ClueCard(
                      name: 'たろう',
                      role: UserRole.demon,
                      viewerRole: viewerRole,
                      verdict: verdict,
                      meter: 50,
                      matchCount: 2,
                      trend: ClueTrend.closer,
                      heightStatus: heightStatus,
                      opponentLowerHPa: 0.4,
                      onHelp: () {},
                      onCalibrate: () {},
                    ),
                  ),
                ),
              );
              clueHeights.add(tester.getSize(find.byType(ClueCard)).height);
            }
          }
        }
        await tester.pumpWidget(
          _wrap(
            SizedBox(
              width: 328,
              child: OpponentSelectorChips(
                roster: const [RoomUser(id: 'a', displayName: 'はなこ')],
                entries: const [
                  WifiProximityEntry(uid: 'a', level: ProximityLevel.close),
                ],
                selectedUid: 'a',
                onSelect: (_) {},
                leadingLabel: '逃走者\nを選ぶ',
              ),
            ),
          ),
        );
        final chipsHeight = tester
            .getSize(find.byType(OpponentSelectorChips))
            .height;
        final smallestClueCard = clueHeights.reduce((a, b) => a < b ? a : b);

        expect(
          hiddenOpponentCardMinHeight,
          chipsHeight + 8 + smallestClueCard,
        );
      },
    );
  });
}
