import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/core/utils/avatar_initial.dart';
import 'package:kakureru/features/room/async_action.dart';
import 'package:kakureru/features/room/error_message.dart';
import 'package:kakureru/features/room/game_outcome.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/restart_recovery.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/room/view/room_stream_error.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _demonColor = Color(0xFFE5484D);

/// ゲーム終了画面。最後まで逃げ切った人(終了時点で逃走者)と鬼になった人
/// (終了時点で鬼)の2セクションで全参加者を表示し、ホストは「同じメンバーで
/// もう一回」で同じ部屋を待機状態に巻き戻せる(issue #44)。
///
/// ヘッダーには勝敗(逃走者の逃げ切り / 鬼の勝ち)を出す(issue #30)。
/// 捕まった時刻の表示はスコープ外(別issue)。
class GameResultPage extends HookConsumerWidget {
  const GameResultPage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final myUid = ref.watch(myUidProvider);
    final restart = useAsyncAction(context);

    // 巻き戻し(「同じメンバーでもう一回」)の検知・自分の役割リセット・
    // 待機画面への遷移は、GamePage側でも同じ処理が要るため共通フックに
    // している(useRestartRecoveryのドキュメント参照)。
    useRestartRecovery(ref, context, roomId: roomId);

    return Scaffold(
      body: SafeArea(
        child: roomAsync.when(
          data: (room) {
            final isHost = room.hostUserId == myUid;
            final survivedFugitives = room.users
                .where((u) => u.role == UserRole.fugitive)
                .toList();
            final demons = room.users
                .where((u) => u.role == UserRole.demon)
                .toList();

            // 勝敗(UI改修モック2a-08)。終了時点で逃走者が残っていれば
            // 逃げ切り、0人なら鬼の勝ち(issue #30)。
            final outcome = determineGameOutcome(
              survivedFugitiveCount: survivedFugitives.length,
            );
            final outcomeText = describeGameOutcome(
              outcome: outcome,
              survivedFugitiveCount: survivedFugitives.length,
            );

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: appFaintBorder, width: 2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outcomeText.title,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        outcomeText.summary,
                        style: TextStyle(
                          fontSize: 13,
                          color: outcome == GameOutcome.demonsWon
                              ? _demonColor
                              : roleThemeOf(UserRole.fugitive).color,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        '最後まで逃げ切った人',
                        style: TextStyle(color: appMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      if (survivedFugitives.isEmpty)
                        const Text(
                          '該当者はいません',
                          style: TextStyle(color: appMuted),
                        ),
                      for (final user in survivedFugitives)
                        _ResultUserTile(
                          user: user,
                          color: roleThemeOf(UserRole.fugitive).color,
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        '鬼になった人',
                        style: TextStyle(color: appMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      if (demons.isEmpty)
                        const Text(
                          '該当者はいません',
                          style: TextStyle(color: appMuted),
                        ),
                      for (final user in demons)
                        _ResultUserTile(
                          user: user,
                          color: roleThemeOf(UserRole.demon).color,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (isHost)
                        FilledButton(
                          // awaitの後はこのページが既に破棄されている可能性
                          // がある。巻き戻しを検知したuseRestartRecoveryが
                          // RoomWaitingPageへpushReplacementすると、旧ルート
                          // は遷移アニメーション完了(約300ms)後に破棄される
                          // ため、RTDBのackがそれより遅いとdispose済みの
                          // HookElementへのsetStateになる。mountedの確認は
                          // useAsyncActionが内側で行う。
                          onPressed: restart.isRunning
                              ? null
                              : () => unawaited(
                                  restart.run(
                                    () => ref
                                        .read(roomRepositoryProvider)
                                        .restartRoom(roomId),
                                  ),
                                ),
                          child: restart.isRunning
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('同じメンバーでもう一回'),
                        )
                      else
                        const Text(
                          'ホストの操作を待っています',
                          style: TextStyle(color: appMuted, fontSize: 12),
                        ),
                      if (restart.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            userFacingErrorMessage(restart.error!),
                            style: const TextStyle(color: _demonColor),
                          ),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          debugPrint(
                            '[GameResultPage] home button pressed '
                            'canPop=${Navigator.of(context).canPop()}',
                          );
                          // 結果画面へはGamePageからのpushReplacementで来る
                          // ため、待機画面のdisposeによる退出を通らない。
                          // ここで消さないと、ホストが「同じメンバーでもう
                          // 一回」を押したときに、帰ったはずの人が幽霊参加者
                          // として人数・キャリブレーション判定・鬼のランダム
                          // 選出に混ざる(issue #94)。
                          //
                          // awaitせずに投げっぱなしにするのは、退出の成否で
                          // ホームへ戻れなくならないようにするため(RTDBの
                          // 往復が遅い/失敗する状況でも画面を詰まらせない)。
                          // 失敗はログだけに留める(ユーザーはもう画面を
                          // 離れているので、出しても対処できない)。
                          unawaited(
                            ref
                                .read(roomRepositoryProvider)
                                .leaveRoom(roomId)
                                .catchError((Object e) {
                                  debugPrint(
                                    '[GameResultPage] leaveRoom 失敗: $e',
                                  );
                                }),
                          );
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                          debugPrint('[GameResultPage] popUntil called');
                        },
                        child: const Text('ホームに戻る'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => RoomStreamErrorView(roomId: roomId, error: e),
        ),
      ),
    );
  }
}

/// 結果画面の参加者1人ぶんの行(アバター+名前)。
class _ResultUserTile extends StatelessWidget {
  const _ResultUserTile({required this.user, required this.color});

  final RoomUser user;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: appFaintBorder, width: 2),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color,
            child: Text(
              avatarInitial(user.displayName),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 9),
          Text(user.displayName, style: const TextStyle(fontSize: 13.5)),
        ],
      ),
    );
  }
}
