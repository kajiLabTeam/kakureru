/// 写真ダウンロード(`GET /rooms/{roomId}/photos/{photoId}`)のレスポンスから
/// 「成功として扱うか」「どう再試行すべきか」を決める純粋関数。
///
/// [PhotoUploadOutcome](photo_upload_decision.dart)と対になる形。HTTP通信は
/// [PhotoRepository](repository/photo_repository.dart)が行い、ステータス
/// コードからの判定だけをここに切り出す。

/// ステータスコードの判定結果。
enum PhotoDownloadOutcome {
  /// ダウンロード成功。
  success,

  /// 401。IDトークンの期限切れ・失効が疑われるので、呼び出し側は
  /// `getIdToken(true)`で強制更新してから1回だけ再送する。
  unauthorized,

  /// 上記以外の失敗(ネットワーク瞬断・404・5xx等)。
  otherFailure,
}

/// HTTPステータスコードから[PhotoDownloadOutcome]を判定する。
PhotoDownloadOutcome judgePhotoDownloadStatusCode(int statusCode) {
  switch (statusCode) {
    case 200:
      return PhotoDownloadOutcome.success;
    case 401:
      return PhotoDownloadOutcome.unauthorized;
    default:
      return PhotoDownloadOutcome.otherFailure;
  }
}
