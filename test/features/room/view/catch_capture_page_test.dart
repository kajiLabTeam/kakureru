import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/view/catch_capture_page.dart';

Future<({List<String> calls})> _pump(
  WidgetTester tester, {
  bool isPicking = false,
}) async {
  final calls = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: CatchCaptureView(
        fugitiveName: 'たろう',
        remainingFugitives: 2,
        isPicking: isPicking,
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

    // 送信は画面を閉じた後に裏で行うので、この画面に「送信中」は無い。
    testWidgets('カメラを開いている間は、撮影ボタンを押せない', (tester) async {
      final result = await _pump(tester, isPicking: true);

      expect(find.text('送信中…'), findsNothing);
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

  group('sendCatchPhoto', () {
    test('アップロードしてから捕獲に付け、成功を伝える', () async {
      final calls = <String>[];
      final message = await sendCatchPhoto(
        upload: () async => calls.add('upload'),
        attach: () async => calls.add('attach'),
      );

      expect(calls, ['upload', 'attach']);
      expect(message, '写真をみんなに送りました');
    });

    test('捕獲が取り消されていたら、その理由を伝える', () async {
      final message = await sendCatchPhoto(
        upload: () async {},
        attach: () async => throw const CatchAlreadyUndoneException(),
      );

      expect(message, '捕獲が取り消されたため、写真は送りませんでした');
    });

    // 画面は閉じた後なので、撮り直しは促さない。例外も外へ投げない。
    test('アップロードに失敗したら、付けずに送れなかったことを伝える', () async {
      final calls = <String>[];
      final message = await sendCatchPhoto(
        upload: () async => throw Exception('network'),
        attach: () async => calls.add('attach'),
      );

      expect(calls, isEmpty);
      expect(message, '捕まえた瞬間の写真を送れませんでした');
    });
  });
}
