import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/room/error_message.dart';
import 'package:kakureru/features/room/model/room_catch.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/view/game/caught_by_demon_overlay.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// 取り消しの完了をテストから制御するRoomRepositoryの差し替え。
class _FakeRoomRepository extends RoomRepository {
  final List<String> undoCalls = [];
  Completer<void>? pendingUndo;

  @override
  Future<void> undoCatch(String roomId, RoomCatch roomCatch) {
    undoCalls.add(roomCatch.id);
    final completer = Completer<void>();
    pendingUndo = completer;
    return completer.future;
  }
}

final _permissionDenied = FirebaseException(
  plugin: 'database',
  code: 'permission-denied',
  message: "Client doesn't have permission",
);

RoomCatch _catch() => RoomCatch(
  id: 'c1',
  demonUserId: 'demon',
  fugitiveUserId: 'me',
  caughtAt: DateTime.now().millisecondsSinceEpoch,
);

/// GamePageの代わり。[useUndoCatch]を持ち、[showOverlay]の間だけ全画面を出す。
/// 実物と同じく、全画面は取り消しの完了を待たずに消せる。
class _Host extends HookConsumerWidget {
  const _Host({required this.showOverlay});

  final ValueNotifier<bool> showOverlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final undo = useUndoCatch(context, ref, roomId: 'room1');
    final visible = useValueListenable(showOverlay);
    final roomCatch = useMemoized(_catch);
    return Scaffold(
      body: visible
          ? CaughtByDemonOverlay(
              roomId: 'room1',
              roomCatch: roomCatch,
              demonName: '鬼',
              canUndo: true,
              isUndoing: undo.isRunning,
              onUndo: () => unawaited(undo.run(roomCatch)),
              onContinue: () {},
            )
          : const SizedBox.shrink(),
    );
  }
}

Future<_FakeRoomRepository> _pumpHost(
  WidgetTester tester,
  ValueNotifier<bool> showOverlay,
) async {
  final repo = _FakeRoomRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomRepositoryProvider.overrideWithValue(repo),
        serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: MaterialApp(home: _Host(showOverlay: showOverlay)),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  group('undoCatchErrorMessage', () {
    test('期限切れは、その理由をそのまま出す', () {
      expect(
        undoCatchErrorMessage(const CatchUndoExpiredException()),
        '取り消せる時間が過ぎました',
      );
    });

    test('通信できないときは、その理由をそのまま出す', () {
      expect(
        undoCatchErrorMessage(const CatchUndoUnavailableException()),
        '通信できないため取り消せませんでした',
      );
    });

    // Firebaseの英語のエラー文などを、そのまま画面に出さない。
    test('それ以外の例外は利用者向けの文言に置き換える', () {
      final error = FirebaseException(
        plugin: 'database',
        code: 'permission-denied',
        message: "Client doesn't have permission",
      );

      final message = undoCatchErrorMessage(error);

      expect(message, userFacingErrorMessage(error));
      expect(message, isNot(contains('permission')));
    });
  });

  group('useUndoCatch(issue #144)', () {
    // undoCatchは手元の捕獲を先に消すので、サーバーの拒否が返る前に全画面が
    // 閉じる。それでもエラーがゲーム画面に出ること。
    testWidgets('全画面が先に閉じても、拒否されたらSnackBarで知らせる', (tester) async {
      final showOverlay = ValueNotifier(true);
      final repo = await _pumpHost(tester, showOverlay);

      await tester.tap(find.text('取り消す'));
      await tester.pump();
      expect(repo.undoCalls, ['c1']);

      showOverlay.value = false;
      await tester.pump();
      expect(find.byType(CaughtByDemonOverlay), findsNothing);

      repo.pendingUndo!.completeError(_permissionDenied);
      await tester.pump();

      expect(
        find.text(userFacingErrorMessage(_permissionDenied)),
        findsOneWidget,
      );
      expect(find.textContaining('permission'), findsNothing);
      // タイマーを止めるため、最後に全画面の無い状態で閉じる。
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('成功したらSnackBarは出さない', (tester) async {
      final showOverlay = ValueNotifier(true);
      final repo = await _pumpHost(tester, showOverlay);

      await tester.tap(find.text('取り消す'));
      await tester.pump();
      showOverlay.value = false;
      repo.pendingUndo!.complete();
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('実行中は「取り消す」を押せず、二重に送らない', (tester) async {
      final showOverlay = ValueNotifier(true);
      final repo = await _pumpHost(tester, showOverlay);

      await tester.tap(find.text('取り消す'));
      await tester.pump();
      await tester.tap(find.text('取り消す'));
      await tester.pump();

      expect(repo.undoCalls, ['c1']);
      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('取り消す'),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);

      repo.pendingUndo!.complete();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
