import 'package:flutter/material.dart';
import 'package:kakureru/features/room/area_rules.dart';

/// 「使ってよい」の見出し色。docs/ui-mockup-2a.html の緑(逃走者/肯定)に合わせる。
const _allowedColor = Color(0xFF4A9C5D);

/// 「使用不可」の見出し色。同じくモックの赤(鬼/警告)に合わせる。
const _forbiddenColor = Color(0xFFE5484D);

/// 使ってよい場所・ダメな場所の一覧を出すモーダル(issue #108)。
///
/// 文言は[allowedAreaRules] / [forbiddenAreaRules]が持っており、ここは
/// 並べるだけ。項目が増えても読めるように本文はスクロールできる。
///
/// ダイアログをアプリ全体のテーマから切り離すために`Theme`で包むのは
/// `become_demon_confirm_dialog.dart`と同じ考え方。
Future<void> showAreaRulesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Theme(
      data: ThemeData(useMaterial3: true),
      child: AlertDialog(
        title: const Text('使用していい範囲'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _RuleSection(
                icon: Icons.check_circle,
                color: _allowedColor,
                title: '使ってよい',
                places: allowedAreaRules,
              ),
              SizedBox(height: 16),
              _RuleSection(
                icon: Icons.block,
                color: _forbiddenColor,
                title: '使用不可',
                places: forbiddenAreaRules,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    ),
  );
}

/// 見出し1行 + 場所の箇条書き。
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final place in places)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 2),
            child: Text('・$place'),
          ),
      ],
    );
  }
}
