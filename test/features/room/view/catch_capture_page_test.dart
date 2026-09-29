import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/view/catch_capture_page.dart';

Future<({List<String> calls})> _pump(
  WidgetTester tester, {
  bool isPicking = false,
  bool isSending = false,
}) async {
  final calls = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: CatchCaptureView(
        fugitiveName: 'たろう',
        remainingFugitives: 2,
        isPicking: isPicking,
        isSending: isSending,
        canTakePhoto: true,
        onTakePhoto: () => calls.add('take'),
      ),
    ),
  );
  return (calls: calls);
}

void main() {
  group('CatchCaptureView', () {
    // 撮ったらそのまま送る(確認画面は無い)ことを画面上でも伝える。
    testWidgets('撮るとそのまま全員に送ることを案内し、撮影ボタンを押せる', (tester) async {
      final result = await _pump(tester);

      expect(find.text('記念に1枚どうぞ。撮るとそのまま全員に送ります'), findsOneWidget);
      expect(find.text('写真を撮る'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.photo_camera));
      expect(result.calls, ['take']);
    });

    testWidgets('送信中は「送信中…」と出し、撮影ボタンを押せない', (tester) async {
      final result = await _pump(tester, isSending: true);

      expect(find.text('送信中…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(InkWell).first);
      expect(result.calls, isEmpty);
    });

    // 撮る前に勝手に閉じないよう、時間制限(自動で戻るカウントダウン)は無い。
    testWidgets('時間制限のカウントダウンを出さない', (tester) async {
      await _pump(tester);

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('秒後にゲーム画面へもどります'), findsNothing);
    });

    testWidgets('「撮らずに続ける」ボタンは出さない', (tester) async {
      await _pump(tester);

      expect(find.text('撮らずに続ける'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('確認画面(みんなに送る・撮り直す・送らない)は出さない', (tester) async {
      await _pump(tester);

      expect(find.text('みんなに送る'), findsNothing);
      expect(find.text('撮り直す'), findsNothing);
      expect(find.text('送らない'), findsNothing);
    });
  });
}
