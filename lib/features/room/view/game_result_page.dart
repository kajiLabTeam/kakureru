import 'package:flutter/material.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/core/utils/avatar_initial.dart';

const _demonColor = Color(0xFFE5484D);

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
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                    '鬼だった人',
                    style: TextStyle(color: appMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  if (demonNames.isEmpty)
                    const Text('不明', style: TextStyle(color: appMuted)),
                  for (final name in demonNames)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: appFaintBorder, width: 2),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: _demonColor,
                            child: Text(
                              avatarInitial(name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Text(name, style: const TextStyle(fontSize: 13.5)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('ホームに戻る'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
