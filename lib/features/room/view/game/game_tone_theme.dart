import 'package:flutter/material.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';

/// ゲーム画面の外(ホーム・ルーム設定・待機・結果)をゲーム画面と同じトーンに揃えるテーマ。
///
/// 生成りの地・白いカード・細い枠・太字の濃いインク・丸いボタン、という
/// ゲーム画面(kakureru-ui-mock.html)の見た目を、[base]に上書きして返す。
/// アプリ全体のテーマ(app_theme.dart)は変えずに、ホーム・設定・待機・
/// 結果の各画面を`Theme`で包んで使う。
ThemeData buildGameToneTheme(ThemeData base) {
  const buttonShape = StadiumBorder();
  const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
  const buttonSize = Size.fromHeight(48);

  OutlineInputBorder inputBorder(Color color, {double width = 1.5}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    scaffoldBackgroundColor: gameBackground,
    colorScheme: base.colorScheme.copyWith(
      primary: gameInk,
      onPrimary: Colors.white,
      error: gameNewBadge,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: gameInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: gameBorder)),
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: gameInk,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: gameInk,
        foregroundColor: Colors.white,
        // ゲーム画面の「無効ボタンの地」と同じ。
        disabledBackgroundColor: gameSelected,
        disabledForegroundColor: gameFaint,
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: gameInk,
        disabledForegroundColor: gameFaint,
        side: const BorderSide(color: gameBorder, width: 1.5),
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: gameInk,
        disabledForegroundColor: gameEmptyDot,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: inputBorder(gameBorder),
      enabledBorder: inputBorder(gameBorder),
      focusedBorder: inputBorder(gameInk, width: 2),
      errorBorder: inputBorder(gameNewBadge),
      focusedErrorBorder: inputBorder(gameNewBadge, width: 2),
      labelStyle: const TextStyle(color: gameMuted, fontSize: 13),
      floatingLabelStyle: const TextStyle(
        color: gameInk,
        fontWeight: FontWeight.w700,
      ),
      counterStyle: const TextStyle(color: gameFaint, fontSize: 11),
      errorStyle: const TextStyle(color: gameNewBadge),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    // 「使用していい範囲」などのダイアログ。ゲーム画面のカードと同じ白地+細枠。
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
        side: BorderSide(color: gameBorder),
      ),
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: gameInk,
      ),
      contentTextStyle: TextStyle(fontSize: 14, color: gameInk),
    ),
    // 待機画面の「鬼にする」「取り消す」。白地に細枠の丸いチップ。
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      side: const BorderSide(color: gameBorder, width: 1.5),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        color: gameInk,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: gameInk),
    dividerTheme: const DividerThemeData(
      color: gameBorder,
      thickness: 1,
      space: 1,
    ),
    textTheme: base.textTheme.apply(bodyColor: gameInk, displayColor: gameInk),
  );
}

/// ゲーム画面の白いカード(HiddenOpponentCard等)と同じ見た目の枠。
class GameToneCard extends StatelessWidget {
  /// 見出し[title]があれば、カードの上に小さな太字で添える。
  const GameToneCard({
    required this.child,
    super.key,
    this.title,
    this.padding = const EdgeInsets.all(16),
  });

  /// カード左上の小さな見出し。
  final String? title;

  /// カードの内側の余白。
  final EdgeInsetsGeometry padding;

  /// カードの中身。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: gameBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: gameMuted,
              ),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}
