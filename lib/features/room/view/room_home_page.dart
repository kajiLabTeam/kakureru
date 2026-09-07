import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/features/room/player_name_validation.dart';
import 'package:kakureru/features/room/view/room_waiting_page.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

class RoomHomePage extends HookConsumerWidget {
  const RoomHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final codeController = useTextEditingController();
    final state = ref.watch(roomViewModelProvider);

    // TextFieldの入力を毎回のbuildで拾えるよう、controllerの変更を購読して
    // 再描画をトリガーする(controllerだけではウィジェットは自動で更新されない)。
    useListenable(nameController);
    final nameError = validatePlayerName(nameController.text);

    // 名前が無効な間は「作成/参加」ボタン自体を無効化するため、押してから
    // 気づかせる必要はない。ただし最初から赤字を出すと圧が強いので、
    // 一度でも入力欄に触れた後だけエラー表示する(未入力の初期状態では
    // 出さない)。
    final hasTouchedName = useState(false);
    final showNameError = hasTouchedName.value ? nameError : null;

    // ルーム作成/参加は同じroomViewModelProviderを共有しているため、
    // state.isLoadingだけでは押されたのがどちらのボタンか区別できない。
    // ローディング表示(スピナー)を押した側だけに出すため、ローカルに
    // どちらを押したかを持つ。
    final isCreating = useState(false);
    final isJoining = useState(false);

    // 前回保存済みの名前を、入力欄がまだ空のうちだけ初期値として復元する
    // (ユーザーが既に入力し始めていたら上書きしない)。
    final savedDisplayName = ref.watch(savedDisplayNameProvider);
    final hasRestoredName = useRef(false);
    useEffect(() {
      final saved = savedDisplayName.asData?.value;
      if (saved != null && saved.isNotEmpty && !hasRestoredName.value) {
        hasRestoredName.value = true;
        if (nameController.text.isEmpty) {
          nameController.text = saved;
        }
      }
      return null;
    }, [savedDisplayName.asData?.value]);

    ref.listen(roomViewModelProvider, (prev, next) {
      if (!next.isLoading) {
        isCreating.value = false;
        isJoining.value = false;
      }
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
              maxLength: playerNameMaxLength,
              onChanged: (_) => hasTouchedName.value = true,
              decoration: InputDecoration(
                labelText: '名前',
                errorText: _nameErrorMessage(showNameError),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: appFaintBorder, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ホストとして',
                    style: TextStyle(fontSize: 12, color: appMuted),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: state.isLoading || nameError != null
                        ? null
                        : () {
                            isCreating.value = true;
                            ref
                                .read(roomViewModelProvider.notifier)
                                .createRoom(nameController.text);
                          },
                    child: isCreating.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('ルームを作る'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: appFaintBorder, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ルームコードで参加',
                    style: TextStyle(fontSize: 12, color: appMuted),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ルームコード(4桁)'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: state.isLoading || nameError != null
                        ? null
                        : () {
                            isJoining.value = true;
                            ref
                                .read(roomViewModelProvider.notifier)
                                .joinRoom(
                                  codeController.text,
                                  nameController.text,
                                );
                          },
                    child: isJoining.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('ルームに参加'),
                  ),
                ],
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  '${state.error}',
                  style: const TextStyle(color: Color(0xFFE5484D)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String? _nameErrorMessage(PlayerNameError? error) {
  switch (error) {
    case PlayerNameError.empty:
      return '名前を入力してください';
    case PlayerNameError.tooLong:
      return '名前は$playerNameMaxLength文字以内で入力してください';
    case null:
      return null;
  }
}
