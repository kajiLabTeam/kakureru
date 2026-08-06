import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../view_model/room_view_model.dart';
import 'room_waiting_page.dart';

class RoomHomePage extends HookConsumerWidget {
  const RoomHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final codeController = useTextEditingController();
    final state = ref.watch(roomViewModelProvider);

    ref.listen(roomViewModelProvider, (prev, next) {
      final roomId = next.value;
      if (roomId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RoomWaitingPage(roomId: roomId),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('かくれんぼ')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '名前'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: state.isLoading
                  ? null
                  : () => ref
                        .read(roomViewModelProvider.notifier)
                        .createRoom(nameController.text),
              child: const Text('ルームを作る'),
            ),
            const Divider(height: 48),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ルームコード(4桁)'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: state.isLoading
                  ? null
                  : () => ref
                        .read(roomViewModelProvider.notifier)
                        .joinRoom(
                          codeController.text,
                          nameController.text,
                        ),
              child: const Text('ルームに参加'),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  '${state.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
