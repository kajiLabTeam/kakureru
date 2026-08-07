import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// ゲーム中の画面。中身はまだ無く、残り時間の表示のみを行う仮実装。
class GamePage extends HookConsumerWidget {
  const GamePage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final offset = ref.watch(serverTimeOffsetProvider).value ?? 0;

    // 残り時間を1秒ごとに再計算するためのティッカー。
    // .info/serverTimeOffset 自体はズレが変化した時にしか流れてこないため、
    // 表示を毎秒更新するにはこのタイマーで再描画をトリガーする必要がある。
    final tick = useState(0);
    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        tick.value++;
      });
      return timer.cancel;
    }, const []);

    return Scaffold(
      appBar: AppBar(title: const Text('ゲーム中')),
      body: roomAsync.when(
        data: (room) {
          final endsAt = room.endsAt;
          final remainingSec = endsAt == null
              ? null
              : ((endsAt - serverNowMillis(offset)) / 1000).ceil();

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('ゲーム中'),
                const SizedBox(height: 16),
                Text(
                  remainingSec == null
                      ? '残り時間: 計算中...'
                      : '残り時間: ${remainingSec < 0 ? 0 : remainingSec}秒',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}
