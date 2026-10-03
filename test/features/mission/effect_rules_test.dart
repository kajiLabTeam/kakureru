import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/mission/effect_rules.dart';
import 'package:kakureru/features/mission/model/mission.dart';
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
      final effect = _effect(startedAt: 100000, durationMs: 30000);
      expect(effectRemainingMillis(effect, serverNowMillis: 100000), 30000);
      expect(effectRemainingMillis(effect, serverNowMillis: 112000), 18000);
      expect(effectRemainingMillis(effect, serverNowMillis: 130000), 0);
      expect(effectRemainingMillis(effect, serverNowMillis: 999999), 0);
    });

    test('端末の時計がずれていても、オフセットで補正すれば同じ残り時間になる', () {
      final effect = _effect(startedAt: 1000000, durationMs: 30000);
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

    test('activeTimedEffectsはenlarge_self_icon(本人にだけ出す帯)を含めない', () {
      final enlarge = _effect(
        id: 'e',
        type: RewardType.enlargeSelfIcon,
      );
      expect(
        activeTimedEffects([enlarge], serverNowMillis: 100000),
        isEmpty,
      );
    });
  });

  group('enlarge_self_icon(自分のアイコンを大きくする)', () {
    test('activeEnlargeSelfIconEffectForは自分が引いた分だけ返す', () {
      final mine = _effect(
        id: 'mine',
        type: RewardType.enlargeSelfIcon,
      );
      final other = _effect(
        id: 'other',
        type: RewardType.enlargeSelfIcon,
        byUid: 'other',
      );
      expect(
        activeEnlargeSelfIconEffectFor(
          [mine, other],
          uid: 'me',
          serverNowMillis: 110000,
        )?.id,
        'mine',
      );
    });

    test('activeEnlargeSelfIconEffectForはuidが無ければnull', () {
      final mine = _effect(type: RewardType.enlargeSelfIcon);
      expect(
        activeEnlargeSelfIconEffectFor(
          [mine],
          uid: null,
          serverNowMillis: 100000,
        ),
        isNull,
      );
    });

    test('activeEnlargeSelfIconUidsは効いている全員のuidを返す(全員の地図用)', () {
      final a = _effect(
        id: 'a',
        type: RewardType.enlargeSelfIcon,
        byUid: 'alice',
      );
      final b = _effect(
        id: 'b',
        type: RewardType.enlargeSelfIcon,
        byUid: 'bob',
      );
      final expired = _effect(
        id: 'c',
        type: RewardType.enlargeSelfIcon,
        byUid: 'carol',
        startedAt: 0,
        durationMs: 30000,
      );
      expect(
        activeEnlargeSelfIconUids(
          [a, b, expired],
          serverNowMillis: 110000,
        ),
        {'alice', 'bob'},
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

    int? slotToSkip(int now, {required bool isDue}) => footPhotoSlotToSkip(
      scheduleStartMillis: start,
      intervalSec: interval,
      nowMillis: now,
      isDue: isDue,
    );

    test('引いた瞬間に撮影タイムが来ていてまだ撮っていなければ、そのスロット', () {
      expect(slotToSkip(slotStart(2) + 10000, isDue: true), 2);
    });

    test('撮影タイムが来ていない・もう撮った後なら、次のスロット', () {
      expect(slotToSkip(slotStart(2) + 60000, isDue: false), 3);
    });

    test('撮影が始まる前に引いたら、最初の撮影タイム', () {
      expect(slotToSkip(start - 60000, isDue: false), 0);
    });

    test('撮影スケジュールが決まっていなければnull', () {
      expect(
        footPhotoSlotToSkip(
          scheduleStartMillis: null,
          intervalSec: interval,
          nowMillis: 0,
          isDue: false,
        ),
        isNull,
      );
    });

    RoomEffect skip(
      int? skipSlot, {
      String byUid = 'me',
      String id = 's',
      int? startedAt,
    }) => _effect(
      id: id,
      type: RewardType.skipFootPhoto,
      byUid: byUid,
      startedAt: startedAt ?? slotStart(2) + 10000,
    ).copyWith(skipSlot: skipSlot);

    Set<int> skipped(List<RoomEffect> effects) => skippedFootPhotoSlots(
      effects: effects,
      myUid: 'me',
      scheduleStartMillis: start,
      intervalSec: interval,
    );

    // 以前は lastPhotoAt から計算し直していたため、引いた後に撮り直すと
    // 飛ばす回が撮影済みのスロットへずれていた。いまは引いた瞬間に決めて
    // 書いた skipSlot だけを見る(lastPhotoAt は受け取らない)。
    test('引いた瞬間に決めたスロットだけを飛ばす(次の回は飛ばさない)', () {
      expect(skipped([skip(3)]), {3});
    });

    test('2回引いて同じスロットに重なったら、2回ぶん飛ばす', () {
      expect(skipped([skip(2, id: 'a'), skip(2, id: 'b')]), {2, 3});
    });

    test('ほかの人が引いたものは自分には効かない', () {
      expect(skipped([skip(2, byUid: 'other')]), isEmpty);
    });

    test('skipSlotが無い古いデータは、引いた時刻のスロット', () {
      expect(skipped([skip(null, startedAt: slotStart(4) + 1)]), {4});
      expect(skipped([skip(null, startedAt: start - 1)]), {0});
    });

    test('撮影スケジュールが決まっていなければ空', () {
      expect(
        skippedFootPhotoSlots(
          effects: [skip(2)],
          myUid: 'me',
          scheduleStartMillis: null,
          intervalSec: interval,
        ),
        isEmpty,
      );
    });
  });

  group('heldRewardsOf(持っていてまだ使っていないごほうび)', () {
    MissionSpot spot(String id, {String? by, RewardType? reward}) =>
        MissionSpot(
          id: id,
          lat: 35,
          lng: 137,
          radiusM: 15,
          claimedBy: by,
          reward: reward,
        );
    final missions = [
      Mission(
        id: 'm1',
        round: 1,
        createdAt: 0,
        expiresAt: 1,
        spots: [
          spot('s0', by: 'me', reward: RewardType.blockClues),
          spot('s1', by: 'other', reward: RewardType.blockClues),
          spot('s2', by: 'me', reward: RewardType.enlargeSelfIcon),
          spot('s3'),
        ],
      ),
      Mission(
        id: 'm2',
        round: 2,
        createdAt: 0,
        expiresAt: 1,
        spots: [spot('s0', by: 'me', reward: RewardType.blockClues)],
      ),
    ];

    test('自分が引いた持っておくごほうびだけを返す', () {
      expect(
        heldRewardsOf(missions: missions, effects: const [], uid: 'me'),
        [
          (missionId: 'm1', spotId: 's0', type: RewardType.blockClues),
          (missionId: 'm2', spotId: 's0', type: RewardType.blockClues),
        ],
      );
    });

    test('使ってある(effectsにある)ものは除く', () {
      expect(
        heldRewardsOf(
          missions: missions,
          effects: [_effect(id: 'm1_s0')],
          uid: 'me',
        ),
        [(missionId: 'm2', spotId: 's0', type: RewardType.blockClues)],
      );
    });

    test('uidが無ければ空', () {
      expect(
        heldRewardsOf(missions: missions, effects: const [], uid: null),
        isEmpty,
      );
    });
  });
}
