import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/left_user_detection.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// 誰かが離脱(leftAtが立った、またはusers/{uid}がRTDBから消えた)したら
/// 「(名前)さんが抜けました」、猶予時間内に復帰(leftAtが消えた)したら
/// 「(名前)さんが戻ってきました」を、待機画面・ゲーム画面のどちらでも
/// SnackBarで知らせるフック。
///
/// 直前のusersスナップショットをuseRefで保持し、次のスナップショットとの
/// 差分(detectLeftUsers/detectRejoinedUsers)から検出する。このウィジェット
/// が破棄されたら追跡もやめてよい一時状態なのでhooksで持つ
/// (AGENTS.mdの状態管理規約)。
void useLeftUserNotifications(
  WidgetRef ref,
  BuildContext context,
  String roomId,
) {
  final previousUsers = useRef<List<RoomUser>?>(null);
  ref.listen(roomStreamProvider(roomId), (prev, next) {
    final nextUsers = next.value?.users;
    if (nextUsers == null) return;

    final previous = previousUsers.value;
    if (previous != null) {
      final leftUsers = detectLeftUsers(previous: previous, current: nextUsers);
      final rejoinedUsers = detectRejoinedUsers(
        previous: previous,
        current: nextUsers,
      );
      // pushReplacement直後は旧ページ・新ページの両方が一瞬マウントされ、
      // どちらも同じroomStreamProviderをlistenしているため、ここでガード
      // しないと同じ離脱/復帰を二重にSnackBar表示してしまう
      // (RoomWaitingPage→GamePageの遷移中に誰かが離脱した場合など)。
      // 表示中でなくなった側のページはisCurrentがfalseになるので、それを
      // 使って「今表示されているページだけが通知する」を保証する。
      // ModalRoute.of(context)がnullになる状況(Navigator配下に無い等)は
      // 通常起こらないが、万一nullなら二重通知よりは「通知しない」側に倒す。
      if ((leftUsers.isNotEmpty || rejoinedUsers.isNotEmpty) &&
          context.mounted &&
          (ModalRoute.of(context)?.isCurrent ?? false)) {
        for (final user in leftUsers) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            SnackBar(content: Text('${user.displayName}さんが抜けました')),
          );
        }
        for (final user in rejoinedUsers) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            SnackBar(content: Text('${user.displayName}さんが戻ってきました')),
          );
        }
      }
    }
    previousUsers.value = nextUsers;
  });
}
