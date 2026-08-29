import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/role_theme.dart';

void main() {
  group('roleThemeOf', () {
    test('鬼は赤系の色と「あなたは 鬼」の文言になる', () {
      final theme = roleThemeOf(UserRole.demon);
      expect(theme.color, const Color(0xFFE5484D));
      expect(theme.label, 'あなたは 鬼');
    });

    test('逃走者は緑系の色と「あなたは 逃走者」の文言になる', () {
      final theme = roleThemeOf(UserRole.fugitive);
      expect(theme.color, const Color(0xFF4A9C5D));
      expect(theme.label, 'あなたは 逃走者');
    });

    test('鬼と逃走者で色・文言・アイコンがすべて異なる(一目で見分けられる)', () {
      final demon = roleThemeOf(UserRole.demon);
      final fugitive = roleThemeOf(UserRole.fugitive);
      expect(demon.color, isNot(fugitive.color));
      expect(demon.label, isNot(fugitive.label));
      expect(demon.icon, isNot(fugitive.icon));
    });
  });
}
