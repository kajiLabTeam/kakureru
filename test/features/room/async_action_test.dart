import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/async_action.dart';

/// [useAsyncAction]をそのまま画面に見立てた最小のテスト用ウィジェット。
///
/// 「送信中ならスピナー、失敗ならエラー行」という4画面共通の使い方を
/// そのまま再現し、ボタンを押すと[action]を走らせる。
class _Harness extends HookWidget {
  const _Harness({required this.action, this.onResult});

  final Future<void> Function() action;
  final void Function(AsyncActionResult result)? onResult;

  @override
  Widget build(BuildContext context) {
    final send = useAsyncAction(context);
    return Column(
      children: [
        FilledButton(
          onPressed: () async {
            final result = await send.run(action);
            onResult?.call(result);
          },
          child: Text(send.isRunning ? '送信中' : '送信'),
        ),
        if (send.error != null) Text('エラー: ${send.error}'),
      ],
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Future<void> Function() action,
  void Function(AsyncActionResult result)? onResult,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _Harness(action: action, onResult: onResult),
      ),
    ),
  );
}

void main() {
  testWidgets('実行中はisRunningがtrueになり、終わると戻る', (tester) async {
    final gate = Completer<void>();
    await _pump(tester, action: () => gate.future);

    expect(find.text('送信'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('送信中'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('送信'), findsOneWidget);
  });

  testWidgets('例外はerrorに入り、画面に出せる', (tester) async {
    await _pump(tester, action: () async => throw Exception('通信失敗'));

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('通信失敗'), findsOneWidget);
    // 失敗してもフラグは下りる(押せないまま固まらない)。
    expect(find.text('送信'), findsOneWidget);
  });

  testWidgets('成功した実行の開始時に、前回のエラーは消える', (tester) async {
    var shouldFail = true;
    await _pump(
      tester,
      action: () async {
        if (shouldFail) throw Exception('通信失敗');
      },
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('通信失敗'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('通信失敗'), findsNothing);
  });

  testWidgets('実行中の二重押しは走らせず、skippedを返す', (tester) async {
    final gate = Completer<void>();
    var calls = 0;
    final results = <AsyncActionStatus>[];

    await _pump(
      tester,
      action: () {
        calls++;
        return gate.future;
      },
      onResult: (result) => results.add(result.status),
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    // RTDBの往復が終わる前に押し直す状況。
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(calls, 1);

    gate.complete();
    await tester.pumpAndSettle();

    expect(results, contains(AsyncActionStatus.skipped));
    expect(results, contains(AsyncActionStatus.succeeded));
  });

  testWidgets('結果はawait直後に読める(errorはrunの戻り値に入る)', (tester) async {
    AsyncActionResult? captured;
    await _pump(
      tester,
      action: () async => throw Exception('通信失敗'),
      onResult: (result) => captured = result,
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(captured?.status, AsyncActionStatus.failed);
    // AsyncAction.errorはリビルドを経ないと更新されないため、await直後に
    // 結果を使いたい呼び出し側のためにrunの戻り値にも入れている。
    expect(captured?.error.toString(), contains('通信失敗'));
  });

  testWidgets('画面が破棄された後に完了しても、setStateで落ちない', (tester) async {
    final gate = Completer<void>();
    await _pump(tester, action: () => gate.future);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    // 送信中に画面を差し替える(結果画面→待機画面の巻き戻しと同じ状況)。
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    gate.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
