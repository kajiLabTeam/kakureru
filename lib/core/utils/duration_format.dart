/// 残り秒数を「MM:SS」形式の文字列にする(例: 310秒 → "05:10")。
///
/// ゲーム画面モック(kakureru-ui-mock.html)の「02:30」「24:13」表記に合わせ、
/// 分も2桁に揃える。桁数が変わらないので、毎秒の更新で横幅が揺れない。
/// 負の値は0として扱う(既に過ぎている場合の表示用)。
String formatCountdown(int totalSeconds) {
  final clamped = totalSeconds < 0 ? 0 : totalSeconds;
  final minutes = clamped ~/ 60;
  final seconds = clamped % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
