import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/view/game_page.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

class RoomWaitingPage extends HookConsumerWidget {
  final String roomId;
  const RoomWaitingPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));
    final isStarting = useState(false);
    final startError = useState<Object?>(null);
    final hasNavigated = useState(false);

    ref.listen(roomStreamProvider(roomId), (prev, next) {
      final room = next.value;
      if (room != null && room.status == RoomStatus.playing && !hasNavigated.value) {
        hasNavigated.value = true;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => GamePage(roomId: roomId)));
      }
    });

    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('待機中')),
      body: roomAsync.when(
        data: (room) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'ルームコード: ${room.roomCode}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const Text('参加者'),
            Expanded(
              child: ListView(
                children: room.users
                    .map(
                      (u) => ListTile(
                        title: Text(u.displayName),
                        trailing: u.isHost ? const Text('ホスト') : null,
                      ),
                    )
                    .toList(),
              ),
            ),
            if (room.hostUserId == myUid)
              Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  onPressed: isStarting.value
                      ? null
                      : () async {
                          isStarting.value = true;
                          startError.value = null;
                          try {
                            await ref.read(roomRepositoryProvider).startGame(roomId);
                          } on Object catch (e) {
                            startError.value = e;
                          } finally {
                            isStarting.value = false;
                          }
                        },
                  child: const Text('ゲーム開始'),
                ),
              ),
            if (startError.value != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('${startError.value}', style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}
