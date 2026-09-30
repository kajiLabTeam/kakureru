import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/clock_time_format.dart';
import 'package:kakureru/features/room/model/sighting.dart';
import 'package:kakureru/features/room/sighting_rules.dart';

Sighting _s(String id, int takenAt, {String uid = 'other'}) =>
    Sighting(id: id, uid: uid, takenAt: takenAt);

void main() {
  group('sightingsOfCurrentGame', () {
    test('撮った時刻の古い順に並べる', () {
      final result = sightingsOfCurrentGame([
        _s('c', 300),
        _s('a', 100),
        _s('b', 200),
      ], startedAt: 0);

      expect(result.map((s) => s.id), ['a', 'b', 'c']);
    });

    test('同じ時刻ならIDの順にする', () {
      final result = sightingsOfCurrentGame([
        _s('y', 100),
        _s('x', 100),
      ], startedAt: 0);

      expect(result.map((s) => s.id), ['x', 'y']);
    });

    test('meta/startedAtより前(前のゲーム)のものは除く', () {
      final result = sightingsOfCurrentGame([
        _s('old', 999),
        _s('edge', 1000),
        _s('new', 1500),
      ], startedAt: 1000);

      expect(result.map((s) => s.id), ['edge', 'new']);
    });

    test('startedAtが分からなければ空', () {
      expect(sightingsOfCurrentGame([_s('a', 1)], startedAt: null), isEmpty);
    });
  });

  group('unreadSightingCount', () {
    final sightings = [
      _s('a', 100),
      _s('b', 200, uid: 'me'),
      _s('c', 300),
      _s('d', 400),
    ];

    test('見た数より後に増えた分を数える', () {
      expect(
        unreadSightingCount(sightings: sightings, seenCount: 2, myUid: 'x'),
        2,
      );
    });

    test('増えた分のうち自分が撮ったものは数えない', () {
      expect(
        unreadSightingCount(sightings: sightings, seenCount: 1, myUid: 'me'),
        2,
      );
    });

    test('全部見ていれば0', () {
      expect(
        unreadSightingCount(sightings: sightings, seenCount: 4, myUid: 'me'),
        0,
      );
    });

    test('まだ数え始めていない(null)なら0', () {
      expect(
        unreadSightingCount(sightings: sightings, seenCount: null, myUid: 'me'),
        0,
      );
    });

    test('見た数が今の枚数より多くても負にならない', () {
      expect(
        unreadSightingCount(sightings: sightings, seenCount: 10, myUid: 'me'),
        0,
      );
    });
  });

  group('sightingCaption', () {
    const takenAt = 1700000000000;
    final time = formatClockTime(takenAt);

    test('名前・時刻・場所を「 ・ 」でつなぐ', () {
      expect(
        sightingCaption(
          authorName: 'こうき',
          isMine: false,
          takenAt: takenAt,
          place: '1号館の前',
        ),
        'こうき ・ $time ・ 1号館の前',
      );
    });

    test('場所が無い・空白だけなら省く', () {
      expect(
        sightingCaption(authorName: 'こうき', isMine: false, takenAt: takenAt),
        'こうき ・ $time',
      );
      expect(
        sightingCaption(
          authorName: 'こうき',
          isMine: false,
          takenAt: takenAt,
          place: '  ',
        ),
        'こうき ・ $time',
      );
    });

    test('自分の写真は「自分」と出す', () {
      expect(
        sightingCaption(authorName: 'わたし', isMine: true, takenAt: takenAt),
        '自分 ・ $time',
      );
    });
  });
}
