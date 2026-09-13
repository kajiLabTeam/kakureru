import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/view/room_home_page.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

FilledButton _createRoomButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'ルームを作る'));

OutlinedButton _joinRoomButton(WidgetTester tester) => tester
    .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'ルームに参加'));

/// ホーム画面を立ち上げ、保存名がまだ届いていない状態にする。
///
/// 実機では保存名の読み込み(SharedPreferences)が非同期なので、保存名は
/// 画面が最初に描画された後から届く。overrideWithにFuture以外の値を
/// 渡すとriverpodがそれを同期的にAsyncDataにしてしまい、初回buildの
/// 時点で既に解決済みになる。それでは実機の順序を再現できず、
/// 「保存名が届いたフレームでボタンが有効にならない」バグを
/// 見逃してしまうため、Completerで届くタイミングを明示的に握る。
Future<Completer<String?>> _pumpHomePage(WidgetTester tester) async {
  final completer = Completer<String?>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        savedDisplayNameProvider.overrideWith((ref) => completer.future),
      ],
      child: const MaterialApp(home: RoomHomePage()),
    ),
  );
  // roomViewModelProviderも初期状態はAsyncLoadingで、1マイクロタスク後に
  // 解決して再buildを起こす。その分をここで先に消化しておかないと、
  // 保存名が届いた後の検証が「保存名とは無関係な再build」に助けられて
  // しまい、テストが回帰を検出できなくなる。
  await tester.pump();
  return completer;
}

/// 保存名を解決し、それが反映される最初の1フレームだけを描画する。
///
/// ここで余分にpumpすると、復元がbuild後(useEffect等)に行われる実装でも
/// 次のフレームで追いついてしまうため、pumpは1回だけに留める。
Future<void> _deliverSavedDisplayName(
  WidgetTester tester,
  Completer<String?> completer,
  String? savedDisplayName,
) async {
  completer.complete(savedDisplayName);
  // Futureの解決はマイクロタスクなので、先に流しておかないと1回の
  // pumpではproviderの更新による再buildが間に合わない。
  await tester.idle();
  await tester.pump();
}

Future<void> _pumpHomePageWithSavedName(
  WidgetTester tester,
  String? savedDisplayName,
) async {
  final completer = await _pumpHomePage(tester);
  await _deliverSavedDisplayName(tester, completer, savedDisplayName);
}

void main() {
  group('名前の復元とボタンの有効/無効', () {
    testWidgets('保存済みの名前がある場合、入力欄に触れなくてもボタンが押せる', (tester) async {
      await _pumpHomePageWithSavedName(tester, 'たろう');

      expect(find.text('たろう'), findsOneWidget);
      expect(_createRoomButton(tester).onPressed, isNotNull);
      expect(_joinRoomButton(tester).onPressed, isNotNull);
      // 復元直後でも赤字のエラー表示は出ない。
      expect(find.text('名前を入力してください'), findsNothing);
    });

    testWidgets('保存済みの名前が無い(初回起動)場合、ボタンは無効のまま', (tester) async {
      await _pumpHomePageWithSavedName(tester, null);

      expect(_createRoomButton(tester).onPressed, isNull);
      expect(_joinRoomButton(tester).onPressed, isNull);
    });

    testWidgets('保存済みの名前が空文字の場合、ボタンは無効のまま', (tester) async {
      await _pumpHomePageWithSavedName(tester, '');

      expect(_createRoomButton(tester).onPressed, isNull);
      expect(_joinRoomButton(tester).onPressed, isNull);
    });

    testWidgets('保存済みの名前が文字数上限を超えている場合、ボタンは無効のまま', (tester) async {
      await _pumpHomePageWithSavedName(tester, 'あ' * 11);

      expect(_createRoomButton(tester).onPressed, isNull);
      expect(_joinRoomButton(tester).onPressed, isNull);
    });

    testWidgets('ユーザーが既に入力し始めていたら保存名で上書きしない', (tester) async {
      final completer = await _pumpHomePage(tester);

      // 保存名が届く前にユーザーが入力を始める。
      await tester.enterText(find.byType(TextField).first, 'じろう');
      await tester.pump();

      await _deliverSavedDisplayName(tester, completer, 'たろう');

      expect(find.text('じろう'), findsOneWidget);
      expect(find.text('たろう'), findsNothing);
    });
  });
}
