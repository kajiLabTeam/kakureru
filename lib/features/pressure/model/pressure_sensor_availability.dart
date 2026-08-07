/// 気圧センサーの搭載状況。
///
/// sensors_plus には搭載有無を直接判定するAPIが無いため、
/// PressureRepository.checkSensorAvailable が実際にイベントを待って判定する。
/// 判定が終わるまでは [checking] のままにしておき、
/// 「非搭載」と誤表示しないようにする。
enum PressureSensorAvailability {
  /// 判定中(起動直後など)。
  checking,

  /// センサーが使える。
  available,

  /// センサーが無い、または一定時間イベントが来なかった。
  unavailable,
}
