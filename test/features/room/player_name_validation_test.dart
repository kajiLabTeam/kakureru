import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/player_name_validation.dart';

void main() {
  group('normalizePlayerName', () {
    test('前後の空白をトリムする', () {
      expect(normalizePlayerName('  たろう  '), 'たろう');
    });

    test('中間の空白は残す', () {
      expect(normalizePlayerName(' た ろう '), 'た ろう');
    });
  });

  group('validatePlayerName', () {
    test('空文字はempty', () {
      expect(validatePlayerName(''), PlayerNameError.empty);
    });

    test('空白のみはempty', () {
      expect(validatePlayerName('   '), PlayerNameError.empty);
    });

    test('トリム後10文字ちょうどは有効', () {
      expect(validatePlayerName('a' * playerNameMaxLength), isNull);
    });

    test('トリム後11文字はtooLong', () {
      expect(validatePlayerName('a' * (playerNameMaxLength + 1)), PlayerNameError.tooLong);
    });

    test('前後の空白を含めると超過するがトリム後は有効なら有効', () {
      final padded = '  ${'a' * playerNameMaxLength}  ';
      expect(validatePlayerName(padded), isNull);
    });

    test('トリム後も有効な名前はnull', () {
      expect(validatePlayerName('たろう'), isNull);
    });
  });
}
