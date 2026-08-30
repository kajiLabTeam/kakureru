/// 同時に1つしか実行させないための単純なガード。
///
/// ボタンの二重押し対策に使う。RTDBへの書き込みはネットワーク往復の
/// 遅延があり、その結果(例: room.pendingDemonUid)が画面に反映されるまでの
/// 間はボタンがまだ有効なままなことがあるため、ローカルの実行中フラグで
/// 即座に多重発火を防ぐ。前の呼び出しがまだ完了していない間に呼ばれた
/// 場合は何もしない(先勝ち)。
class SingleFlightAction {
  bool _running = false;

  bool get isRunning => _running;

  Future<void> run(Future<void> Function() action) async {
    if (_running) return;
    _running = true;
    try {
      await action();
    } finally {
      _running = false;
    }
  }
}
