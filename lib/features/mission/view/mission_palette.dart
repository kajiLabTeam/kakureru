import 'package:flutter/material.dart';

/// ミッション・特典の配色(kakureru-mission-mock.html)。
///
/// 白文字を載せる面は濃い方([missionDeep])を使う。演出(ガチャ)の暗い地と
/// 金はこのファイルに置かない(ゲーム中の画面には持ち込まないため)。
const missionAccent = Color(0xFFC98A1E);

/// 白文字を載せるミッションの面(見出しのアイコン・「特典を引く」)。
const missionDeep = Color(0xFF8A6A16);

/// ミッションの淡い地(タグ・帯・「まだ誰も取っていない」)。
const missionSoft = Color(0xFFF6ECD6);

/// [missionSoft]の上に載せる文字。
const missionInk = Color(0xFF6B5310);

/// 判定範囲の円の塗り。
const missionRangeFill = Color(0x1FC98A1E);

/// 「鬼に効く」のタグの地と文字。
const demonSoft = Color(0xFFFBEBEB);

/// 「鬼に効く」の文字・アイコン、注意の赤字。
const demonDeep = Color(0xFFC0343A);

/// 「自分に効く」のタグの地。
const selfSoft = Color(0xFFE8EEF9);

/// 「全員が挑める」のタグの地。
const fugitiveSoft = Color(0xFFE9F0EA);

/// 「全員が挑める」のタグの文字。
const fugitiveDeep = Color(0xFF3A7F4A);
