import 'package:flutter/material.dart';

/// ゲーム画面モック(kakureru-ui-mock.html)の配色。
///
/// 役割そのものの色(ピン・ヘッダー帯)は role_theme.dart / game_view_helpers.dart
/// 側にあり、ここには画面の地・文字・枠・中立色だけを置く。
const gameBackground = Color(0xFFF5F3EE);

/// カード・帯の地(白)を区切る枠線。
const gameBorder = Color(0xFFE3E0D9);

/// カード内の小さな区切り(高さパネルの枠など)。
const gameSoftBorder = Color(0xFFEDEAE2);

/// 本文の文字色。
const gameInk = Color(0xFF1B1B19);

/// 補助テキスト。
const gameMuted = Color(0xFF6B6A64);

/// さらに弱い補助テキスト(hPaの行、バーの「上/下」など)。
const gameFaint = Color(0xFF8A8880);

/// 灰色の見出し(「遠いかも」など)や説明文。
const gameInkSoft = Color(0xFF4A483F);

/// メーターの溝・中立のタグ・アイコンの丸。
const gameTrack = Color(0xFFF1EFE9);

/// 選択中のタブ・無効ボタンの地。
const gameSelected = Color(0xFFEAE7DF);

/// 塗られていない「電波の一致」の点・進捗バー。
const gameEmptyDot = Color(0xFFD8D5CC);

/// 注意(放出前バナー・未キャリブレーション)の地・枠・文字。
const gameNoticeBackground = Color(0xFFFFF6E2);

/// 注意の枠。
const gameNoticeBorder = Color(0xFFE8D5A8);

/// 注意の本文。
const gameNoticeInk = Color(0xFF6B5210);

/// 注意の補足文。
const gameNoticeSubInk = Color(0xFF7A6528);

/// 注意のアイコン・強調。
const gameNoticeAccent = Color(0xFF8A6A16);

/// 新着を知らせる点(写真タブ)。鬼の濃い赤と同じ。
const gameNewBadge = Color(0xFFC0343A);

/// 手がかりカード内の案内枠(C3の行動のすすめ・C5の高さ欄)の下地。
const gameHint = Color(0xFFF7F6F2);

/// 手がかりカード内の注意枠(C4のキャリブレーション)の下地。
const gameNoticeSoftBackground = Color(0xFFFFFAEF);
