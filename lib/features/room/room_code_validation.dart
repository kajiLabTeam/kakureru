/// ルームコードの桁数(`_reserveRoomCode`が発行するのは1000〜9999の4桁)。
const roomCodeLength = 4;

/// ルームコードのバリデーションエラー。
enum RoomCodeError {
  /// 未入力(空、または空白のみ)。
  empty,

  /// 4桁の数字になっていない(桁数が足りない/多い、数字以外を含む)。
  invalidFormat,
}

final _digitsOnly = RegExp(r'^\d+$');

/// 前後の空白を取り除いたコードを返す。
String normalizeRoomCode(String raw) => raw.trim();

/// 入力されたコード(未トリム)を検証する。問題なければnull。
///
/// 空のまま参加を押すと参照先が`roomCodes/`になり権限エラーになるため、
/// 画面はこの結果で参加ボタンの活性を制御する。
RoomCodeError? validateRoomCode(String raw) {
  final normalized = normalizeRoomCode(raw);
  if (normalized.isEmpty) return RoomCodeError.empty;
  if (normalized.length != roomCodeLength ||
      !_digitsOnly.hasMatch(normalized)) {
    return RoomCodeError.invalidFormat;
  }
  return null;
}
