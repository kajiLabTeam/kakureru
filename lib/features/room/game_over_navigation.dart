import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/game_alerts.dart';
import 'package:kakureru/features/room/view/game_result_page.dart';

/// ゲーム終了が検知されたら結果画面へ遷移するフック。
///
/// **終了したかどうかの判定はここではやらない**。判定は[GameAlerts]が
/// 1秒ごとのタイマーで回していて、画面が消えていても進む(issue #71)。
/// ここはその結果(`isGameOver`)を見て画面を差し替えるだけ。
///
/// 検知と遷移を分けているのは、Navigator操作にフレームが要るため。画面が
/// 消えている間は遷移させる意味も手段も無く、点けた瞬間の再描画でここが
/// 走って結果画面に着けばよい(そのとき終了の通知は[GameAlerts]が既に
/// 出している)。
///
/// [isShowingCaughtTransition]がtrueの間は遷移を見送る。「捕まった」
/// 確定演出(CaughtTransitionOverlay)の表示中に結果画面へ差し替えると
/// 演出が一瞬で消えてしまうため、演出を閉じた後の再描画で改めて判定させる。
void useGameOverNavigation(
  WidgetRef ref,
  BuildContext context, {
  required String roomId,
  required bool isShowingCaughtTransition,
}) {
  final isGameOver = ref.watch(gameAlertsProvider).isGameOver;
  final hasNavigated = useRef(false);
  useEffect(() {
    if (hasNavigated.value || !isGameOver) return null;
    if (isShowingCaughtTransition) return null;
    hasNavigated.value = true;
    // useEffectはビルド直後に同期実行されるため、ここで即座にNavigatorを
    // 操作すると「ビルド中にNavigator操作をした」というエラーになり、
    // Navigatorが以降ずっと操作不能になる(useRestartRecoveryと同じ理由。
    // restart_recovery.dartのコメント参照)。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      // pop中(「ホームに戻る」を押した直後の約300ms)はルートがまだ生きて
      // いてmountedもtrueのままで、そこでpushReplacementすると「今いちばん上
      // にある生きたルート」=ホームが結果画面に置き換わる。結果画面が最初の
      // ルートになると、その「ホームに戻る」(popUntil(isFirst))は何もせず、
      // 退出済みのまま詰む。購読エラー画面からホームへ戻れるようにしたことで
      // この窓ができた(restart_recovery.dartと同じガード。issue #94/#95)。
      if (ModalRoute.of(context)?.isActive != true) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => GameResultPage(roomId: roomId),
        ),
      );
    });
    return null;
  }, [isGameOver, isShowingCaughtTransition]);
}
