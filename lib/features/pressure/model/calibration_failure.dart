/// 気圧キャリブレーションが失敗した理由。
///
/// 以前は失敗しても状態に何も残らず、ボタンが元に戻るだけだったため、
/// 押した本人には「効いていない」ようにしか見えなかった(issue #98)。
enum CalibrationFailure {
  /// 失敗していない(まだ試していない・成功した)。
  none,

  /// 気圧センサーの値がまだ取れていない。
  noPressure,

  /// ホストがまだキャリブレーションしておらず、基準値が無い(参加者のみ)。
  noBasePressure,

  /// RTDBへの書き込みに失敗した(通信断・権限エラー等)。
  writeFailed,
}

/// 失敗の理由を、画面にそのまま出せる1行の日本語にする。
/// 失敗していなければnull。
///
/// 例外の文面をそのまま出さないのは、原因(通信・権限)が利用者には
/// 読み取れず、次に何をすればよいかも分からないため。
String? calibrationFailureMessage(CalibrationFailure failure) {
  switch (failure) {
    case CalibrationFailure.none:
      return null;
    case CalibrationFailure.noPressure:
      return '気圧をまだ取得できていません。少し待ってからもう一度お試しください';
    case CalibrationFailure.noBasePressure:
      return 'ホストのキャリブレーションが終わってから、もう一度お試しください';
    case CalibrationFailure.writeFailed:
      return 'キャリブレーションに失敗しました。通信状況を確認して、もう一度お試しください';
  }
}
