import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/ble/model/ble_detection.dart';
import 'package:kakureru/features/ble/repository/ble_proximity_calculator.dart';
import 'package:kakureru/features/room/catch_rules.dart';
import 'package:kakureru/features/room/model/catch_photo.dart';
import 'package:kakureru/features/room/model/room_catch.dart';
import 'package:kakureru/features/room/model/room_user.dart';

const _now = 1000000;

/// 基準RSSI(-59dBm)は1m、-80dBmは約5m(3mの外)になる。
BleDetection _detection(String uid, int rssi, {int at = _now}) => BleDetection(
  shortUid: shortenUid(uid),
  rssiDbm: rssi,
  detectedAtMillis: at,
);

RoomCatch _catch(String id, int caughtAt, {String fugitive = 'f1'}) =>
    RoomCatch(
      id: id,
      demonUserId: 'demon',
      fugitiveUserId: fugitive,
      caughtAt: caughtAt,
    );

void main() {
  group('fugitivesWithinCatchRange', () {
    const users = [
      RoomUser(id: 'me', role: UserRole.demon),
      RoomUser(id: 'near'),
      RoomUser(id: 'nearer'),
      RoomUser(id: 'far'),
      RoomUser(id: 'otherDemon', role: UserRole.demon),
    ];

    test('3m以内の逃走者だけを近い順に返し、鬼は除く', () {
      final result = fugitivesWithinCatchRange(
        detections: {
          for (final d in [
            _detection('near', -65),
            _detection('nearer', -59),
            _detection('far', -80),
            _detection('otherDemon', -50),
          ])
            d.shortUid: d,
        },
        users: users,
        myUid: 'me',
        nowMillis: _now,
      );
      expect(result, ['nearer', 'near']);
    });

    test('古い検知は数えない', () {
      final stale = _detection(
        'near',
        -59,
        at: _now - BleProximityThresholds.staleAfterMillis - 1,
      );
      expect(
        fugitivesWithinCatchRange(
          detections: {stale.shortUid: stale},
          users: users,
          myUid: 'me',
          nowMillis: _now,
        ),
        isEmpty,
      );
    });

    test('誰も検知していなければ空(ボタンは押せない)', () {
      expect(
        fugitivesWithinCatchRange(
          detections: const {},
          users: users,
          myUid: 'me',
          nowMillis: _now,
        ),
        isEmpty,
      );
    });
  });

  group('preselectedCatchTarget', () {
    test('候補が1人ならその人を選んでおく', () {
      expect(preselectedCatchTarget(['a']), 'a');
    });
    test('0人・2人以上なら選ばない', () {
      expect(preselectedCatchTarget([]), isNull);
      expect(preselectedCatchTarget(['a', 'b']), isNull);
    });
  });

  group('取り消しの期限(10秒)', () {
    test('期限は10秒', () {
      expect(catchUndoWindow, const Duration(seconds: 10));
    });

    test('10秒未満なら取り消せ、10秒ちょうど以降は取り消せない', () {
      expect(isCatchUndoable(caughtAt: 0, nowMillis: 9999), isTrue);
      expect(isCatchUndoable(caughtAt: 0, nowMillis: 10000), isFalse);
      expect(isCatchUndoable(caughtAt: 0, nowMillis: 60000), isFalse);
    });

    test('残り秒数は切り上げ、期限後は0', () {
      expect(catchUndoRemainingSeconds(caughtAt: 0, nowMillis: 0), 10);
      expect(catchUndoRemainingSeconds(caughtAt: 0, nowMillis: 9001), 1);
      expect(catchUndoRemainingSeconds(caughtAt: 0, nowMillis: 10000), 0);
    });
  });

  group('catchesToAnnounce', () {
    test('期限内の捕獲は知らせず、期限を過ぎたものだけ知らせる', () {
      final catches = [_catch('old', _now - 10000), _catch('new', _now - 9999)];
      expect(
        catchesToAnnounce(
          announcedIds: const {},
          catches: catches,
          nowMillis: _now,
        ).map((c) => c.id),
        ['old'],
      );
    });

    test('知らせ済みの捕獲は二度知らせない', () {
      expect(
        catchesToAnnounce(
          announcedIds: const {'old'},
          catches: [_catch('old', 0)],
          nowMillis: _now,
        ),
        isEmpty,
      );
    });
  });

  group('catchesOfCurrentGame / catchToAcceptAsCaught', () {
    test('前のゲーム(startedAtより前)の捕獲は除く', () {
      final result = catchesOfCurrentGame(
        [_catch('prev', 100), _catch('cur', 300)],
        startedAt: 200,
      );
      expect(result.map((c) => c.id), ['cur']);
    });

    test('逃走者の自分宛ての捕獲を受け入れ対象にする', () {
      final c = _catch('c', 300, fugitive: 'me');
      expect(
        catchToAcceptAsCaught(
          catches: [c],
          myUid: 'me',
          myRole: UserRole.fugitive,
          startedAt: 200,
        ),
        c,
      );
    });

    test('既に鬼なら受け入れ済みとみなす', () {
      expect(
        catchToAcceptAsCaught(
          catches: [_catch('c', 300, fugitive: 'me')],
          myUid: 'me',
          myRole: UserRole.demon,
          startedAt: 200,
        ),
        isNull,
      );
    });
  });

  group('undoneCatchesOf', () {
    test('自分が報告した捕獲が消えたら取り消しとみなす', () {
      final mine = _catch('a', 0);
      const others = RoomCatch(
        id: 'b',
        demonUserId: 'someone',
        fugitiveUserId: 'x',
        caughtAt: 0,
      );
      expect(
        undoneCatchesOf(
          previous: [mine, others],
          current: const [],
          myUid: 'demon',
        ),
        [mine],
      );
    });
  });

  group('catchPhotosForGallery', () {
    CatchPhoto photo(String id, String catchId, int takenAt) => CatchPhoto(
      id: id,
      catchId: catchId,
      demonUid: 'demon',
      fugitiveUid: 'f1',
      takenAt: takenAt,
    );

    test('確定した捕獲の写真を新しい順に返す(見る人が撮ったかどうかは関係ない)', () {
      final result = catchPhotosForGallery(
        catchPhotos: [photo('p1', 'c1', 100), photo('p2', 'c2', 200)],
        catches: [_catch('c1', 100), _catch('c2', 200)],
        startedAt: 0,
        nowMillis: _now,
      );
      expect(result.map((p) => p.id), ['p2', 'p1']);
    });

    test('期限内・取り消し済み・前のゲームの捕獲の写真は出さない', () {
      final result = catchPhotosForGallery(
        catchPhotos: [
          photo('pending', 'c1', _now),
          photo('undone', 'gone', 100),
          photo('prev', 'c0', 50),
        ],
        catches: [_catch('c1', _now - 1000), _catch('c0', 50)],
        startedAt: 60,
        nowMillis: _now,
      );
      expect(result, isEmpty);
    });
  });

  test('remainingFugitiveCount は逃走者の人数', () {
    expect(
      remainingFugitiveCount(const [
        RoomUser(id: 'a'),
        RoomUser(id: 'b', role: UserRole.demon),
      ]),
      1,
    );
  });
}
