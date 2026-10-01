/// 特典ガチャの確定演出の段と、時間・タップでの進み方(純粋な計算)。
///
/// 待たされるのは最初の2段(ハンドル・激熱)だけで、あとはタップで進む。
/// 毎回見る演出なので、**どの段でもタップ1回で最後(特典カード)まで
/// 飛ばせる**。ただしカプセルの段のタップは「開ける」で、開く演出を見せる。
library;

/// 演出の段。
enum GachaPhase {
  /// ハンドルを回す(1.5秒)。ハンドルが3回転、筐体が揺れ、集中線が回り出し、
  /// きたい度のランプが 青 → 緑 → 赤 と点く。
  turning,

  /// 激熱(1.4秒)。画面が赤一色になり、文字が飛び込んで画面ごと揺れる。
  heat,

  /// 金のカプセルが落ちて2回弾む。脈打って光り、タップを待つ。
  capsule,

  /// 確定(当たり)。白く弾ける → 虹の輪・紙吹雪・「確定」のハンコ → 特典カード。
  confirmed,

  /// ハズレ。激熱を出さず、赤い「残念」で短く終わる。
  missed,
}

/// ハンドルを回す段の長さ。
const gachaTurningDuration = Duration(milliseconds: 1500);

/// 激熱の段の長さ。
const gachaHeatDuration = Duration(milliseconds: 1400);

/// 確定(当たり)の段の、ハンコと特典カードが出そろうまでの長さ。
const gachaConfirmDuration = Duration(milliseconds: 1100);

/// ハズレの段の、「残念」と特典カードが出そろうまでの長さ。当たりより
/// 短くする(待たされた末のハズレを長引かせない)。
const gachaMissedDuration = Duration(milliseconds: 700);

/// ハンドルの回転数(ハンドルを回す段の間に回る数)。
const gachaKnobTurns = 3;

/// 紙吹雪の枚数(同時に動かすアニメを抑えるため10枚まで)。
const gachaConfettiCount = 10;

/// 緑のランプが点くまでの時間(ハンドルを回し始めてから)。
const gachaGreenLampDelay = Duration(milliseconds: 150);

/// 赤のランプが点くまでの時間(ハンドルを回し始めてから)。
const gachaRedLampDelay = Duration(milliseconds: 550);

/// 時間で進む段(ハンドル・激熱)の、始まってから[elapsed]たったときの段。
/// 時間で進むのはカプセルまで。カプセルから先はタップでしか進まない。
///
/// [isMiss]ならハズレなので激熱を出さず、ハンドルのあとすぐカプセルに進む。
GachaPhase gachaPhaseAt(Duration elapsed, {bool isMiss = false}) {
  if (elapsed < gachaTurningDuration) return GachaPhase.turning;
  if (!isMiss && elapsed < gachaTurningDuration + gachaHeatDuration) {
    return GachaPhase.heat;
  }
  return GachaPhase.capsule;
}

/// タップしたときの動き。
enum GachaTapAction {
  /// 確定の段の終わり(特典カードが出そろった状態)まで一気に飛ばす。
  skipToEnd,

  /// カプセルを開ける(確定の段の演出を最初から見せる)。
  open,
}

/// [phase]でタップしたときにどう進むか。
///
/// カプセルの段だけは「開ける」。それ以外(ハンドル・激熱・確定の途中)は
/// 最後まで飛ばす。確定の段が出そろった後のタップは何もしない
/// (呼び出し側で「地図にもどる」等のボタンを押させる)。
GachaTapAction gachaTapAction(GachaPhase phase) => switch (phase) {
  GachaPhase.capsule => GachaTapAction.open,
  GachaPhase.turning ||
  GachaPhase.heat ||
  GachaPhase.confirmed ||
  GachaPhase.missed => GachaTapAction.skipToEnd,
};

/// きたい度のランプが何個点いているか(1〜3)。ハンドルを回し始めてから
/// [elapsed]たったとき。青は最初から、緑は0.15秒、赤は0.55秒で点く。
int gachaLitLamps(Duration elapsed) {
  if (elapsed >= gachaRedLampDelay) return 3;
  if (elapsed >= gachaGreenLampDelay) return 2;
  return 1;
}
