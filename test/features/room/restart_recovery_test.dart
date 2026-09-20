import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/features/pressure/view_model/pressure_view_model.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/restart_recovery.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _roomId = 'room1';
const _hostUid = 'host';
const _memberUid = 'member';

/// [useRestartRecovery]を単体で呼ぶだけの最小Widget。GamePage/GameResultPage
/// 双方に共通するこのフックの挙動(issue #44)を、それらのページが抱える
/// 他の重いprovider(位置情報・Wi-Fi・気圧・BLE)無しでテストするために使う。
class _Harness extends HookConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useRestartRecovery(ref, context, roomId: _roomId);
    return const Scaffold(body: Text('harness'));
  }
}

class _FakeRoomRepository extends RoomRepository {
  final List<String> resetOwnRoleCalls = [];

  @override
  Future<void> resetOwnRoleForRestart(String roomId) async {
    resetOwnRoleCalls.add(roomId);
  }

  @override
  Future<void> leaveRoom(String roomId) async {}
}

class _FakePressureViewModel extends PressureViewModel {
  @override
  PressureState build() => const PressureState();

  @override
  Future<void> init(String roomId) async {}
}

Room _room({required RoomStatus status, required List<RoomUser> users}) => Room(
  id: _roomId,
  roomCode: '1234',
  hostUserId: _hostUid,
  status: status,
  createdAt: 0,
  setting: const RoomSetting(),
  users: users,
);

Future<StreamController<Room>> _pumpHarness(
  WidgetTester tester, {
  required _FakeRoomRepository roomRepo,
  required String myUid,
  required Room initialRoom,
}) async {
  final controller = StreamController<Room>.broadcast();
  addTearDown(controller.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myUidProvider.overrideWithValue(myUid),
        roomRepositoryProvider.overrideWithValue(roomRepo),
        pressureViewModelProvider.overrideWith(_FakePressureViewModel.new),
        roomStreamProvider(_roomId).overrideWith((ref) => controller.stream),
      ],
      child: const MaterialApp(home: _Harness()),
    ),
  );
  await tester.pump();
  controller.add(initialRoom);
  await tester.pump();
  return controller;
}

void main() {
  testWidgets(
    'PLAYING→WAITINGへの変化を検知すると、鬼だった自分の役割をリセットして待機画面へ遷移する'
    '(GamePageに留まっている端末が結果画面を経由せずに巻き戻される想定)',
    (tester) async {
      final roomRepo = _FakeRoomRepository();
      final controller = await _pumpHarness(
        tester,
        roomRepo: roomRepo,
        myUid: _memberUid,
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
    },
  );

  testWidgets(
    '最初に観測したスナップショットが既にWAITINGでも、鬼だった自分の役割をリセットして待機画面へ遷移する'
    '(巻き戻しより後に画面がマウントされた/ストリームが再購読された場合の取りこぼし防止)',
    (tester) async {
      final roomRepo = _FakeRoomRepository();
      await _pumpHarness(
        tester,
        roomRepo: roomRepo,
        myUid: _memberUid,
        initialRoom: _room(
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
      await tester.pumpAndSettle();

      expect(roomRepo.resetOwnRoleCalls, [_roomId]);
      expect(find.text('待機中'), findsOneWidget);
    },
  );

  testWidgets('自分が鬼でなければroleのリセットは呼ばず、待機画面へ戻すだけ', (tester) async {
    final roomRepo = _FakeRoomRepository();
    await _pumpHarness(
      tester,
      roomRepo: roomRepo,
      myUid: _memberUid,
      initialRoom: _room(
        status: RoomStatus.waiting,
        users: const [
          RoomUser(id: _hostUid, displayName: 'ホスト', isHost: true),
          RoomUser(id: _memberUid, displayName: 'メンバー'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(roomRepo.resetOwnRoleCalls, isEmpty);
    expect(find.text('待機中'), findsOneWidget);
  });

  testWidgets('巻き戻しの検知は一度だけで、その後のWAITING更新で二重に発火しない', (tester) async {
    final roomRepo = _FakeRoomRepository();
    final controller = await _pumpHarness(
      tester,
      roomRepo: roomRepo,
      myUid: _memberUid,
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

    for (var i = 0; i < 3; i++) {
      controller.add(
        _room(
          status: RoomStatus.waiting,
          users: [
            const RoomUser(id: _hostUid, displayName: 'ホスト', isHost: true),
            RoomUser(
              id: _memberUid,
              displayName: 'メンバー$i',
              role: UserRole.demon,
            ),
          ],
        ),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(roomRepo.resetOwnRoleCalls, [_roomId]);
  });
}
