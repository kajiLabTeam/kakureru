import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/model/sighting.dart';
import 'package:kakureru/features/room/sighting_notifications.dart';
import 'package:kakureru/features/room/sighting_rules.dart';

const _users = [
  RoomUser(id: 'demon', displayName: 'おに', role: UserRole.demon),
  RoomUser(id: 'ayana', displayName: 'あやな'),
  RoomUser(id: 'kouki', displayName: 'こうき'),
];

Sighting _sighting(String id, {String uid = 'ayana', int takenAt = 5000}) =>
    Sighting(id: id, uid: uid, takenAt: takenAt);

void main() {
  group('sightingsToNotify', () {
    test('鬼には、ほかの人が撮った新しい目撃写真を知らせる', () {
      final result = sightingsToNotify(
        previousIds: {'old'},
        sightings: [_sighting('old'), _sighting('new')],
        myUid: 'demon',
        myRole: UserRole.demon,
      );
      expect(result.map((s) => s.id), ['new']);
    });

    test('逃走者には知らせない', () {
      expect(
        sightingsToNotify(
          previousIds: const {},
          sightings: [_sighting('new')],
          myUid: 'kouki',
          myRole: UserRole.fugitive,
        ),
        isEmpty,
      );
    });

    test('自分が撮ったものは知らせない', () {
      expect(
        sightingsToNotify(
          previousIds: const {},
          sightings: [_sighting('mine', uid: 'demon')],
          myUid: 'demon',
          myRole: UserRole.demon,
        ),
        isEmpty,
      );
    });

    test('基準(最初に届いた一覧)ができるまでは知らせない', () {
      expect(
        sightingsToNotify(
          previousIds: null,
          sightings: [_sighting('a')],
          myUid: 'demon',
          myRole: UserRole.demon,
        ),
        isEmpty,
      );
    });

    test('前のゲームの写真は、今のゲームに絞ると知らせない', () {
      final current = sightingsOfCurrentGame([
        _sighting('before', takenAt: 500),
        _sighting('after', takenAt: 5000),
      ], startedAt: 1000);
      expect(
        sightingsToNotify(
          previousIds: const {},
          sightings: current,
          myUid: 'demon',
          myRole: UserRole.demon,
        ).map((s) => s.id),
        ['after'],
      );
    });
  });

  group('sightingTakenMessage', () {
    test('撮った人の名前を出す', () {
      expect(
        sightingTakenMessage([_sighting('a')], _users),
        'あやなさんが鬼の写真を撮りました',
      );
    });

    test('複数人は「、」でつなぎ、同じ人は1回だけ', () {
      expect(
        sightingTakenMessage([
          _sighting('a'),
          _sighting('b', uid: 'kouki'),
          _sighting('c'),
        ], _users),
        'あやなさん、こうきさんが鬼の写真を撮りました',
      );
    });

    test('名前が分からない人は「誰か」', () {
      expect(
        sightingTakenMessage([_sighting('a', uid: 'unknown')], _users),
        '誰かさんが鬼の写真を撮りました',
      );
    });
  });
}
