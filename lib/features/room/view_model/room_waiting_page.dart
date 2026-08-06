import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../view_model/room_view_model.dart';

class RoomWaitingPage extends ConsumerWidget {
  final String roomId;
  const RoomWaitingPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomStreamProvider(roomId));

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
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}
