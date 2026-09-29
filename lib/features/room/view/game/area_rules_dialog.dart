import 'package:flutter/material.dart';
import 'package:kakureru/features/room/area_rules.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';
import 'package:kakureru/features/room/view/game/game_tone_theme.dart';

/// 使ってよい場所・ダメな場所の一覧を出すモーダル(issue #108)。
///
/// 文言は[allowedAreaRules] / [forbiddenAreaRules]が持っており、ここは
/// 並べるだけ。項目が増えても読めるように本文はスクロールできる。
///
/// 見た目は待機・ゲーム画面と同じトーン(白地+細枠のカード、太字の濃い
/// インク、丸い黒ボタン)に揃える。アプリ全体のテーマから切り離すために
/// `Theme`で包むのは`become_demon_confirm_dialog.dart`と同じ考え方で、
/// その上にゲーム画面のトーンを重ねる。
Future<void> showAreaRulesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Theme(
      data: buildGameToneTheme(ThemeData(useMaterial3: true)),
      child: AlertDialog(
        title: const Text('使用していい範囲'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 緑=逃走者/肯定、赤=鬼/警告。ゲーム画面の役割の色と同じ。
              _RuleSection(
                icon: Icons.check_circle,
                color: roleThemeOf(UserRole.fugitive).color,
                title: '使ってよい',
                places: allowedAreaRules,
              ),
              const SizedBox(height: 12),
              _RuleSection(
                icon: Icons.block,
                color: roleThemeOf(UserRole.demon).color,
                title: '使用不可',
                places: forbiddenAreaRules,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            // テーマの既定は横幅いっぱい(Size.fromHeight)だが、actionsの
            // 並び(OverflowBar)の中では幅が決まらないので大きさを指定する。
            style: FilledButton.styleFrom(minimumSize: const Size(112, 44)),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    ),
  );
}

/// 見出し1行 + 場所の箇条書きを、役割の色で縁取ったカードにまとめる。
class _RuleSection extends StatelessWidget {
  const _RuleSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.places,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> places;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withValues(alpha: 0.06), Colors.white),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final place in places)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 3),
              child: Text(
                '・$place',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: gameInk,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
