import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/room/error_message.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/view/game_result_page.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _roomId = 'room1';
const _hostUid = 'host';
const _memberUid = 'member';

/// RTDBを叩かずに、「同じメンバーでもう一回」まわりの呼び出し・タイミングを
/// テストから制御するRoomRepositoryの差し替え(room_waiting_page_test.dartの
/// _FakeRoomRepositoryと同じ方針)。
class _FakeRoomRepository extends RoomRepository {
  Completer<void>? pendingRestart;
  int restartCalls = 0;
  final List<String> resetOwnRoleCalls = [];
  int leaveRoomCalls = 0;

  /// trueにすると[leaveRoom]が失敗する(退出に失敗してもホームへ戻れること
  /// を確かめるため)。
  bool leaveRoomFails = false;

  @override
  Future<void> restartRoom(String roomId) {
    restartCalls++;
    final completer = Completer<void>();
    pendingRestart = completer;
    return completer.future;
  }

  @override
  Future<void> resetOwnRoleForRestart(String roomId) async {
    resetOwnRoleCalls.add(roomId);
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    leaveRoomCalls++;
    if (leaveRoomFails) throw Exception('退出の失敗を模擬');
  }
}

/// センサー・RTDBを触らずに済ませるPressureViewModelの差し替え。巻き戻し後の
/// 待機画面(RoomWaitingPage)への遷移テストでのみ必要になる(それ以外の
/// テストではRoomWaitingPageまで到達しないため未使用でも問題ない)。
class _FakePressureViewModel extends PressureViewModel {
  @override
  PressureState build() => const PressureState();

  @override
  Future<void> init(String roomId) async {}
}

Room _room({
  required RoomStatus status,
  required List<RoomUser> users,
  String hostUserId = _hostUid,
}) => Room(
  id: _roomId,
  roomCode: '1234',
  hostUserId: hostUserId,
  status: status,
  createdAt: 0,
  setting: const RoomSetting(),
  users: users,
);

Future<StreamController<Room>> _pumpResultPage(
  WidgetTester tester, {
  required _FakeRoomRepository roomRepo,
  required String myUid,
  Room? initialRoom,
  PressureViewModel? pressureViewModel,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final controller = StreamController<Room>.broadcast();
  addTearDown(controller.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myUidProvider.overrideWithValue(myUid),
        roomRepositoryProvider.overrideWithValue(roomRepo),
        roomStreamProvider(_roomId).overrideWith((ref) => controller.stream),
        if (pressureViewModel != null)
          pressureViewModelProvider.overrideWith(() => pressureViewModel),
      ],
      child: const MaterialApp(home: GameResultPage(roomId: _roomId)),
    ),
  );
  await tester.pump();
  controller.add(
    initialRoom ??
        _room(
          status: RoomStatus.playing,
          users: const [
            RoomUser(id: _hostUid, displayName: 'ホスト', isHost: true),
          ],
        ),
  );
  await tester.pump();
  return controller;
}

/// 結果画面を「ホーム画面の上にpushされたルート」として出す。「ホームに戻る」
/// の`popUntil`がホームまで戻ることを見るには、下にルートが要るため
/// ([_pumpResultPage]は結果画面自体が最初のルートで、popUntilが何もしない)。
Future<void> _pumpResultPageOverHome(
  WidgetTester tester, {
  required _FakeRoomRepository roomRepo,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final controller = StreamController<Room>.broadcast();
  addTearDown(controller.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myUidProvider.overrideWithValue(_hostUid),
        roomRepositoryProvider.overrideWithValue(roomRepo),
        roomStreamProvider(_roomId).overrideWith((ref) => controller.stream),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GameResultPage(roomId: _roomId),
                  ),
                ),
                child: const Text('ホーム画面'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ホーム画面'));
  // 部屋が届くまで結果画面はCircularProgressIndicatorを出し続けるため、
  // ここでpumpAndSettleすると終わらない。遷移アニメーションぶんだけ進める。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  controller.add(
    _room(
      status: RoomStatus.finished,
      users: const [RoomUser(id: _hostUid, displayName: 'ホスト', isHost: true)],
    ),
  );
  await tester.pump();
}

