import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/mission/effect_rules.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/model/room_effect.dart';
import 'package:kakureru/features/room/model/photo_slot.dart';
import 'package:clock/clock.dart';

RoomEffect _effect({
  String id = 'e1',
  RewardType type = RewardType.blockClues,
  String byUid = 'me',
  int startedAt = 100000,
  int? durationMs,
}) => RoomEffect(
  id: id,
  type: type,
  byUid: byUid,
  startedAt: startedAt,
  durationMs: durationMs ?? type.duration.inMilliseconds,
);

void main() {
  group('効果の残り時間(startedAt + durationMs)', () {
    test('サーバー時刻で数える', () {
      final effect = _effect(startedAt: 100000);
      expect(effectRemainingMillis(effect, serverNowMillis: 100000), 30000);
      expect(effectRemainingMillis(effect, serverNowMillis: 112000), 18000);
      expect(effectRemainingMillis(effect, serverNowMillis: 130000), 0);
      expect(effectRemainingMillis(effect, serverNowMillis: 999999), 0);
    });

    test('端末の時計がずれていても、オフセットで補正すれば同じ残り時間になる', () {
      final effect = _effect(startedAt: 1000000);
      // サーバー時刻 1,012,000 のときの2台。片方は時計が5秒進み、
      // もう片方は3秒遅れている。それぞれのオフセットで補正する。
      final fast = withClock(
        Clock.fixed(DateTime.fromMillisecondsSinceEpoch(1017000)),
        () => serverNowMillis(-5000),
      );
      final slow = withClock(
        Clock.fixed(DateTime.fromMillisecondsSinceEpoch(1009000)),
        () => serverNowMillis(3000),
      );
      expect(effectRemainingMillis(effect, serverNowMillis: fast), 18000);
      expect(effectRemainingMillis(effect, serverNowMillis: slow), 18000);
    });

    test('回数もの(durationMs == 0)は時間で効く効果として扱わない', () {
      final skip = _effect(type: RewardType.skipFootPhoto);
      expect(isEffectActive(skip, serverNowMillis: 100000), isFalse);
      expect(
        activeTimedEffects([skip], serverNowMillis: 100000),
        isEmpty,
      );
    });

    test('同じ効果が重なったら、一番後まで残るものを返す', () {
      final first = _effect(id: 'a', startedAt: 100000);
      final second = _effect(id: 'b', startedAt: 110000);
      expect(
        activeEffectOf(
          [second, first],
          RewardType.blockClues,
          serverNowMillis: 115000,
        )?.id,
        'b',
      );
    });

    test('effectsOfCurrentGameは前のゲームの効果を除く', () {
      final old = _effect(id: 'old', startedAt: 500);
      final now = _effect(id: 'now', startedAt: 5000);
      expect(
        effectsOfCurrentGame([now, old], startedAt: 1000).map((e) => e.id),
        ['now'],
      );
    });
  });

  group('skip_foot_photo は次の1回だけ効く', () {
    const interval = 300; // 5分
    const start = 1000000; // 撮影スケジュールの基準(スロット0の開始)
    int slotStart(int index) => photoSlotStartMillis(
      startedAt: start,
      slotIndex: index,
      intervalSec: interval,
    );

    Set<int> skipped(List<RoomEffect> effects, {int? lastPhotoAt}) =>
        skippedFootPhotoSlots(
          effects: effects,
          myUid: 'me',
          scheduleStartMillis: start,
          intervalSec: interval,
          lastPhotoAt: lastPhotoAt,
        );

    RoomEffect skipAt(int at, {String byUid = 'me', String id = 's'}) =>
        _effect(
          id: id,
          type: RewardType.skipFootPhoto,
          byUid: byUid,
          startedAt: at,
        );

    test('撮影タイムが来ていてまだ撮っていなければ、そのスロットを飛ばす', () {
      expect(
        skipped([skipAt(slotStart(2) + 10000)], lastPhotoAt: slotStart(1)),
        {2},
      );
    });

    test('もう撮った後なら、次のスロットを飛ばす', () {
      expect(
        skipped(
          [skipAt(slotStart(2) + 60000)],
          lastPhotoAt: slotStart(2) + 5000,
        ),
        {3},
      );
    });

    test('撮影が始まる前に引いたら、最初の撮影タイムを飛ばす', () {
      expect(skipped([skipAt(start - 60000)]), {0});
    });

    test('飛ばすのは1回だけ(その次のスロットは飛ばさない)', () {
      final result = skipped(
        [skipAt(slotStart(2) + 10000)],
        lastPhotoAt: slotStart(1),
      );
      expect(result.contains(3), isFalse);
    });

    test('2回引いたら2回ぶん飛ばす', () {
      expect(
        skipped(
          [
            skipAt(slotStart(2) + 10000, id: 'a'),
            skipAt(slotStart(2) + 20000, id: 'b'),
          ],
          lastPhotoAt: slotStart(1),
        ),
        {2, 3},
      );
    });

    test('ほかの人が引いたものは自分には効かない', () {
      expect(skipped([skipAt(slotStart(2), byUid: 'other')]), isEmpty);
    });

    test('撮影スケジュールが決まっていなければ空', () {
      expect(
        skippedFootPhotoSlots(
          effects: [skipAt(slotStart(2))],
          myUid: 'me',
          scheduleStartMillis: null,
          intervalSec: interval,
          lastPhotoAt: null,
        ),
        isEmpty,
      );
    });
  });
}
