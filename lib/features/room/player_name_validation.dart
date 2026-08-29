/// プレイヤー名として許容する最大文字数(前後の空白をトリムした後の長さで判定)。
const playerNameMaxLength = 10;

/// プレイヤー名のバリデーションエラー。
enum PlayerNameError {
  /// 空、または空白のみ。
  empty,

  /// トリム後の文字数が[playerNameMaxLength]を超えている。
  tooLong,
}

/// 前後の空白を取り除いた名前を返す。
String normalizePlayerName(String raw) => raw.trim();

/// 入力された名前(未トリム)を検証する。問題なければnull。
PlayerNameError? validatePlayerName(String raw) {
  final normalized = normalizePlayerName(raw);
  if (normalized.isEmpty) return PlayerNameError.empty;
  if (normalized.length > playerNameMaxLength) return PlayerNameError.tooLong;
  return null;
}
