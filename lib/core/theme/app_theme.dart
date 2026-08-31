import 'package:flutter/material.dart';

/// docs/ui-mockup-2a.html のトーン(白背景・#2b2b2b の太めの黒枠・角丸10〜16・
/// グレーの補助テキスト)をアプリ全体に適用する共通テーマ。
/// 役割ごとの色(鬼=赤/逃走者=緑/自分=青)は各画面・role_theme.dart側で個別に扱う。
const appInk = Color(0xFF2B2B2B);
const appMuted = Color(0xFF888888);
const appFaintBorder = Color(0xFFEEEEEE);

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(seedColor: appInk);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: appInk,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 17, color: appInk),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: appInk,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFDDDDDD),
        disabledForegroundColor: const Color(0xFF999999),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: const TextStyle(fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: appMuted,
        side: const BorderSide(color: Color(0xFFDDDDDD), width: 2),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: const TextStyle(fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: appInk, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: appInk, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: appInk, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5484D), width: 2),
      ),
      labelStyle: const TextStyle(color: appMuted, fontSize: 12),
      contentPadding: const EdgeInsets.all(11),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: appFaintBorder, width: 2),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: appFaintBorder,
      thickness: 2,
      space: 1,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: appInk),
    ),
  );
}
