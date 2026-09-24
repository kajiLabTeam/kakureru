/// 写真アップロード(`PUT /rooms/{roomId}/photos/{photoId}`)のレスポンスから
/// 「成功として扱うか」「どう再試行すべきか」を決める純粋関数。
///
/// HTTP通信そのものは[PhotoRepository](repository/photo_repository.dart)が
/// 行い、ステータスコードからの判定だけをここに切り出す。IO抜きでテストする
/// 方針は`pressure_math.dart`/`proximity_calculator.dart`と同じ。

/// ステータスコードの判定結果。
enum PhotoUploadOutcome {
  /// アップロード成功として扱う。
  ///
  /// 204(新規保存)に加えて409(同じキーが既に存在)もここに含める。
  /// photoIdはRTDBのpush keyで生成する使い捨ての値で、衝突が起きるとすれば
  /// 「レスポンスが届く前に通信が切れて呼び出し側が再送した」場合しかない
  /// ため、409は他人との衝突ではなく自分自身の再送とみなしてよい
  /// (Worker側の実装、`kakureru-photo-api/src/index.js`のhead-then-put参照)。
  success,

  /// 401。IDトークンの期限切れ・失効が疑われるので、呼び出し側は
  /// `getIdToken(true)`で強制更新してから1回だけ再送する。
  unauthorized,

  /// 413。上限(2MB)超過。呼び出し側で画質を下げても直る保証がないため、
  /// 再試行せず失敗として扱う。
  tooLarge,

  /// 上記以外の失敗(ネットワーク瞬断・5xx等)。呼び出し側は
  /// 指数バックオフで再試行してよい。
  otherFailure,
}

/// HTTPステータスコードから[PhotoUploadOutcome]を判定する。
PhotoUploadOutcome judgePhotoUploadStatusCode(int statusCode) {
  switch (statusCode) {
    case 204:
    case 409:
      return PhotoUploadOutcome.success;
    case 401:
      return PhotoUploadOutcome.unauthorized;
    case 413:
      return PhotoUploadOutcome.tooLarge;
    default:
      return PhotoUploadOutcome.otherFailure;
  }
}
