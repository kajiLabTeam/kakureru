import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/user_color.dart';

void main() {
  test('同じuidなら常に同じ色になる', () {
    final first = userColorOf('user-1');
    final second = userColorOf('user-1');
    expect(first, second);
  });

  test('違うuidなら基本的に違う色になる', () {
    expect(userColorOf('user-1'), isNot(userColorOf('user-2')));
  });

  test('空文字のuidでも例外にならない', () {
    expect(() => userColorOf(''), returnsNormally);
  });
}