void main() {
  group('勝敗の表示', () {
    testWidgets('逃走者が残っていれば「タイムアップ」と逃げ切り人数を出す', (tester) async {
      await _pumpResultPage(
        tester,
        roomRepo: _FakeRoomRepository(),
        myUid: _hostUid,
        initialRoom: _room(
          status: RoomStatus.finished,
          users: const [
            RoomUser(id: _hostUid, displayName: 'たくみ', isHost: true),
            RoomUser(
              id: _memberUid,
              displayName: 'りんや',
              role: UserRole.demon,
            ),
          ],
        ),
      );

      expect(find.text('タイムアップ'), findsOneWidget);
      expect(find.text('逃走者 1人 が逃げ切り'), findsOneWidget);
    });

    testWidgets('逃走者が全員鬼になっていれば鬼の勝ちを出す', (tester) async {
      await _pumpResultPage(
        tester,
        roomRepo: _FakeRoomRepository(),
        myUid: _hostUid,
        initialRoom: _room(
          status: RoomStatus.finished,
          users: const [
            RoomUser(
              id: _hostUid,
              displayName: 'たくみ',
              isHost: true,
              role: UserRole.demon,
            ),
            RoomUser(
              id: _memberUid,
              displayName: 'りんや',
              role: UserRole.demon,
            ),
          ],
        ),
      );

      expect(find.text('全員捕まりました'), findsOneWidget);
      expect(find.text('鬼の勝ち'), findsOneWidget);
    });
  });

  group('全参加者の表示', () {
    testWidgets('最後まで逃げ切った人と鬼になった人が2セクションに分かれて表示される', (tester) async {
      await _pumpResultPage(
        tester,
        roomRepo: _FakeRoomRepository(),
        myUid: _hostUid,
        initialRoom: _room(
          status: RoomStatus.playing,
          users: const [
            RoomUser(id: _hostUid, displayName: 'たくみ', isHost: true),
            RoomUser(
              id: _memberUid,
              displayName: 'りんや',
              role: UserRole.demon,
            ),
          ],
        ),
      );

      expect(find.text('最後まで逃げ切った人'), findsOneWidget);
      expect(find.text('たくみ'), findsOneWidget);
      expect(find.text('鬼になった人'), findsOneWidget);
      expect(find.text('りんや'), findsOneWidget);
    });

    testWidgets('該当者が0人のセクションは崩れずに案内文が出る', (tester) async {
      await _pumpResultPage(
        tester,
        roomRepo: _FakeRoomRepository(),
        myUid: _hostUid,
        initialRoom: _room(
          status: RoomStatus.playing,
          users: const [
            RoomUser(id: _hostUid, displayName: 'ホスト', isHost: true),
          ],
        ),
      );

      expect(find.text('最後まで逃げ切った人'), findsOneWidget);
      expect(find.text('ホスト'), findsOneWidget);
      expect(find.text('鬼になった人'), findsOneWidget);
      expect(find.text('該当者はいません'), findsOneWidget);
    });
  });

  group('同じメンバーでもう一回', () {
    testWidgets('ホストにはボタンが出て、押すとrestartRoomが呼ばれ送信中はスピナーになる', (tester) async {
      final roomRepo = _FakeRoomRepository();
      await _pumpResultPage(tester, roomRepo: roomRepo, myUid: _hostUid);

      expect(find.text('ホストの操作を待っています'), findsNothing);
      final button = find.widgetWithText(FilledButton, '同じメンバーでもう一回');
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pump();

      expect(roomRepo.restartCalls, 1);
      expect(find.widgetWithText(FilledButton, '同じメンバーでもう一回'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('失敗したらエラーを表示し、ボタンは押せる状態に戻る', (tester) async {
      final roomRepo = _FakeRoomRepository();
      await _pumpResultPage(tester, roomRepo: roomRepo, myUid: _hostUid);

      await tester.tap(find.widgetWithText(FilledButton, '同じメンバーでもう一回'));
      await tester.pump();

      roomRepo.pendingRestart!.completeError(Exception('巻き戻しの失敗を模擬'));
      await tester.pump();

      // 生の例外文ではなくユーザー向けの案内を出す(issue #95)。文言自体の
      // 網羅はerror_message_test.dart側で見る。
      expect(find.textContaining('巻き戻しの失敗を模擬'), findsNothing);
      expect(
        find.text(userFacingErrorMessage(Exception('巻き戻しの失敗を模擬'))),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, '同じメンバーでもう一回'),
        findsOneWidget,
      );
    });

    testWidgets('ホスト以外にはボタンが出ず、待っている旨だけ表示される', (tester) async {
      await _pumpResultPage(
        tester,
        roomRepo: _FakeRoomRepository(),
        myUid: _memberUid,
        initialRoom: _room(
          status: RoomStatus.playing,
          users: const [
            RoomUser(id: _hostUid, displayName: 'ホスト', isHost: true),
            RoomUser(id: _memberUid, displayName: 'メンバー'),
          ],
        ),
      );

      expect(
        find.widgetWithText(FilledButton, '同じメンバーでもう一回'),
        findsNothing,
      );
      expect(find.text('ホストの操作を待っています'), findsOneWidget);
    });
  });

  group('巻き戻し後の待機画面への復帰', () {
    testWidgets('自分が鬼だった場合、自分の役割をリセットしてから待機画面に遷移する', (tester) async {
      final roomRepo = _FakeRoomRepository();
      final controller = await _pumpResultPage(
        tester,
        roomRepo: roomRepo,
        myUid: _memberUid,
        pressureViewModel: _FakePressureViewModel(),
        initialRoom: _room(
          status: RoomStatus.playing,
          users: const [
            RoomUser(id: _hostUid, displayName: 'ホスト', isHost: true),
            RoomUser(
              id: _memberUid,
              displayName: 'メンバー',
              role: UserRole.demon,
            ),
          ],
        ),
      );

      controller.add(
        _room(
          status: RoomStatus.waiting,
          users: const [
            RoomUser(id: _hostUid, displayName: 'ホスト', isHost: true),
            RoomUser(
              id: _memberUid,
              displayName: 'メンバー',
              role: UserRole.demon,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(roomRepo.resetOwnRoleCalls, [_roomId]);
      expect(find.text('待機中'), findsOneWidget);
    });

    testWidgets('自分が逃走者のままだった場合は役割リセットを呼ばずに待機画面へ遷移する', (tester) async {
      final roomRepo = _FakeRoomRepository();
      final controller = await _pumpResultPage(
        tester,
        roomRepo: roomRepo,
        myUid: _hostUid,
        pressureViewModel: _FakePressureViewModel(),
        initialRoom: _room(
          status: RoomStatus.playing,
          users: const [
            RoomUser(id: _hostUid, displayName: 'ホスト', isHost: true),
            RoomUser(
              id: _memberUid,
              displayName: 'メンバー',
              role: UserRole.demon,
            ),
          ],
        ),
      );

      controller.add(
        _room(
          status: RoomStatus.waiting,
          users: const [
            RoomUser(id: _hostUid, displayName: 'ホスト', isHost: true),
            RoomUser(
              id: _memberUid,
              displayName: 'メンバー',
              role: UserRole.demon,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(roomRepo.resetOwnRoleCalls, isEmpty);
      expect(find.text('待機中'), findsOneWidget);
    });
  });

  group('ホームに戻る', () {
    testWidgets('押すとleaveRoomが1回呼ばれ、ホームまで戻る', (tester) async {
      // 結果画面へはpushReplacementで来るため待機画面のdisposeによる退出を
      // 通らない。ここで消さないと幽霊参加者が残る(issue #94)。
      final roomRepo = _FakeRoomRepository();
      await _pumpResultPageOverHome(tester, roomRepo: roomRepo);

      await tester.tap(find.widgetWithText(OutlinedButton, 'ホームに戻る'));
      await tester.pumpAndSettle();

      expect(roomRepo.leaveRoomCalls, 1);
      expect(find.text('ホーム画面'), findsOneWidget);
      expect(find.byType(GameResultPage), findsNothing);
    });

    testWidgets('退出に失敗してもホームには戻れる', (tester) async {
      final roomRepo = _FakeRoomRepository()..leaveRoomFails = true;
      await _pumpResultPageOverHome(tester, roomRepo: roomRepo);

      await tester.tap(find.widgetWithText(OutlinedButton, 'ホームに戻る'));
      await tester.pumpAndSettle();

      expect(roomRepo.leaveRoomCalls, 1);
      expect(find.text('ホーム画面'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
