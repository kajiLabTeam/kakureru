/// 参加者1人分の気圧センサーキャリブレーション状況。
enum CalibrationStatus {
  /// この端末は気圧センサー非搭載で、キャリブレーション自体が不要。
  unavailable,

  /// センサーはあるが、まだキャリブレーションを済ませていない。
  pending,

  /// キャリブレーション済み。
  done,
}

/// 1人分のキャリブレーション状況を判定する。
///
/// ホストは`room.basePressure`、参加者は`user.pressureOffset`の有無で
/// 完了を判定する(書き込み先のパスが役割によって異なるため)。
/// `sensorAvailable`が明示的にfalseの場合のみ非対応扱いにし、
/// 未確定(null、判定中)の場合は完了扱いにならない限りpendingとする。
CalibrationStatus calibrationStatusFor({
  required bool isHost,
  required bool? sensorAvailable,
  required double? basePressure,
  required double? pressureOffset,
}) {
  final done = isHost ? basePressure != null : pressureOffset != null;
  if (done) return CalibrationStatus.done;
  if (sensorAvailable == false) return CalibrationStatus.unavailable;
  return CalibrationStatus.pending;
}

/// センサー搭載者(unavailable以外)全員が完了しているかどうか。
/// センサー搭載者が1人もいなければ(全員unavailableなら)真を返す。
bool isCalibrationComplete(Iterable<CalibrationStatus> statuses) {
  return statuses.every((status) => status != CalibrationStatus.pending);
}
