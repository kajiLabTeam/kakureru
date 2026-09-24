import 'package:flutter/material.dart';

/// 写真一覧・拡大表示で「誰が撮ったか」を一目で見分けるための、
/// uidから決定的に選ぶ色。
///
/// [role_theme.dart]の色は役割(鬼/逃走者)の2値だが、こちらは個人ごとに
/// 見分けたいための色で、既存の役割別・自分別の色割り当て(`selfColor`/
/// `colorForRole`, game_view_helpers.dart)とは別物。人ごとの色を保存する
/// 仕組みはRTDB側に無いため、uidだけから毎回同じ色を再現できる必要がある
/// (`String.hashCode`はDartの仕様上プラットフォーム間で同一である保証が
/// 無いため使わず、自前の安定したハッシュ関数を使う)。
const _userColorPalette = <Color>[
  Color(0xFFF59E0B), // amber
  Color(0xFF8B5CF6), // violet
  Color(0xFFEC4899), // pink
  Color(0xFF06B6D4), // cyan
  Color(0xFF6366F1), // indigo
  Color(0xFFF97316), // orange
  Color(0xFF14B8A6), // teal
  Color(0xFFD946EF), // fuchsia
];

/// [uid]から[_userColorPalette]の中の1色を決定的に選ぶ。
Color userColorOf(String uid) {
  final index = _stableHash(uid) % _userColorPalette.length;
  return _userColorPalette[index];
}

/// Bob Jenkinsのone-at-a-timeハッシュ。`String.hashCode`と違い実装依存の
/// 揺れが無く、同じ文字列なら常に同じ値を返す。
int _stableHash(String input) {
  var hash = 0;
  for (final codeUnit in input.codeUnits) {
    hash = 0x1fffffff & (hash + codeUnit);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= hash >> 6;
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= hash >> 11;
  hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  return hash;
}
