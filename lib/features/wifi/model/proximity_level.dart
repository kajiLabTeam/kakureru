/// Wi-Fi近接判定の3段階。
enum ProximityLevel {
  /// 近い。
  close,

  /// 遠い。
  far,

  /// 判定に十分なデータが無い(共通APが少ない・Jaccard係数が低い等)。
  notDetected,
}
