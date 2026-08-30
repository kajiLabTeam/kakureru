import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/left_user_notifications.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _roomId = 'room1';

// createdAtは通常固定でよいが、Roomは値等価(Freezed)なのでusersの内容が
// 同じRoomを続けて流すとroomStreamProviderが「変化なし」とみなし後続の
// listenerへ配信しない。同一usersのスナップショットを複数回流したいテスト
// では、createdAtを変えて明示的に別の値として扱わせる。
Room _roomWith(List<RoomUser> users, {int createdAt = 0}) {
  return Room(
    id: _roomId,
    roomCode: '1234',
    hostUserId: 'alice',
    status: RoomStatus.waiting,
    createdAt: createdAt,
    setting: const RoomSetting(),
    users: users,
  );
}

class _Harness extends HookConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useLeftUserNotifications(ref, context, _roomId);
    return const Scaffold(body: SizedBox());
  }
}

void main() {
  testWidgets('離脱したユーザーの名前でSnackBarを表示する', (tester) async {
    final controller = StreamController<Room>.broadcast();
    addTearDown(controller.close);

    const alice = RoomUser(id: 'alice', displayName: 'アリス');
    const bob = RoomUser(id: 'bob', displayName: 'ボブ');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomStreamProvider(
            _roomId,
          ).overrideWith((ref) => controller.stream),
        ],
        child: const MaterialApp(home: _Harness()),
      ),
    );
    await tester.pump();

    controller.add(_roomWith([alice, bob]));
    await tester.pump();
    expect(find.text('ボブさんが抜けました'), findsNothing);

    controller.add(_roomWith([alice]));
    await tester.pump();

    expect(find.text('ボブさんが抜けました'), findsOneWidget);
  });

  testWidgets('誰も抜けていなければSnackBarを表示しない', (tester) async {
    final controller = StreamController<Room>.broadcast();
    addTearDown(controller.close);

    const alice = RoomUser(id: 'alice', displayName: 'アリス');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomStreamProvider(
            _roomId,
          ).overrideWith((ref) => controller.stream),
        ],
        child: const MaterialApp(home: _Harness()),
      ),
    );
    await tester.pump();

    controller.add(_roomWith([alice]));
    await tester.pump();
    controller.add(_roomWith([alice]));
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('isCurrentでない側のページは二重に通知しない', (tester) async {
    // RoomWaitingPage→GamePageのpushReplacement中、旧ページ・新ページの
    // 両方が一瞬同時にマウントされ同じroomStreamProviderをlistenする状況を、
    // 通常のpush(下のページがisCurrent=falseのまま残り続ける点は同じ)で
    // 再現する。
    final controller = StreamController<Room>.broadcast();
    addTearDown(controller.close);
    final navigatorKey = GlobalKey<NavigatorState>();

    const alice = RoomUser(id: 'alice', displayName: 'アリス');
    const bob = RoomUser(id: 'bob', displayName: 'ボブ');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomStreamProvider(
            _roomId,
          ).overrideWith((ref) => controller.stream),
        ],
        child: MaterialApp(navigatorKey: navigatorKey, home: const _Harness()),
      ),
    );
    await tester.pump();
    controller.add(_roomWith([alice, bob]));
    await tester.pump();

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const _Harness()),
    );
    await tester.pumpAndSettle();

    // ref.listenは登録後の変化にしか反応しない(初期値では発火しない)ため、
    // 新しくマウントされた側のフックにも一度スナップショットを送って
    // 「直前のusers一覧」を確立させておく(このイベント自体はどちら側も
    // 通知しない)。createdAtを変えて前回と別の値として配信させる。
    controller.add(_roomWith([alice, bob], createdAt: 1));
    await tester.pump();

    controller.add(_roomWith([alice]));
    await tester.pump();

    expect(find.text('ボブさんが抜けました'), findsOneWidget);

    // isCurrentでない側(下のページ)まで通知していれば、ScaffoldMessengerの
    // キューに2件目が積まれているはず。表示中の1件目を即座に消化させ、
    // 2件目が続けて出てこないことを確認する(出てきたら二重通知)。
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.text('ボブさんが抜けました'), findsNothing);
  });
}
