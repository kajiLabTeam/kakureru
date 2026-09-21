import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/room_create_error.dart';
import 'package:kakureru/features/room/room_join_error.dart';
import 'package:kakureru/features/room/view/room_home_page.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

Finder _nameField() => find.byType(TextField).first;

Finder _codeField() => find.byType(TextField).last;

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

/// joinRoomが必ず[error]で失敗するRoomViewModel。本物はFirebaseを叩くため
/// widgetテストでは呼べないので、失敗の中身だけを注入する。
class _FailingRoomViewModel extends RoomViewModel {
  _FailingRoomViewModel(this.error);

  final Object error;

  @override
  Future<void> joinRoom(String code, String displayName) async {
    state = AsyncError(error, StackTrace.empty);
  }
}

/// 名前とコードを埋めて「ルームに参加」を押し、[error]で失敗させる。
Future<void> _tapJoinAndFail(WidgetTester tester, Object error) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        savedDisplayNameProvider.overrideWith((ref) async => 'たろう'),
        roomViewModelProvider.overrideWith(() => _FailingRoomViewModel(error)),
      ],
      child: const MaterialApp(home: RoomHomePage()),
    ),
  );
  await tester.pump();

  await tester.enterText(_codeField(), '1234');
  await tester.pump();

  await tester.tap(find.widgetWithText(OutlinedButton, 'ルームに参加'));
  await tester.pump();
}

void main() {
  group('名前の復元とボタンの有効/無効', () {
    testWidgets('保存済みの名前がある場合、入力欄に触れなくてもボタンが押せる', (tester) async {
      await _pumpHomePageWithSavedName(tester, 'たろう');

      expect(find.text('たろう'), findsOneWidget);
      expect(_createRoomButton(tester).onPressed, isNotNull);
      // 参加はルームコードも要るので、名前だけ復元された時点ではまだ押せない。
      expect(_joinRoomButton(tester).onPressed, isNull);
      // 復元直後でも赤字のエラー表示は出ない。
      expect(find.text('名前を入力してください'), findsNothing);
      expect(find.text('ルームコードを入力してください'), findsNothing);
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
      await tester.enterText(_nameField(), 'じろう');
      await tester.pump();

      await _deliverSavedDisplayName(tester, completer, 'たろう');

      expect(find.text('じろう'), findsOneWidget);
      expect(find.text('たろう'), findsNothing);
    });
  });

  group('ルームコードの入力', () {
    testWidgets('名前があってもコードが4桁そろうまで参加ボタンは押せない', (tester) async {
      await _pumpHomePageWithSavedName(tester, 'たろう');

      await tester.enterText(_codeField(), '12');
      await tester.pump();
      expect(_joinRoomButton(tester).onPressed, isNull);

      await tester.enterText(_codeField(), '1234');
      await tester.pump();
      expect(_joinRoomButton(tester).onPressed, isNotNull);

      // 「ルームを作る」側はコードと無関係に押せるままであること。
      expect(_createRoomButton(tester).onPressed, isNotNull);
    });

    testWidgets('コードが4桁でも名前が無ければ参加ボタンは押せない', (tester) async {
      await _pumpHomePageWithSavedName(tester, null);

      await tester.enterText(_codeField(), '1234');
      await tester.pump();

      expect(_joinRoomButton(tester).onPressed, isNull);
    });

    testWidgets('数字以外は入力されず、5桁目も入らない', (tester) async {
      await _pumpHomePageWithSavedName(tester, 'たろう');

      await tester.enterText(_codeField(), '12a3');
      await tester.pump();
      expect(tester.widget<TextField>(_codeField()).controller!.text, '123');

      await tester.enterText(_codeField(), '12345');
      await tester.pump();
      expect(tester.widget<TextField>(_codeField()).controller!.text, '1234');
      expect(_joinRoomButton(tester).onPressed, isNotNull);
    });

    testWidgets('コード欄に触れるまでは赤字を出さず、触れた後は理由が出る', (tester) async {
      await _pumpHomePageWithSavedName(tester, 'たろう');

      expect(find.text('ルームコードを入力してください'), findsNothing);
      expect(find.text('ルームコードは4桁の数字です'), findsNothing);

      await tester.enterText(_codeField(), '12');
      await tester.pump();
      expect(find.text('ルームコードは4桁の数字です'), findsOneWidget);

      await tester.enterText(_codeField(), '');
      await tester.pump();
      expect(find.text('ルームコードを入力してください'), findsOneWidget);

      await tester.enterText(_codeField(), '1234');
      await tester.pump();
      expect(find.text('ルームコードは4桁の数字です'), findsNothing);
      expect(find.text('ルームコードを入力してください'), findsNothing);
    });
  });

  group('参加に失敗したときの表示', () {
    testWidgets('終了したルームには日本語の理由が出る', (tester) async {
      await _tapJoinAndFail(tester, RoomJoinError.finished);

      expect(find.text('この部屋は終了しています'), findsOneWidget);
    });

    testWidgets('存在しないコードには日本語の理由が出る', (tester) async {
      await _tapJoinAndFail(tester, RoomJoinError.notFound);

      expect(find.text('そのコードの部屋が見つかりません'), findsOneWidget);
      // `Exception: `の接頭辞や英文が見えないこと。
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('コードの形式エラーも日本語の理由が出る', (tester) async {
      // 参加ボタンの無効化をすり抜けた場合の保険(ViewModel側の検証)。
      await _tapJoinAndFail(tester, RoomJoinError.invalidCode);

      expect(find.text('ルームコードは4桁の数字です'), findsOneWidget);
    });

    testWidgets('ルーム作成側の失敗理由も日本語で出る', (tester) async {
      // コードが埋まって発行できなかったのに「電波が悪い」と案内しない。
      await _tapJoinAndFail(tester, RoomCreateError.codeExhausted);

      expect(
        find.text('ルームコードが空いていません。少し待ってからもう一度お試しください'),
        findsOneWidget,
      );
    });

    testWidgets('想定外の失敗でも生の例外文は出さない', (tester) async {
      await _tapJoinAndFail(tester, Exception('permission-denied'));

      expect(find.textContaining('permission-denied'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.text('通信に失敗しました。電波の良い場所でもう一度お試しください'), findsOneWidget);
    });
  });
}
