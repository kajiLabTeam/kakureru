import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/role_visibility.dart';
import 'package:kakureru/features/room/view/game_result_page.dart';

/// ゲーム終了を検知したら結果画面へ遷移するフック。
///
/// 終了条件は[isGameOver](endsAtを過ぎた / meta/statusがFINISHED /
/// 進行中に逃走者が0人になった)。[tick]には毎秒更新されるカウンタを
/// 渡すこと。endsAt自体は変化しないため、これが無いとendsAtが確定した
/// 最初の一瞬しか判定されない。
///
/// [isShowingCaughtTransition]がtrueの間は遷移を見送る。「捕まった」
/// 確定演出(CaughtTransitionOverlay)の表示中に結果画面へ差し替えると
/// 演出が一瞬で消えてしまうため、演出を閉じた後のtick更新で改めて
/// 判定させる。
void useGameOverNavigation(
  BuildContext context, {
  required Room? room,
  required String roomId,
  required int serverTimeOffset,
  required int tick,
  required bool isShowingCaughtTransition,
}) {
  final hasNavigated = useRef(false);
  useEffect(() {
    if (hasNavigated.value || room == null) return null;
    if (isShowingCaughtTransition) return null;
    final gameOver = isGameOver(
      status: room.status,
      endsAt: room.endsAt,
      nowMillis: serverNowMillis(serverTimeOffset),
      hasFugitives: room.users.any((u) => u.role == UserRole.fugitive),
    );
    if (!gameOver) return null;
    hasNavigated.value = true;
    // useEffectはビルド直後に同期実行されるため、ここで即座にNavigatorを
    // 操作すると「ビルド中にNavigator操作をした」というエラーになり、
    // Navigatorが以降ずっと操作不能になる(useRestartRecoveryと同じ理由。
    // restart_recovery.dartのコメント参照)。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameResultPage(roomId: roomId),
        ),
      );
    });
    return null;
  }, [room?.status, room?.endsAt, tick, isShowingCaughtTransition]);
}
