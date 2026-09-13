import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/repository/location_smoothing.dart';

void main() {
  group('shouldAcceptLocationUpdate', () {
    test('直前の採用位置が無い(初回)なら、accuracyが良ければ採用する', () {
      final result = shouldAcceptLocationUpdate(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: null,
        previousLongitude: null,
      );
      expect(result, isTrue);
    });

    test('accuracyが閾値を超える(=精度が悪い)測位は初回でも不採用', () {
      final result = shouldAcceptLocationUpdate(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: LocationFilterThresholds.maxAcceptableAccuracyM + 0.1,
        previousLatitude: null,
        previousLongitude: null,
      );
      expect(result, isFalse);
    });

    test('accuracyがちょうど閾値なら採用する(境界値)', () {
      final result = shouldAcceptLocationUpdate(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: LocationFilterThresholds.maxAcceptableAccuracyM,
        previousLatitude: null,
        previousLongitude: null,
      );
      expect(result, isTrue);
    });

    test('accuracyがnull(取得できない)なら、accuracyによる足切りは行わない', () {
      final result = shouldAcceptLocationUpdate(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: null,
        previousLatitude: null,
        previousLongitude: null,
      );
      expect(result, isTrue);
    });

    test('直前の採用位置と全く同じ(移動0m)なら不採用(デッドバンド)', () {
      final result = shouldAcceptLocationUpdate(
        latitude: 35.6812,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
      );
      expect(result, isFalse);
    });

    test('移動距離がデッドバンド未満なら不採用(GPSノイズによる飛び回りを抑える)', () {
      // 緯度方向に約0.00005度(≒5.5m)離れた点。デッドバンド(8m)未満。
      final result = shouldAcceptLocationUpdate(
        latitude: 35.68125,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
      );
      expect(result, isFalse);
    });

    test('移動距離がデッドバンド以上なら採用する(実際に移動したとみなす)', () {
      // 緯度方向に約0.0002度(≒22m)離れた点。デッドバンド(8m)を超える。
      final result = shouldAcceptLocationUpdate(
        latitude: 35.6814,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
      );
      expect(result, isTrue);
    });

    test('accuracyが悪ければ、移動距離が十分でも不採用(足切りが優先)', () {
      final result = shouldAcceptLocationUpdate(
        latitude: 35.6814,
        longitude: 139.7671,
        accuracy: LocationFilterThresholds.maxAcceptableAccuracyM + 10,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
      );
      expect(result, isFalse);
    });

    test('閾値はデフォルト値を上書きできる', () {
      final result = shouldAcceptLocationUpdate(
        latitude: 35.68125,
        longitude: 139.7671,
        accuracy: 5,
        previousLatitude: 35.6812,
        previousLongitude: 139.7671,
        deadbandDistanceM: 1,
      );
      expect(result, isTrue);
    });
  });
}
