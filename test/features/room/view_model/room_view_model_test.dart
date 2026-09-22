import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/room_join_error.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// joinRoomが呼ばれたかどうかだけを記録するRoomRepository。
///
/// 本物はFirebaseを叩くため、メソッドを丸ごとoverrideして差し替える
/// (`RoomRepository`は`.instance`の解決をlateにしてあるので、サブクラスの
/// 暗黙の`super()`ではFirebaseに触れない)。
class _RecordingRoomRepository extends RoomRepository {
  bool joinCalled = false;

  @override
  Future<String> joinRoom({
    required String code,
    required String displayName,
  }) async {
    joinCalled = true;
    return 'room-1';
  }
}

void main() {
  group('RoomViewModel.joinRoom', () {
    test('4桁でないコードはRTDBを読みにいく前に弾く', () async {
      // 画面側でも参加ボタンを無効にしているが、別の入口が増えたときに
      // 空や短いコードで`roomCodes/`を読むと権限エラーの英文が出るため、
      // ViewModelでも弾いておく(issue #96)。
      final repository = _RecordingRoomRepository();
      final container = ProviderContainer(
        overrides: [roomRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await container
          .read(roomViewModelProvider.notifier)
          .joinRoom('12', 'たろう');

      expect(
        container.read(roomViewModelProvider).error,
        RoomJoinError.invalidCode,
      );
      expect(repository.joinCalled, isFalse);
    });
  });
}
