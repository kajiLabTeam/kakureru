import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/core/utils/avatar_initial.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/restart_recovery.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/room/single_flight_action.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _demonColor = Color(0xFFE5484D);

/// ゲーム終了画面。最後まで逃げ切った人(終了時点で逃走者)と鬼になった人
/// (終了時点で鬼)の2セクションで全参加者を表示し、ホストは「同じメンバーで
/// もう一回」で同じ部屋を待機状態に巻き戻せる(issue #44)。
///
/// 勝敗表示・捕まった時刻の表示はスコープ外(別issue)。
class GameResultPage extends HookConsumerWidget {
  const GameResultPage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final myUid = ref.watch(myUidProvider);
    final isRestarting = useState(false);
    final restartError = useState<Object?>(null);
    final restartGuard = useMemoized(SingleFlightAction.new);

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
                  child: const Text('ゲーム終了', style: TextStyle(fontSize: 20)),
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
                          onPressed: isRestarting.value
                              ? null
                              : () => unawaited(
                                  restartGuard.run(() async {
                                    isRestarting.value = true;
                                    restartError.value = null;
                                    try {
                                      await ref
                                          .read(roomRepositoryProvider)
                                          .restartRoom(roomId);
                                    } on Object catch (e) {
                                      // awaitの後はこのページが既に破棄されて
                                      // いる可能性がある。巻き戻しを検知した
                                      // useRestartRecoveryがRoomWaitingPageへ
                                      // pushReplacementすると、旧ルートは遷移
                                      // アニメーション完了(約300ms)後に破棄
                                      // されるため、RTDBのack がそれより遅い
                                      // とdispose済みのHookElementへの
                                      // setStateになり、unawaited経由の未処理
                                      // 非同期エラーとして表に出てしまう。
                                      if (context.mounted) {
                                        restartError.value = e;
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        isRestarting.value = false;
                                      }
                                    }
                                  }),
                                ),
                          child: isRestarting.value
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
                      if (restartError.value != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${restartError.value}',
                            style: const TextStyle(color: _demonColor),
                          ),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                        child: const Text('ホームに戻る'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('エラー: $e')),
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
