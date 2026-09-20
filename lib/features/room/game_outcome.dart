/// ゲームの決着。
enum GameOutcome {
  /// 逃走者が1人以上残ったまま終了した(逃走者側の勝ち)。
  fugitivesEscaped,

  /// 逃走者が全員鬼になった(鬼側の勝ち)。
  demonsWon,
}

/// 終了時点の逃走者の人数から決着を判定する。
///
/// `isGameOver`(role_visibility.dart)が「逃走者0人」自体を終了条件に
/// しているため、終了した時点の逃走者の人数がそのまま勝敗になる:
/// - 時間切れで終わったなら、残っている逃走者は逃げ切り
/// - 全員捕まって終わったなら、逃走者は0人なので鬼の勝ち
GameOutcome determineGameOutcome({required int survivedFugitiveCount}) {
  return survivedFugitiveCount > 0
      ? GameOutcome.fugitivesEscaped
      : GameOutcome.demonsWon;
}

/// 結果画面のヘッダーに出す見出しと内訳(UI改修モック2a-08)。
///
/// 値を保持するだけの型だが、Freezed必須ルール(AGENTS.md)の対象になる
/// クラスを増やさずに済むようレコードにしている。
({String title, String summary}) describeGameOutcome({
  required GameOutcome outcome,
  required int survivedFugitiveCount,
}) {
  switch (outcome) {
    case GameOutcome.fugitivesEscaped:
      return (
        title: 'タイムアップ',
        summary: '逃走者 $survivedFugitiveCount人 が逃げ切り',
      );
    case GameOutcome.demonsWon:
      return (title: '全員捕まりました', summary: '鬼の勝ち');
  }
}
