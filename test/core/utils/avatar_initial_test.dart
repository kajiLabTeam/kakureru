import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/core/utils/avatar_initial.dart';

void main() {
  group('avatarInitial', () {
    test('空文字なら「?」を返す', () {
      expect(avatarInitial(''), '?');
    });

    test('通常の文字列なら先頭1文字を返す', () {
      expect(avatarInitial('りんや'), 'り');
    });

    test('ASCII文字列なら先頭1文字を返す', () {
      expect(avatarInitial('Alice'), 'A');
    });

    test('サロゲートペアの絵文字が先頭でも1コードポイントを正しく切り出す', () {
      // 😀(U+1F600)はUTF-16ではサロゲートペア(2コードユニット)になるため、
      // String.substring(0, 1)だと不正な文字(前半のみ)になってしまう対象。
      const emojiName = '😀たろう';
      expect(avatarInitial(emojiName), '😀');
    });
  });
}
