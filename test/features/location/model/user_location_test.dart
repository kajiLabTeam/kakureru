import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';

void main() {
  group('UserLocation', () {
    test('fromMap injects uid from the map key and maps lat/lng to latitude/longitude', () {
      final Map<dynamic, dynamic> raw = {
        'lat': 35.6812,
        'lng': 139.7671,
        'altitude': 12.5,
        'updatedAt': 1000,
      };

      final location = UserLocation.fromMap('uid-1', raw);

      expect(location.uid, 'uid-1');
      expect(location.latitude, 35.6812);
      expect(location.longitude, 139.7671);
      expect(location.altitude, 12.5);
      expect(location.pressure, isNull);
    });

    test('toMap writes back to lat/lng and excludes uid', () {
      const location = UserLocation(uid: 'uid-1', latitude: 35.0, longitude: 139.0);

      final map = location.toMap();

      expect(map.containsKey('uid'), isFalse);
      expect(map['lat'], 35.0);
      expect(map['lng'], 139.0);
    });
  });
}
