/// ミッションまわりの時間の定数。**時間の数値はすべてここに置く**
/// (ほかのファイルに秒数・分数を直接書かない)。
///
/// 企画(1段目)の決まりごと:
/// - 1回目は鬼の放出から3分後、2回目は10分後、3回目は25分後。4回目は無い
/// - 制限時間は5分。同時に出すのは1件だけ
/// - 地点がすべて取られたら、その場で終わる
/// - 次の回の前にゲームが終わったら、その回は出ない
library;

/// 鬼の放出から1回目のミッションを出すまで。
const firstMissionDelay = Duration(minutes: 3);

/// 鬼の放出から2回目のミッションを出すまで。
const secondMissionDelay = Duration(minutes: 10);

/// 鬼の放出から3回目のミッションを出すまで。
const thirdMissionDelay = Duration(minutes: 25);

/// 回ごとの「放出から出すまで」。`missionDueDelays[0]`が1回目。
/// 長さがそのまま回数の上限になる(4回目は出さない)。
const List<Duration> missionDueDelays = [
  firstMissionDelay,
  secondMissionDelay,
  thirdMissionDelay,
];

/// ミッションの制限時間(`expiresAt = createdAt + missionTimeLimit`)。
const missionTimeLimit = Duration(minutes: 5);

/// 期限のこの時間前に「まだ空いている」を知らせる。
const missionLastMinuteWarning = Duration(minutes: 1);

/// 地点がすべて取られて早く終わったミッションのカード(「ほかの人に
/// 取られた」「ごほうびを引いた」)を出しておく時間。
const finishedMissionCardDuration = Duration(seconds: 15);

/// ごほうび「鬼の手がかりを止める」の、使ってから効いている時間。
const rewardEffectDuration = Duration(minutes: 3);

/// ごほうび「自分のアイコンを大きくする」の効いている時間。
const enlargeSelfIconDuration = Duration(minutes: 2, seconds: 30);

/// アプリ内のお知らせ(バナー)を出しておく時間。
const missionBannerDuration = Duration(seconds: 8);

/// 「終わった」のお知らせを出してよい、終わってからの猶予。これより前に
/// 終わったミッションは、入り直したときなどに今さら知らせない。
const missionFinishedNoticeGrace = Duration(seconds: 15);

/// ホストの端末がミッションを書いた直後、同じ判定で二重に書かないための
/// 間隔。書いたミッションが購読に戻ってくるまでの間を埋める。
const missionCreateCooldown = Duration(seconds: 5);

/// 判定(生成・到着・お知らせ)を回す周期。
const missionEvaluateInterval = Duration(seconds: 1);
