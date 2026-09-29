/// 写真撮影の「スロット」計算(純粋関数)。
///
/// スロットは `setting/photoIntervalSec` ごとに区切られた撮影の時間帯。
/// 撮影は鬼が放たれてから1間隔たった時点(`meta/releasedAt` + 間隔、
/// [photoScheduleStartMillis])から始まり、そこを基準に、経過ミリ秒を
/// スロット長で割った商がスロット番号になる。以下の関数の `startedAt` は
/// この撮影スケジュールの基準時刻(=スロット0の開始)を指す。撮影・閲覧のどちらの判定もこのスロット番号の一致で行う
/// (docs参照。RTDBの `photos/{photoId}` は `{uid, takenAt}` のみを持ち、
/// スロット番号自体は保存しない=常にこの関数で導出する)。
library;

/// 撮影スケジュールの基準時刻(スロット0の開始=1回目の撮影タイミング)。
///
/// 鬼の放出待ちの間は撮影しない。1回目は鬼が放たれて([releasedAt] =
/// `meta/releasedAt`)から[intervalSec]たった時点で、以後[intervalSec]ごと。
/// [releasedAt]が未確定(ゲーム開始前)ならnull。
int? photoScheduleStartMillis({
  required int? releasedAt,
  required int intervalSec,
}) {
  if (releasedAt == null) return null;
  return releasedAt + intervalSec * 1000;
}

/// [takenAt]（または現在時刻）が属するスロット番号。
///
/// [startedAt] は撮影スケジュールの基準時刻([photoScheduleStartMillis])、
/// [intervalSec] は `setting/photoIntervalSec`。基準より前は負の番号になる。
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

/// いま撮影を促すべきか(=現在のスロットでまだ撮っていないか)。
///
/// 撮影の通知・バナーはこの判定に揃える。以前は「前回の撮影(未撮影なら
/// 画面を開いた時刻)+間隔」で通知していたため、スロットの区切りとずれて
/// 最初のスロットの通知がスロット終了時にしか来ない等の取りこぼしがあった。
///
/// [lastPhotoAt]は自分の直近の撮影時刻(未撮影ならnull)。撮影スケジュールの
/// 開始前([nowMillis]が[startedAt]より前=鬼の放出待ちと放出後の最初の
/// 1間隔)は促さない。
bool isPhotoCaptureDue({
  required int startedAt,
  required int? lastPhotoAt,
  required int nowMillis,
  required int intervalSec,
}) {
  final currentSlot = currentPhotoSlotIndex(
    startedAt: startedAt,
    nowMillis: nowMillis,
    intervalSec: intervalSec,
  );
  if (currentSlot < 0) return false;
  if (lastPhotoAt == null) return true;
  final takenSlot = photoSlotIndexOf(
    takenAt: lastPhotoAt,
    startedAt: startedAt,
    intervalSec: intervalSec,
  );
  return takenSlot < currentSlot;
}

/// [nowMillis]の次にスロットが切り替わる時刻(ミリ秒)。撮影を促すかどうかを
/// 判定し直すタイミングに使う。撮影スケジュールの開始前なら開始時刻
/// ([startedAt])。
int nextPhotoSlotBoundaryMillis({
  required int startedAt,
  required int nowMillis,
  required int intervalSec,
}) {
  if (nowMillis < startedAt) return startedAt;
  return photoSlotEndMillis(
    startedAt: startedAt,
    slotIndex: currentPhotoSlotIndex(
      startedAt: startedAt,
      nowMillis: nowMillis,
      intervalSec: intervalSec,
    ),
    intervalSec: intervalSec,
  );
}
