import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

/// 写真アップロード先(`kakureru-photo-api` Worker)のベースURL。
///
/// `--dart-define-from-file=dart_defines.json` 経由で渡す
/// (dart_defines.example.json参照)。CARTO_API_KEYと同じ渡し方に揃えており、
/// ハードコードしないのは環境ごとに向き先を切り替えられるようにするため。
const String photoApiBaseUrl = String.fromEnvironment('PHOTO_API_BASE_URL');

/// [photoApiBaseUrl]が設定されているか。
///
/// 未設定でもアプリ全体をクラッシュさせず、写真機能だけを無効化する
/// (呼び出し側はこれを見て撮影バナーの表示自体を止める)。
bool get isPhotoFeatureConfigured => photoApiBaseUrl.isNotEmpty;

bool _hasWarnedMissingConfig = false;

/// [photoApiBaseUrl]が未設定のとき、デバッグビルドで一度だけ警告ログを出す。
///
/// タイマーやウィジェット再構築のたびに呼ばれても、プロセス内で1回しか
/// 出さない(起動のたびに大量に出て他のログに埋もれるのを避けるため)。
void warnIfPhotoFeatureNotConfigured() {
  if (isPhotoFeatureConfigured) return;
  if (_hasWarnedMissingConfig) return;
  _hasWarnedMissingConfig = true;
  if (kDebugMode) {
    debugPrint(
      '[photo_capture_config] PHOTO_API_BASE_URL が未設定のため、写真機能を無効化します。'
      'dart_defines.json に設定してください(dart_defines.example.json参照)。',
    );
  }
}
