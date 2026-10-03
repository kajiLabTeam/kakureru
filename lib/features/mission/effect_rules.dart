/// ごほうびの効果(`effects`)の残り時間・有効かどうか・足元写真を飛ばす
/// スロットの純粋な計算。
///
/// 残り時間は**端末の時計ではなくサーバー時刻**で数える。`startedAt` は
/// `ServerValue.timestamp` で書くので、比べる「今」も `serverNowMillis` を
/// 渡すこと(端末ごとに時計がずれていても、全員の帯の残り時間が揃う)。
library;

import 'dart:math' as math;

import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/model/room_effect.dart';
import 'package:kakureru/features/mission/repository/mission_repository.dart'
    show missionEffectId;
import 'package:kakureru/features/room/model/photo_slot.dart';

/// 今のゲームの効果だけを、発動した順(古い順)に返す。[startedAt]が
/// null(開始前)なら空。前のゲームの効果は `restartRoom` で消えないため。
List<RoomEffect> effectsOfCurrentGame(
  List<RoomEffect> effects, {
  required int? startedAt,
}) {
  if (startedAt == null) return const [];
  return effects.where((e) => e.startedAt >= startedAt).toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
}

/// 効果が切れる時刻(サーバー時刻のミリ秒) = `startedAt + durationMs`。
int effectEndsAt(RoomEffect effect) => effect.startedAt + effect.durationMs;

/// 効果の残り時間(ミリ秒)。切れていれば0。
///
/// [serverNowMillis]は `serverNowMillis(offset)` の値を渡す。端末の時計を
/// そのまま渡すと、時計が進んでいる端末だけ早く切れる。
int effectRemainingMillis(RoomEffect effect, {required int serverNowMillis}) {
  final remaining = effectEndsAt(effect) - serverNowMillis;
  return remaining < 0 ? 0 : remaining;
}

/// 時間で効く効果が、いま効いているか。回数もの(`durationMs == 0`)は
/// 常にfalse。
bool isEffectActive(RoomEffect effect, {required int serverNowMillis}) =>
    effect.durationMs > 0 &&
    effectRemainingMillis(effect, serverNowMillis: serverNowMillis) > 0;

/// [type]の効果のうち、いま効いていて一番長く残るもの。無ければnull。
///
/// 同じ効果を続けて引いたときは、帯には一番後まで残るものを出す。
RoomEffect? activeEffectOf(
  List<RoomEffect> effects,
  RewardType type, {
  required int serverNowMillis,
}) {
  RoomEffect? best;
  for (final effect in effects) {
    if (effect.type != type) continue;
    if (!isEffectActive(effect, serverNowMillis: serverNowMillis)) continue;
    if (best == null || effectEndsAt(effect) > effectEndsAt(best)) {
      best = effect;
    }
  }
  return best;
}

/// いま効いている、時間で効く効果の一覧(地図の上の帯に出すもの)。
///
/// `enlarge_self_icon`(自分のアイコンを大きくする)は除く。これは `byUid` の本人にだけ出す
/// 個人向けの表示のため、ここでは全体から1件だけ選んでしまうと複数の
/// 逃走者が同時に引いたときに他の人の分が隠れてしまう([activeEnlargeSelfIconEffectFor]を使うこと)。
List<RoomEffect> activeTimedEffects(
  List<RoomEffect> effects, {
  required int serverNowMillis,
}) => [
  for (final type in RewardType.values)
    if (type != RewardType.enlargeSelfIcon)
      ?activeEffectOf(effects, type, serverNowMillis: serverNowMillis),
];

/// [uid]が引いた `enlarge_self_icon` のうち、いま効いているもの。無ければ
/// null。本人向けの帯(「あなたのアイコンが大きくなっている」)に使う。
RoomEffect? activeEnlargeSelfIconEffectFor(
  List<RoomEffect> effects, {
  required String? uid,
  required int serverNowMillis,
}) {
  if (uid == null) return null;
  return activeEffectOf(
    effects.where((e) => e.byUid == uid).toList(),
    RewardType.enlargeSelfIcon,
    serverNowMillis: serverNowMillis,
  );
}

