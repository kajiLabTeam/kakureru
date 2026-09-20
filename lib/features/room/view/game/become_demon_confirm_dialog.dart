import 'package:flutter/material.dart';

/// 「鬼になる」を押したときの確認ダイアログ。
///
/// `reportCaught` は取り消せない(逃走者に戻す導線が無い)ため、BLEの
/// 誤検知や誤タップでそのまま鬼になってしまわないよう一度確認を挟む。
/// 「はい」を選んだときだけ true を返す(閉じた・キャンセルは false)。
Future<bool> showBecomeDemonConfirmDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Theme(
      data: ThemeData(useMaterial3: true),
      child: AlertDialog(
        title: const Text('鬼が近くにいます'),
        content: const Text(
          'BLEで鬼が至近距離(3m程度)にいることを検知しました。'
          '鬼になりますか?この操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('鬼になる'),
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}
