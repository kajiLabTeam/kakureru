/// 写真一覧・拡大表示で時刻を「17:00」のように表示するための整形。
///
/// このプロジェクトは`intl`パッケージを使っていないため、`DateTime`の
/// フィールドから手で組み立てる。
library;

/// [epochMillis]を端末のローカル時刻でHH:MM形式にする(0埋め)。
String formatClockTime(int epochMillis) {
  final local = DateTime.fromMillisecondsSinceEpoch(epochMillis).toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
