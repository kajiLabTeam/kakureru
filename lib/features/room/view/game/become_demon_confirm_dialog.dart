import 'package:flutter/material.dart';

/// 捕まった場所。分析用のイベントログ(`catch`の`indoor`)に記録する。
enum CaughtPlace {
  /// 屋内で捕まった。
  indoor,

  /// 屋外で捕まった。
  outdoor,
}

/// 「鬼になる」を押したときの確認ダイアログ。
///
/// `reportCaught` は取り消せない(逃走者に戻す導線が無い)ため、BLEの
/// 誤検知や誤タップでそのまま鬼になってしまわないよう一度確認を挟む。
/// 確定ボタンを「屋内」「屋外」の2つに分け、確認と場所の申告を
/// タップ1回で済ませる。選んだ場所を返し、閉じた・キャンセルは null。
Future<CaughtPlace?> showBecomeDemonConfirmDialog(BuildContext context) {
  return showDialog<CaughtPlace>(
    context: context,
    builder: (dialogContext) => Theme(
      data: ThemeData(useMaterial3: true),
      child: AlertDialog(
        title: const Text('鬼が近くにいます'),
        content: const Text(
          'BLEで鬼が至近距離(3m程度)にいることを検知しました。'
          '鬼になりますか?この操作は取り消せません。\n'
          '捕まった場所を選んでください。',
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(CaughtPlace.indoor),
            child: const Text('屋内で捕まった'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(CaughtPlace.outdoor),
            child: const Text('屋外で捕まった'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    ),
  );
}