/// いま `enlarge_self_icon` が効いている人のuid一覧。全員の地図でその
/// 人のピンを大きくする対象を決めるために使う(複数人が同時に効いて
/// いることもあるため、1件に絞らず集合で返す)。
Set<String> activeEnlargeSelfIconUids(
  List<RoomEffect> effects, {
  required int serverNowMillis,
}) => {
  for (final effect in effects)
    if (effect.type == RewardType.enlargeSelfIcon &&
        isEffectActive(effect, serverNowMillis: serverNowMillis))
      effect.byUid,
};

/// `skip_foot_photo` を引いた瞬間に、どの撮影スロットを飛ばすかを決める。
///
/// 撮影タイムが来ていてまだ撮っていなければ([isDue]。撮影バナーが出て
/// いる状態)**そのスロット**、そうでなければ**次のスロット**。撮影が
/// まだ始まっていなければ最初のスロット(0)。
///
/// 引いた瞬間に1回だけ決めて `effects/{id}/skipSlot` に書く。後から
/// `lastPhotoAt` を見て計算し直すと、引いた後に撮り直したときに飛ばす回が
/// 撮影済みのスロットへずれて、ごほうびが無駄になるため。[isDue]はアップロード
/// 中の撮影も含めた撮影バナーの判定(`PhotoCaptureState.isDue`)を渡す。
/// 撮影スケジュールが未確定([scheduleStartMillis]がnull)ならnull。
int? footPhotoSlotToSkip({
  required int? scheduleStartMillis,
  required int intervalSec,
  required int nowMillis,
  required bool isDue,
}) {
  final start = scheduleStartMillis;
  if (start == null) return null;
  final current = currentPhotoSlotIndex(
    startedAt: start,
    nowMillis: nowMillis,
    intervalSec: intervalSec,
  );
  if (current < 0) return 0;
  return isDue ? current : current + 1;
}

/// `skip_foot_photo` で飛ばす撮影スロットの番号(自分のぶん)。
///
/// 引いた瞬間に決めた `skipSlot` を使う。2回引いて同じスロットに重なったら、
/// 後のものはその次へずらす(1回引くごとに1回ぶん飛ばせるように)。
/// `skipSlot` が無い古いデータは、引いた時刻のスロット(撮影前なら0)にする。
///
/// [scheduleStartMillis]は撮影スケジュールの基準([photoScheduleStartMillis])。
/// 未確定(null)なら空。
Set<int> skippedFootPhotoSlots({
  required List<RoomEffect> effects,
  required String? myUid,
  required int? scheduleStartMillis,
  required int intervalSec,
}) {
  final start = scheduleStartMillis;
  if (start == null || myUid == null) return const {};
  final mine =
      effects
          .where((e) => e.type == RewardType.skipFootPhoto && e.byUid == myUid)
          .toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

  final skipped = <int>{};
  for (final effect in mine) {
    var slot =
        effect.skipSlot ??
        math.max(
          0,
          currentPhotoSlotIndex(
            startedAt: start,
            nowMillis: effect.startedAt,
            intervalSec: intervalSec,
          ),
        );
    while (skipped.contains(slot)) {
      slot++;
    }
    skipped.add(slot);
  }
  return skipped;
}

/// 持っていてまだ使っていないごほうび1つ。使うときは
/// `MissionRepository.useHeldReward(roomId, missionId, spotId)` に渡す。
typedef HeldReward = ({String missionId, String spotId, RewardType type});

/// [uid]が持っていて、まだ使っていないごほうび(引いた順)。
///
/// 持っておくごほうび([RewardType.isHeld])は、引いたときは地点の `reward`
/// だけを書き、使ったときに `effects/{missionId}_{spotId}` を書く。なので
/// 「自分が取った地点の `reward` が持っておくもので、同じキーの効果がまだ
/// 無い」ものが手元に残っている。[missions]は `missionsOfCurrentGame` で
/// 今のゲームに絞ったもの、[effects]は効果の一覧を渡す。
List<HeldReward> heldRewardsOf({
  required List<Mission> missions,
  required List<RoomEffect> effects,
  required String? uid,
}) {
  if (uid == null) return const [];
  final usedIds = effects.map((e) => e.id).toSet();
  return [
    for (final mission in missions)
      for (final spot in mission.spots)
        if (spot.claimedBy == uid &&
            (spot.reward?.isHeld ?? false) &&
            !usedIds.contains(missionEffectId(mission.id, spot.id)))
          (missionId: mission.id, spotId: spot.id, type: spot.reward!),
  ];
}
