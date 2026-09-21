import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/error_message.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/view/room_stream_error.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _roomId = 'room1';

/// RTDBを叩かずに退出の呼び出しだけ記録するRoomRepositoryの差し替え。
class _FakeRoomRepository extends RoomRepository {
  final List<String> leaveRoomCalls = [];

  @override
  Future<void> leaveRoom(String roomId) async {
    leaveRoomCalls.add(roomId);
  }
}

void main() {
  testWidgets('生の例外文ではなくユーザー向けの案内を出す', (tester) async {
    final error = Exception('[firebase_database/permission-denied] boom');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: RoomStreamErrorView(roomId: _roomId, error: error),
          ),
        ),
      ),
    );

    expect(find.text(userFacingErrorMessage(error)), findsOneWidget);
    expect(find.textContaining('firebase_database'), findsNothing);
  });

  testWidgets('「再読み込み」で部屋の購読が張り直される', (tester) async {
    // GamePageはcanPop:falseで戻る導線が無いため、再読み込みが無いと購読が
    // 失敗した時点で詰む(issue #95)。
    var subscribeCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomStreamProvider(_roomId).overrideWith((ref) {
            subscribeCount++;
            return const Stream<Room>.empty();
          }),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                // 画面側と同じく購読しておかないと、invalidateしても
                // 張り直しが起きない(autoDisposeのため)。
                ref.watch(roomStreamProvider(_roomId));
                return RoomStreamErrorView(
                  roomId: _roomId,
                  error: Exception('購読の失敗を模擬'),
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(subscribeCount, 1);

    await tester.tap(find.widgetWithText(OutlinedButton, '再読み込み'));
    await tester.pump();

    expect(subscribeCount, 2);
  });

  testWidgets('「ホームに戻る」で退出してホームまで戻る', (tester) async {
    // 部屋が消えている・権限が無いといった原因では再読み込みが何度やっても
    // 直らないため、戻る導線が無いと詰む(issue #95)。戻るときは退出も
    // 済ませて幽霊参加者を残さない(issue #94)。
    final roomRepo = _FakeRoomRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [roomRepositoryProvider.overrideWithValue(roomRepo)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: RoomStreamErrorView(
                          roomId: _roomId,
                          error: Exception('購読の失敗を模擬'),
                        ),
                      ),
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
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'ホームに戻る'));
    await tester.pumpAndSettle();

    expect(roomRepo.leaveRoomCalls, [_roomId]);
    expect(find.text('ホーム画面'), findsOneWidget);
    expect(find.byType(RoomStreamErrorView), findsNothing);
  });
}
