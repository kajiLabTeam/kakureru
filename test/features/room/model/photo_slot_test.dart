import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/photo_slot.dart';

void main() {
  const startedAt = 1000000;
  const intervalSec = 300;
  const intervalMillis = intervalSec * 1000;

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
      final now = startedAt + intervalMillis * 2 + 50;
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
}
