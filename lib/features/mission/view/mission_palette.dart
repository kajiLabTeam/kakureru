import 'package:flutter/material.dart';

/// ミッション・ごほうびの配色(kakureru-mission-mock.html)。
///
/// 白文字を載せる面は濃い方([missionDeep])を使う。演出(ガチャ)の暗い地と
/// 金はこのファイルに置かない(ゲーム中の画面には持ち込まないため)。
const missionAccent = Color(0xFFC98A1E);

/// 白文字を載せるミッションの面(見出しのアイコン・「ごほうびガチャを引く」)。
const missionDeep = Color(0xFF8A6A16);

/// ミッションの淡い地(タグ・帯・「まだ誰も取っていない」)。
const missionSoft = Color(0xFFF6ECD6);

/// [missionSoft]の上に載せる文字。
const missionInk = Color(0xFF6B5310);

/// 判定範囲の円の塗り。
const missionRangeFill = Color(0x1FC98A1E);

/// ほかの人に取られた地点の判定範囲の塗り(issue #155。色を落として
/// 「埋まった」ことを示す)。
const missionRangeClaimedFill = Color(0x1F6B6A64);

/// 「鬼をジャマする」のタグの地と文字。
const demonSoft = Color(0xFFFBEBEB);

/// 「鬼をジャマする」の文字・アイコン、注意の赤字。
const demonDeep = Color(0xFFC0343A);

/// 「自分がトクする」のタグの地。
const selfSoft = Color(0xFFE8EEF9);

/// 逃走者の緑の淡い地。
const fugitiveSoft = Color(0xFFE9F0EA);

/// 逃走者の緑(白文字を載せてよい面。ごほうびの画面の「地図に戻る」)。
const fugitiveDeep = Color(0xFF3A7F4A);
