import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/opponent_roster_status.dart';
import 'package:kakureru/features/room/view/game/game_status_cards.dart';

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
  });
}
