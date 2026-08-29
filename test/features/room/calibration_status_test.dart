import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/calibration_status.dart';

void main() {
  group('calibrationStatusFor (host)', () {
    test('basePressureが無ければpending', () {
      expect(
        calibrationStatusFor(
          isHost: true,
          sensorAvailable: true,
          basePressure: null,
          pressureOffset: null,
        ),
        CalibrationStatus.pending,
      );
    });

    test('basePressureがあればdone', () {
      expect(
        calibrationStatusFor(
          isHost: true,
          sensorAvailable: true,
          basePressure: 1013,
          pressureOffset: null,
        ),
        CalibrationStatus.done,
      );
    });

    test('センサー非搭載ならunavailable(未完了でも)', () {
      expect(
        calibrationStatusFor(
          isHost: true,
          sensorAvailable: false,
          basePressure: null,
          pressureOffset: null,
        ),
        CalibrationStatus.unavailable,
      );
    });
  });

  group('calibrationStatusFor (participant)', () {
    test('pressureOffsetが無ければpending', () {
      expect(
        calibrationStatusFor(
          isHost: false,
          sensorAvailable: true,
          basePressure: 1013,
          pressureOffset: null,
        ),
        CalibrationStatus.pending,
      );
    });

    test('pressureOffsetがあればdone', () {
      expect(
        calibrationStatusFor(
          isHost: false,
          sensorAvailable: true,
          basePressure: 1013,
          pressureOffset: -0.5,
        ),
        CalibrationStatus.done,
      );
    });

    test('センサー非搭載ならunavailable', () {
      expect(
        calibrationStatusFor(
          isHost: false,
          sensorAvailable: false,
          basePressure: 1013,
          pressureOffset: null,
        ),
        CalibrationStatus.unavailable,
      );
    });

    test('sensorAvailable未確定(null)でも未完了ならpending扱い', () {
      expect(
        calibrationStatusFor(
          isHost: false,
          sensorAvailable: null,
          basePressure: 1013,
          pressureOffset: null,
        ),
        CalibrationStatus.pending,
      );
    });

    test('sensorAvailableがfalseでも既に完了していればdoneを優先する', () {
      expect(
        calibrationStatusFor(
          isHost: false,
          sensorAvailable: false,
          basePressure: 1013,
          pressureOffset: -0.5,
        ),
        CalibrationStatus.done,
      );
    });
  });

  group('isCalibrationComplete', () {
    test('全員done/unavailableなら真', () {
      expect(
        isCalibrationComplete([
          CalibrationStatus.done,
          CalibrationStatus.unavailable,
          CalibrationStatus.done,
        ]),
        isTrue,
      );
    });

    test('1人でもpendingがいれば偽', () {
      expect(
        isCalibrationComplete([
          CalibrationStatus.done,
          CalibrationStatus.pending,
        ]),
        isFalse,
      );
    });

    test('全員センサー非搭載(unavailableのみ)なら真', () {
      expect(
        isCalibrationComplete([
          CalibrationStatus.unavailable,
          CalibrationStatus.unavailable,
        ]),
        isTrue,
      );
    });

    test('空リストなら真(判定対象がいない)', () {
      expect(isCalibrationComplete(const []), isTrue);
    });
  });
}
