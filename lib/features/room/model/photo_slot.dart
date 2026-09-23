/// 写真撮影の「スロット」計算(純粋関数)。
///
/// スロットは `setting/photoIntervalSec` ごとに区切られた撮影の時間帯。
/// `meta/startedAt` を基準に、経過ミリ秒をスロット長で割った商がスロット番号
/// になる。撮影・閲覧のどちらの判定もこのスロット番号の一致で行う
/// (docs参照。RTDBの `photos/{photoId}` は `{uid, takenAt}` のみを持ち、
/// スロット番号自体は保存しない=常にこの関数で導出する)。
library;

/// [takenAt]（または現在時刻）が属するスロット番号。
///
/// [startedAt] はゲーム開始時刻(`meta/startedAt`)、[intervalSec] は
/// `setting/photoIntervalSec`。
int photoSlotIndexOf({
  required int takenAt,
  required int startedAt,
  required int intervalSec,
}) {
  final intervalMillis = intervalSec * 1000;
  return ((takenAt - startedAt) / intervalMillis).floor();
}

/// [slotIndex]番目のスロットが始まる時刻(ミリ秒)。
int photoSlotStartMillis({
  required int startedAt,
  required int slotIndex,
  required int intervalSec,
}) {
  return startedAt + slotIndex * intervalSec * 1000;
}

/// [slotIndex]番目のスロットが終わる(次のスロットが始まる)時刻(ミリ秒)。
int photoSlotEndMillis({
  required int startedAt,
  required int slotIndex,
  required int intervalSec,
}) {
  return photoSlotStartMillis(
    startedAt: startedAt,
    slotIndex: slotIndex + 1,
    intervalSec: intervalSec,
  );
}

/// 現在時刻([nowMillis])が属するスロット番号。
///
/// 撮影できるのはこの番号のスロットの間だけ(`photoSlotIndexOf`と同じ式に
/// [nowMillis]を渡しているだけ)。
int currentPhotoSlotIndex({
  required int startedAt,
  required int nowMillis,
  required int intervalSec,
}) {
  return photoSlotIndexOf(
    takenAt: nowMillis,
    startedAt: startedAt,
    intervalSec: intervalSec,
  );
}
