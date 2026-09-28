import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/photo_slot.dart';

void main() {
  const startedAt = 1000000;
  const intervalSec = 300;
  const intervalMillis = intervalSec * 1000;

  group('photoScheduleStartMillis', () {
    test('1回目は鬼の放出から1間隔たった時点', () {
      expect(
        photoScheduleStartMillis(releasedAt: 1000000, intervalSec: 300),
        1300000,
      );
    });

    test('放出時刻が未確定ならnull', () {
      expect(
        photoScheduleStartMillis(releasedAt: null, intervalSec: 300),
        isNull,
      );
    });

    test('放出待ち・放出後1間隔の間は撮影を促さず、ちょうど1間隔で促す', () {
      const releasedAt = 1000000;
      final start = photoScheduleStartMillis(
        releasedAt: releasedAt,
        intervalSec: 300,
      )!;
      for (final now in [releasedAt - 60000, releasedAt, start - 1]) {
        expect(
          isPhotoCaptureDue(
            startedAt: start,
            lastPhotoAt: null,
            nowMillis: now,
            intervalSec: 300,
          ),
          isFalse,
          reason: 'now=$now',
        );
      }
      expect(
        isPhotoCaptureDue(
          startedAt: start,
          lastPhotoAt: null,
          nowMillis: start,
          intervalSec: 300,
        ),
        isTrue,
      );
    });
  });

  group('photoSlotIndexOf', () {
    test('startedAtちょうどはスロット0', () {
      expect(
        photoSlotIndexOf(
          takenAt: startedAt,
          startedAt: startedAt,
          intervalSec: intervalSec,
        ),
        0,
      );
    });

    test('スロット0の終わりの直前はスロット0のまま', () {
      expect(
        photoSlotIndexOf(
          takenAt: startedAt + intervalMillis - 1,
          startedAt: startedAt,
          intervalSec: intervalSec,
        ),
        0,
      );
    });

    test('スロット0の終わり(=スロット1の始まり)はスロット1', () {
      expect(
        photoSlotIndexOf(
          takenAt: startedAt + intervalMillis,
          startedAt: startedAt,
          intervalSec: intervalSec,
        ),
        1,
      );
    });

    test('複数スロット先も割り算で求まる', () {
      expect(
        photoSlotIndexOf(
          takenAt: startedAt + intervalMillis * 5 + 100,
          startedAt: startedAt,
          intervalSec: intervalSec,
        ),
        5,
      );
    });
  });

  group('photoSlotStartMillis / photoSlotEndMillis', () {
    test('スロット0の開始はstartedAtそのもの', () {
      expect(
        photoSlotStartMillis(
          startedAt: startedAt,
          slotIndex: 0,
          intervalSec: intervalSec,
        ),
        startedAt,
      );
    });

    test('スロットNの開始はstartedAt + N*interval', () {
      expect(
        photoSlotStartMillis(
          startedAt: startedAt,
          slotIndex: 3,
          intervalSec: intervalSec,
        ),
        startedAt + intervalMillis * 3,
      );
    });

    test('スロットの終わりは次のスロットの開始と一致する', () {
      final end = photoSlotEndMillis(
        startedAt: startedAt,
        slotIndex: 2,
        intervalSec: intervalSec,
      );
      final nextStart = photoSlotStartMillis(
        startedAt: startedAt,
        slotIndex: 3,
        intervalSec: intervalSec,
      );
      expect(end, nextStart);
    });
  });

  group('currentPhotoSlotIndex', () {
    test('photoSlotIndexOfにnowMillisを渡した場合と同じ結果になる', () {
      const now = startedAt + intervalMillis * 2 + 50;
      expect(
        currentPhotoSlotIndex(
          startedAt: startedAt,
          nowMillis: now,
          intervalSec: intervalSec,
        ),
        photoSlotIndexOf(
          takenAt: now,
          startedAt: startedAt,
          intervalSec: intervalSec,
        ),
      );
    });
  });

  group('isPhotoCaptureDue', () {
    bool due({required int nowMillis, int? lastPhotoAt}) => isPhotoCaptureDue(
      startedAt: startedAt,
      lastPhotoAt: lastPhotoAt,
      nowMillis: nowMillis,
      intervalSec: intervalSec,
    );

    test('ゲーム開始前は促さない', () {
      expect(due(nowMillis: startedAt - 1), isFalse);
    });

    // 以前は画面を開いてから間隔ぶん待ってから通知しており、最初のスロットの
    // 通知がスロット終了時にしか来なかった(実データで0:00〜5:00に1枚も
    // 撮られていなかった)。
    test('未撮影なら最初のスロットの開始直後から促す', () {
      expect(due(nowMillis: startedAt), isTrue);
    });

    test('今のスロットで撮影済みなら促さない', () {
      expect(
        due(nowMillis: startedAt + 100, lastPhotoAt: startedAt + 50),
        isFalse,
      );
    });

    test('スロットの終わり際に撮っても、次のスロットに入ったら促す', () {
      const lastPhotoAt = startedAt + intervalMillis - 10;
      expect(
        due(
          nowMillis: startedAt + intervalMillis - 1,
          lastPhotoAt: lastPhotoAt,
        ),
        isFalse,
      );
      expect(
        due(nowMillis: startedAt + intervalMillis, lastPhotoAt: lastPhotoAt),
        isTrue,
      );
    });

    test('前のスロットの写真しか無ければ促す', () {
      expect(
        due(
          nowMillis: startedAt + intervalMillis * 3 + 5,
          lastPhotoAt: startedAt + intervalMillis + 5,
        ),
        isTrue,
      );
    });
  });

  group('nextPhotoSlotBoundaryMillis', () {
    int next(int nowMillis) => nextPhotoSlotBoundaryMillis(
      startedAt: startedAt,
      nowMillis: nowMillis,
      intervalSec: intervalSec,
    );

    test('ゲーム開始前なら開始時刻', () {
      expect(next(startedAt - 1000), startedAt);
    });

    test('スロットの途中なら次のスロットの開始時刻', () {
      expect(
        next(startedAt + intervalMillis + 5),
        startedAt + intervalMillis * 2,
      );
    });

    test('ちょうど区切りの時刻なら、その次の区切り', () {
      expect(next(startedAt + intervalMillis), startedAt + intervalMillis * 2);
    });
  });
}
