import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/features/room/model/room_user.dart';

part 'role_theme.freezed.dart';

/// 役割(鬼/逃走者)を一目で見分けるための表示情報(ヘッダー背景色・文言・アイコン)。
///
/// 「画面を見ただけでは自分が鬼か逃走者か分かりにくい」という課題(issue #12)に
/// 対応するためのもの。docs/ui-mockup-2a.html の画面03(鬼)・画面04(逃走者)の
/// 配色(鬼=赤 #E5484D、逃走者=緑 #4A9C5D)と「あなたは 鬼/逃走者」の文言に合わせている。
///
/// [color]はピン・点など小さな面の色。白文字を載せる面(ヘッダー帯など)には
/// 濃い方の[surfaceColor]を使う。#4A9C5Dの上の白文字はコントラストが3.4:1しか
/// なく読みにくいため(ゲーム画面モック kakureru-ui-mock.html の01の注記)。
@freezed
abstract class RoleTheme with _$RoleTheme {
  const factory RoleTheme({
    required Color color,
    required Color surfaceColor,
    required String label,
    required IconData icon,
  }) = _RoleTheme;
}

const _demonColor = Color(0xFFE5484D);
const _fugitiveColor = Color(0xFF4A9C5D);
const _demonSurfaceColor = Color(0xFFC0343A);
const _fugitiveSurfaceColor = Color(0xFF3A7F4A);

/// 役割に応じたヘッダー表示情報を返す。
RoleTheme roleThemeOf(UserRole role) {
  switch (role) {
    case UserRole.demon:
      return const RoleTheme(
        color: _demonColor,
        surfaceColor: _demonSurfaceColor,
        label: 'あなたは 鬼',
        icon: Icons.local_fire_department,
      );
    case UserRole.fugitive:
      return const RoleTheme(
        color: _fugitiveColor,
        surfaceColor: _fugitiveSurfaceColor,
        label: 'あなたは 逃走者',
        icon: Icons.directions_run,
      );
  }
}
