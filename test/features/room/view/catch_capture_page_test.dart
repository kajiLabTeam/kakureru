import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/view/catch_capture_page.dart';
import 'package:kakureru/features/room/view/game/catch_target_sheet.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

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
    testWidgets('撮って送ると捕まえたことになると案内し、撮影ボタンを押せる', (tester) async {
      final result = await _pump(tester);

      expect(find.text('写真を撮って送ると、捕まえたことになります'), findsOneWidget);
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

  group('runCatchFlow', () {
    const outdoor = (uid: 'f', indoor: false);
    const indoor = (uid: 'f', indoor: true);

    test('撮らずに戻ったら、選択からやり直して選び直した内容で撮影画面を開く', () async {
      final choices = <CatchTargetChoice?>[outdoor, indoor];
      final captured = <CatchTargetChoice>[];
      final caught = await runCatchFlow(
        chooseTarget: () async => choices.removeAt(0),
        capture: (choice) async {
          captured.add(choice);
          // 1回目は撮らずに戻る、2回目は送る。
          return captured.length == 2;
        },
      );

      expect(caught, isTrue);
      expect(captured, [outdoor, indoor]);
    });

    test('選択シートを閉じたら、撮影画面を開かずにやめる', () async {
      var captureCalls = 0;
      final caught = await runCatchFlow(
        chooseTarget: () async => null,
        capture: (_) async {
          captureCalls++;
          return true;
        },
      );

      expect(caught, isFalse);
      expect(captureCalls, 0);
    });

    test('撮らずに戻った後に選択シートを閉じたら、捕まえずにやめる', () async {
      final choices = <CatchTargetChoice?>[outdoor, null];
      final caught = await runCatchFlow(
        chooseTarget: () async => choices.removeAt(0),
        capture: (_) async => false,
      );

      expect(caught, isFalse);
    });
  });

  group('CatchCapturePage', () {
    Future<({List<String> calls, List<bool?> results})> pumpPage(
      WidgetTester tester, {
      required Future<Uint8List?> Function() pickPhoto,
      Future<String> Function()? onCatch,
    }) async {
      final calls = <String>[];
      final results = <bool?>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomStreamProvider.overrideWith(
              (ref, _) => const Stream<Room>.empty(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final sent = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => CatchCapturePage(
                        roomId: 'r',
                        fugitiveUid: 'f',
                        fugitiveName: 'たろう',
                        canTakePhoto: true,
                        pickPhoto: pickPhoto,
                        onCatch:
                            onCatch ??
                            () async {
                              calls.add('catch');
                              return 'c1';
                            },
                        sendPhoto: ({required catchId, required bytes}) async {
                          calls.add('send:$catchId');
                          return '写真をみんなに送りました';
                        },
                      ),
                    ),
                  );
                  results.add(sent);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (calls: calls, results: results);
    }

    testWidgets('写真を撮ったら捕獲を書いて写真を送り、送ったことを返して閉じる', (tester) async {
      final r = await pumpPage(
        tester,
        pickPhoto: () async => Uint8List.fromList([1, 2, 3]),
      );

      await tester.tap(find.byIcon(Icons.photo_camera));
      await tester.pumpAndSettle();

      expect(r.calls, ['catch', 'send:c1']);
      expect(r.results, [true]);
      expect(find.byType(CatchCapturePage), findsNothing);
    });

    testWidgets('カメラを開いて撮らずに閉じたら、捕獲を書かずに撮影画面に留まる', (tester) async {
      final r = await pumpPage(tester, pickPhoto: () async => null);

      await tester.tap(find.byIcon(Icons.photo_camera));
      await tester.pumpAndSettle();

      expect(r.calls, isEmpty);
      expect(r.results, isEmpty);
      expect(find.byType(CatchCapturePage), findsOneWidget);
    });

    testWidgets('撮らずに「戻る」で閉じたら、捕獲を書かずに送っていないことを返す', (tester) async {
      final r = await pumpPage(tester, pickPhoto: () async => null);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();

      expect(r.calls, isEmpty);
      expect(r.results, [null]);
    });

    testWidgets('捕獲の送信に失敗したら、写真を送らずに撮影画面に留まる', (tester) async {
      final r = await pumpPage(
        tester,
        pickPhoto: () async => Uint8List.fromList([1]),
        onCatch: () async => throw Exception('network'),
      );

      await tester.tap(find.byIcon(Icons.photo_camera));
      await tester.pumpAndSettle();

      expect(r.calls, isEmpty);
      expect(r.results, isEmpty);
      expect(find.byType(CatchCapturePage), findsOneWidget);
      expect(find.textContaining('「捕まえた」の送信に失敗しました'), findsOneWidget);
    });
  });
}
