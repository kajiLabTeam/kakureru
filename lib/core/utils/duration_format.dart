/// 残り秒数を「M:SS」形式の文字列にする(例: 310秒 → "5:10")。
///
/// UI改修モック(docs/ui-mockup-2a.html)のゲーム中画面が採用している表記。
/// 負の値は0として扱う(既に過ぎている場合の表示用)。
String formatCountdown(int totalSeconds) {
  final clamped = totalSeconds < 0 ? 0 : totalSeconds;
  final minutes = clamped ~/ 60;
  final seconds = clamped % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
