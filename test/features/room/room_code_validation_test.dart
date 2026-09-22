import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/room_code_validation.dart';

void main() {
  group('normalizeRoomCode', () {
    test('前後の空白を取り除く', () {
      expect(normalizeRoomCode(' 1234 '), '1234');
    });
  });

  group('validateRoomCode', () {
    test('4桁の数字はエラーにならない', () {
      expect(validateRoomCode('1234'), isNull);
      expect(validateRoomCode('0000'), isNull);
      expect(validateRoomCode(' 1234 '), isNull);
    });

    test('未入力・空白のみはempty', () {
      expect(validateRoomCode(''), RoomCodeError.empty);
      expect(validateRoomCode('   '), RoomCodeError.empty);
    });

    test('桁数が足りない/多いとinvalidFormat', () {
      expect(validateRoomCode('123'), RoomCodeError.invalidFormat);
      expect(validateRoomCode('12345'), RoomCodeError.invalidFormat);
    });

    test('数字以外を含むとinvalidFormat', () {
      // inputFormattersをすり抜けた場合(貼り付け等)の保険。
      expect(validateRoomCode('12a4'), RoomCodeError.invalidFormat);
      expect(validateRoomCode('１２３４'), RoomCodeError.invalidFormat);
      expect(validateRoomCode('12 4'), RoomCodeError.invalidFormat);
    });
  });
}
