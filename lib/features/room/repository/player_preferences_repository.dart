import 'package:shared_preferences/shared_preferences.dart';

/// 端末ローカルに保存する、プレイヤーに関する情報へのアクセス。
///
/// 匿名認証のためサーバー側にユーザー情報は残らない。次回以降の入力の
/// 手間を減らすため、名前などをSharedPreferencesにキャッシュしておく。
/// 将来「前回のルームコードを覚えておく」等の項目が増えても対応しやすい
/// よう、値ごとに独立したメソッドとして公開する。
class PlayerPreferencesRepository {
  static const _displayNameKey = 'player.displayName';

  /// 保存済みの表示名を返す。未保存、または読み込みに失敗した場合はnull。
  Future<String?> loadDisplayName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_displayNameKey);
    } on Object {
      return null;
    }
  }

  /// 表示名を保存する。保存に失敗しても例外は投げない
  /// (次回また入力してもらうだけで、アプリの動作自体は止めない)。
  Future<void> saveDisplayName(String displayName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_displayNameKey, displayName);
    } on Object {
      // 保存できなくても致命的ではないため握りつぶす。
    }
  }
}
