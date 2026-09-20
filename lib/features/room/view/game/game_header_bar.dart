import 'package:flutter/material.dart';
import 'package:kakureru/core/utils/duration_format.dart';
import 'package:kakureru/features/room/role_theme.dart';

/// 役割ラベルの文字サイズ。
///
/// モック2a-03は280px幅の枠で13px。実機幅(393dp)へ同じ比率でスケールすると
/// 18px相当になるが、以前はモックの数値をそのまま15pxで実装していたため、
/// 実機では小さすぎた(issue #76)。
const double gameHeaderLabelFontSize = 17;

/// 残り時間の文字サイズ。同じくモックの17px(280px枠)を実機幅へスケールした値。
const double gameHeaderTimerFontSize = 22;

/// ゲーム画面のヘッダー(役割ラベル + 残り時間)。
///
/// UI改修モック(2a-03/2a-04)はヘッダーの帯1本に役割文言とタイマーを左右に
/// 並べて同居させている。以前はAppBarのtitleに役割文言だけを出し、タイマーは
/// 本文側の別行に分けていたが、本文側は毎秒rebuildされるため、そのつど
/// AppBarのtitleだけ文言色が上書きされない不具合が起きていた経緯もあり、
/// 1つのRowにまとめて明示的に色を指定している。
///
/// GamePageから切り出しているのは、**この部分だけをwidgetテストで確かめ
/// られるようにするため**。GamePage全体はFirebase・センサー系のproviderを
/// 丸ごと差し替えないと立ち上がらない(`outside_area_alert.dart` /
/// `become_demon_button.dart` と同じ考え方)。
class GameHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  /// [roleTheme]がnullなのは、まだ自分の役割が分からないとき。
  /// そのときは既定色のヘッダーに「ゲーム中」とだけ出し、残り時間は出さない
  /// (役割が決まる前は残り時間の意味が変わるため)。
  const GameHeaderBar({
    super.key,
    required this.roleTheme,
    required this.countdownSec,
    this.actions = const [],
  });

  /// 自分の役割に応じた配色と文言。役割が未確定ならnull。
  final RoleTheme? roleTheme;

  /// 残り秒数。計算できていなければnull(`--:--`と出す)。
  final int? countdownSec;

  /// ヘッダー右端に足すウィジェット。GamePageはデバッグビルド限定の
  /// 偽プレイヤートグルを渡す。
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = roleTheme;
    final sec = countdownSec;
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: theme?.color,
      foregroundColor: theme != null ? Colors.white : null,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              theme?.label ?? 'ゲーム中',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // 役割が決まっているときだけ白を指定する。
                //
                // 役割色(赤/緑)の帯の上に載るので白が要るが、**nullのときは
                // 背景がAppBarThemeの白になる**ため、同じ白を指定すると
                // 「ゲーム中」が白地に白で消える。かといって色指定を無条件に
                // 外すと、AppBarThemeのtitleTextStyleが非nullなので
                // foregroundColorは効かず、役割色の帯の上でもappInkのまま
                // になる(Flutter側の仕様: titleTextStyleがあると
                // foregroundColorを混ぜない)。
                color: theme != null ? Colors.white : null,
                fontSize: gameHeaderLabelFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (theme != null)
            Text(
              sec == null ? '--:--' : formatCountdown(sec),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                fontSize: gameHeaderTimerFontSize,
              ),
            ),
        ],
      ),
      actions: actions,
    );
  }
}
