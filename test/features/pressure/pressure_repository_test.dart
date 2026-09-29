import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/pressure/repository/pressure_repository.dart';

import '../../helpers/fake_rtdb.dart';

void main() {
  group('PressureRepository.reportSensorAvailability', () {
    test('users/{uid}の他のフィールドを消さずに書き込む', () async {
      final db = FakeRtdb({
        'rooms': <String, Object?>{
          'room-1': <String, Object?>{
            'users': <String, Object?>{
              'me': <String, Object?>{
                'displayName': 'たろう',
                'role': 'FUGITIVE',
                'joinedAt': 1,
              },
            },
          },
        },
      });
      final repo = PressureRepository(db: db, auth: FakeAuth());

      await repo.reportSensorAvailability('room-1', available: true);

      expect(db.read('rooms/room-1/users/me'), {
        'displayName': 'たろう',
        'role': 'FUGITIVE',
        'joinedAt': 1,
        'pressureSensorAvailable': true,
      });
    });
  });
}
