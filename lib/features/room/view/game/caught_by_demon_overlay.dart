import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/room/async_action.dart';
import 'package:kakureru/features/room/catch_rules.dart';
import 'package:kakureru/features/room/model/room_catch.dart';
import 'package:kakureru/features/room/view/game/catch_button_strip.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _undoBoxColor = Color(0x38141413);

/// 鬼に捕まった本人に出す「あなたは鬼になった」の全画面(issue #140)。
///
/// 取り消しの期限([catchUndoWindow])の間だけ「取り消す」を押せる。
/// 取り消すと捕獲が`catches`から消えるので、GamePage側の`shownCatch`が
/// nullになってこの画面も消える。
class CaughtByDemonOverlay extends HookConsumerWidget {
  /// [canUndo]は役割の書き換え(`acceptCaught`)が終わったか。終わる前に
  /// 取り消すと、取り消した後で鬼に書き換わってしまうため押せなくする。
  const CaughtByDemonOverlay({
    super.key,
    required this.roomId,
    required this.roomCatch,
    required this.demonName,
    required this.canUndo,
    required this.onContinue,
  });

  /// ルームID。
  final String roomId;

  /// 自分が捕まった捕獲。
  final RoomCatch roomCatch;

  /// 捕まえた鬼の名前。
  final String demonName;

  /// 「取り消す」を押せる状態か(期限とは別の条件)。
  final bool canUndo;

  /// 「鬼の画面へ」。
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offset = ref.watch(serverTimeOffsetProvider).value ?? 0;
    // 残り秒数とバーを滑らかに進めるための再描画用。
    final tick = useState(0);
    useEffect(() {
      final timer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => tick.value++,
      );
      return timer.cancel;
    }, const []);

    final undo = useAsyncAction(context);
    final nowMillis = serverNowMillis(offset);
    final undoable = isCatchUndoable(
      caughtAt: roomCatch.caughtAt,
      nowMillis: nowMillis,
    );
    final remainingSec = catchUndoRemainingSeconds(
      caughtAt: roomCatch.caughtAt,
      nowMillis: nowMillis,
    );
    final remainingMillis = (catchUndoDeadline(roomCatch.caughtAt) - nowMillis)
        .clamp(
          0,
          catchUndoWindow.inMilliseconds,
        );
    final progress = remainingMillis / catchUndoWindow.inMilliseconds;

    Future<void> handleUndo() async {
      final result = await undo.run(
        () => ref.read(roomRepositoryProvider).undoCatch(roomId, roomCatch),
      );
      if (!context.mounted) return;
      if (result.status == AsyncActionStatus.failed) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${result.error}')));
      }
    }

    return Material(
      color: catchSurfaceColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.directions_run, color: Colors.white, size: 44),
              const SizedBox(height: 16),
              const Text(
                'あなたは\n鬼になった',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$demonName に捕まりました',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'これから逃走者の位置が見えます。\n写真を撮る側にもなります。',
                style: TextStyle(color: Color(0xFFFFE0E0), fontSize: 13),
              ),
              const Spacer(),
              if (undoable)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _undoBoxColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'まだ捕まっていない場合は取り消せます',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: canUndo && !undo.isRunning
                              ? () => unawaited(handleUndo())
                              : null,
                          icon: const Icon(Icons.undo),
                          label: const Text(
                            '取り消す',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white54,
                            side: const BorderSide(color: Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'あと $remainingSec秒',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Text(
                  '捕獲が確定しました',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFFFE0E0), fontSize: 13),
                ),
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: catchSurfaceColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '鬼の画面へ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
