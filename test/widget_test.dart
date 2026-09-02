import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/view/room_home_page.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// createRoom/joinRoomの完了タイミングをテストから制御するための
/// RoomViewModelの差し替え。本物はFirebase/device_info_plusを叩くため
/// widgetテストでは呼べず、Completerで代わりに結果を注入する。
class _ControllableRoomViewModel extends RoomViewModel {
  Completer<String?>? createCompleter;
  Completer<String?>? joinCompleter;
  var createCallCount = 0;
  var joinCallCount = 0;

  @override
  Future<void> createRoom(String displayName) async {
    createCallCount++;
    final completer = Completer<String?>();
    createCompleter = completer;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => completer.future);
  }

  @override
  Future<void> joinRoom(String code, String displayName) async {
    joinCallCount++;
    final completer = Completer<String?>();
    joinCompleter = completer;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => completer.future);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('RoomHomePage shows create/join room controls', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RoomHomePage())),
    );

    expect(find.text('かくれんぼ'), findsOneWidget);
    expect(find.text('ルームを作る'), findsOneWidget);
    expect(find.text('ルームに参加'), findsOneWidget);
  });

  testWidgets('初期表示では名前が空でエラーは出ず、ボタンは無効化されている', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RoomHomePage())),
    );
    await tester.pump();

    expect(find.text('名前を入力してください'), findsNothing);

    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'ルームを作る'),
    );
    final joinButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'ルームに参加'),
    );
    expect(createButton.onPressed, isNull);
    expect(joinButton.onPressed, isNull);
  });

  testWidgets('名前を入力すればボタンが有効化される', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RoomHomePage())),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'たろう');
    await tester.pump();

    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'ルームを作る'),
    );
    final joinButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'ルームに参加'),
    );
    expect(createButton.onPressed, isNotNull);
    expect(joinButton.onPressed, isNotNull);
  });

  testWidgets('名前を入力してから空に戻すとエラーが表示され、ボタンは無効のまま', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RoomHomePage())),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'たろう');
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();

    expect(find.text('名前を入力してください'), findsOneWidget);
    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'ルームを作る'),
    );
    expect(createButton.onPressed, isNull);
  });

  testWidgets('空白のみの名前を入力するとエラーが表示される', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: RoomHomePage())),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();

    expect(find.text('名前を入力してください'), findsOneWidget);
  });

  testWidgets('「ルームを作る」を押すと送信中はスピナーが出て両ボタンとも無効化される', (
    tester,
  ) async {
    final model = _ControllableRoomViewModel();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomViewModelProvider.overrideWith(() => model),
        ],
        child: const MaterialApp(home: RoomHomePage()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'たろう');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'ルームを作る'));
    await tester.pump();

    expect(model.createCallCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('ルームを作る'), findsNothing);

    final createButtonWhileLoading = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    final joinButtonWhileLoading = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton),
    );
    expect(createButtonWhileLoading.onPressed, isNull);
    expect(joinButtonWhileLoading.onPressed, isNull);

    // 失敗させて、スピナーが消えてエラー表示・再操作可能に戻ることを確認する。
    model.createCompleter!.completeError(Exception('boom'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('ルームを作る'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('「ルームに参加」を押すと送信中はスピナーが出る', (tester) async {
    final model = _ControllableRoomViewModel();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomViewModelProvider.overrideWith(() => model),
        ],
        child: const MaterialApp(home: RoomHomePage()),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'たろう');
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'ルームに参加'));
    await tester.pump();

    expect(model.joinCallCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('ルームに参加'), findsNothing);

    model.joinCompleter!.completeError(Exception('boom'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('ルームに参加'), findsOneWidget);
  });
}
