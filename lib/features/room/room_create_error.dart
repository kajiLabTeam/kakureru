/// ルーム作成に失敗した理由。
///
/// RoomJoinErrorと同じく、画面側でユーザー向けの日本語へ変換するために
/// メッセージ文字列ではなく理由そのものを投げる。
/// データを持たないのでenumをそのまま例外として使う。
enum RoomCreateError implements Exception {
  /// 未使用の4桁コードを引き当てられなかった。コードは9000通りしか無く、
  /// 使い終わったルームのコードも解放されない運用のため、埋まってくると
  /// 抽選が連続で外れる(docs/rtdb-schema.md「Phase 1の限界」参照)。
  codeExhausted,
}
