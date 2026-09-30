import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/sighting.dart';

void main() {
  group('Sighting.fromMap', () {
    test('キーをidにし、uid・takenAtを読む。placeが無ければnull', () {
      final sighting = Sighting.fromMap('p1', <dynamic, dynamic>{
        'uid': 'alice',
        'takenAt': 1000,
      });

      expect(sighting, const Sighting(id: 'p1', uid: 'alice', takenAt: 1000));
      expect(sighting.place, isNull);
    });

    test('placeが書かれていれば読む', () {
      final sighting = Sighting.fromMap('p2', <dynamic, dynamic>{
        'uid': 'bob',
        'takenAt': 2000,
        'place': '1号館の前',
      });

      expect(sighting.place, '1号館の前');
    });

    test('uidが無いものは読めない(一覧側で飛ばす)', () {
      expect(
        () => Sighting.fromMap('p3', <dynamic, dynamic>{'takenAt': 1}),
        throwsA(anything),
      );
    });
  });
}
