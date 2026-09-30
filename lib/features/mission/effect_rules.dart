/// ごほうびの効果(`effects`)の残り時間・有効かどうか・足元写真を飛ばす
/// スロットの純粋な計算。
///
/// 残り時間は**端末の時計ではなくサーバー時刻**で数える。`startedAt` は
/// `ServerValue.timestamp` で書くので、比べる「今」も `serverNowMillis` を
/// 渡すこと(端末ごとに時計がずれていても、全員の帯の残り時間が揃う)。
library;

import 'dart:math' as math;

import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/model/room_effect.dart';
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
List<RoomEffect> activeTimedEffects(
  List<RoomEffect> effects, {
  required int serverNowMillis,
}) => [
  for (final type in RewardType.values)
    ?activeEffectOf(effects, type, serverNowMillis: serverNowMillis),
];

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
