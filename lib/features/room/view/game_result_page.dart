import 'package:flutter/material.dart';

/// ゲーム終了を伝える仮の画面。勝敗表示等は未実装で、鬼になった人の一覧と
/// ホームに戻る導線のみ持つ。
class GameResultPage extends StatelessWidget {
  const GameResultPage({super.key, required this.demonNames});

  /// ゲーム終了時点で役割がDEMONだった参加者の表示名(捕まって鬼になった
  /// 人も含む)。
  final List<String> demonNames;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ゲーム終了')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ゲーム終了', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 16),
            Text(
              demonNames.isEmpty ? '鬼: 不明' : '鬼だった人: ${demonNames.join('、')}',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('ホームに戻る'),
            ),
          ],
        ),
      ),
    );
  }
}
