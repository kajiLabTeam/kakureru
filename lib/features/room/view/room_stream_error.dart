import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/features/room/error_message.dart';
import 'package:kakureru/features/room/view/leave_room_action.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// 部屋の購読(roomStreamProvider)が失敗したときに、画面いっぱいに出す案内。
///
/// 以前は `Text('エラー: $e')` だけを置いていたため、英語の例外文が出るうえに
/// 次に何をすればいいのか分からなかった(issue #95)。特にGamePageは
/// `canPop: false` で戻る導線が無いため、再読み込みが無いと詰む。
///
/// 再読み込みはproviderのinvalidateで行う(autoDisposeのStreamProviderなので、
/// 破棄して張り直すと購読がやり直される)。
///
/// 「ホームに戻る」も必ず添える。部屋が消えている・権限が無いといった原因では
/// 再読み込みが何度やっても直らず、案内文も「ホームに戻ってやり直して」と
/// 言うため、導線が無いとGamePage(`canPop: false`)で詰むのは同じ。戻るときは
/// 退出も済ませる(結果画面のdisposeによる退出と二重に走ることがあるが、
/// leaveRoomは同じ子ノードの削除なので二重でも害は無い)。
class RoomStreamErrorView extends ConsumerWidget {
  /// [roomId]の購読が[error]で失敗したことを伝える表示を作る。
  const RoomStreamErrorView({
    required this.roomId,
    required this.error,
    super.key,
  });

  /// 購読に失敗した部屋のID。再読み込みの対象。
  final String roomId;

  /// 購読が投げた例外。ユーザー向けの1文へ変換して表示する。
  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              userFacingErrorMessage(error),
              textAlign: TextAlign.center,
              style: const TextStyle(color: appMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.invalidate(roomStreamProvider(roomId)),
              child: const Text('再読み込み'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => leaveRoomAndGoHome(
                context,
                ref.read(roomRepositoryProvider),
                roomId,
                tag: 'RoomStreamErrorView',
              ),
              child: const Text('ホームに戻る'),
            ),
          ],
        ),
      ),
    );
  }
}
