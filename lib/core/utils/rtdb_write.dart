import 'package:flutter/foundation.dart' show debugPrint;

/// センサー値の定期送信のように「1回失敗しても次の周期で送り直せばよいが、
/// 黙って消えると原因調査ができない」RTDB書き込みを実行する。
///
/// [write] の完了を待ち、失敗しても例外を呼び出し側へ投げ返さず
/// `[$tag] $fieldの書き込みに失敗: ...` の形でログにだけ残す。await せずに
/// 投げっぱなしにすると、失敗は未処理の非同期エラーとしてどこにも出ずに
/// 消えてしまうため、ここで必ず待ち合わせる。
///
/// Wi-Fi(`WifiScanRepository`)と気圧(`PressureRepository`)の定期送信が
/// まったく同じ扱いを必要とするため、同じtry/catchを2箇所に書かないよう
/// 切り出している。
///
/// [log] はテストから出力を検証するためだけの引数。省略すると [debugPrint]。
Future<void> writeOrLogFailure(
  Future<void> Function() write, {
  required String tag,
  required String field,
  void Function(String message)? log,
}) async {
  try {
    await write();
  } on Object catch (e) {
    (log ?? _logWithDebugPrint)('[$tag] $fieldの書き込みに失敗: $e');
  }
}

void _logWithDebugPrint(String message) => debugPrint(message);
