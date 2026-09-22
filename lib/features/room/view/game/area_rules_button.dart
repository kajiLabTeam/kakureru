import 'package:flutter/material.dart';
import 'package:kakureru/features/room/view/game/area_rules_dialog.dart';

/// 使ってよい場所・ダメな場所の一覧を開くボタン(issue #108)。
///
/// 待機画面とゲーム画面のAppBarの`actions`に、デバッグ用の偽プレイヤー
/// トグル(`DebugMockPlayersToggle`)の**右隣**に置く。
///
/// あちらと違い、これは**リリースビルドでも常に出る**(プレー中に「ここ
/// 入っていいんだっけ?」を確かめるためのものなので、`kDebugMode`で隠さない)。
class AreaRulesButton extends StatelessWidget {
  /// AppBarの`actions`に置く。
  const AreaRulesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      // 隣のデバッグ用トグルと大きさを揃える。
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      tooltip: '使用していい範囲',
      // 地図アイコンではなく「?」。「ここ入っていいんだっけ?」と迷った
      // ときに押すものなので、ヘルプの見た目のほうが押す気になる。
      icon: const Icon(Icons.help_outline),
      onPressed: () => showAreaRulesDialog(context),
    );
  }
}
