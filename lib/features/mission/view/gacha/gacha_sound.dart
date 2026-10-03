import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/mission/view/gacha/gacha_phase.dart';
import 'package:vibration/vibration.dart';

/// ガチャの効果音(issue #160)。音源は`assets/sounds/gacha/`で、
/// 出どころとライセンスは`docs/gacha-sounds.md`。
enum GachaCue {
  /// ハンドルを回す … カチカチ。
  turning('turning.wav'),

  /// 激熱 … 低い音の溜め。
  heat('heat.wav'),

  /// カプセルが落ちる … コロン。
  drop('drop.wav'),

  /// 確定 … ファンファーレ。
  fanfare('fanfare.wav'),

  /// ハズレ … 短く低い音。
  miss('miss.wav');

  const GachaCue(this.fileName);

  /// `assets/sounds/gacha/`の中のファイル名。
  final String fileName;
}

/// [phase]に入ったときに鳴らす音。
GachaCue gachaCueFor(GachaPhase phase) => switch (phase) {
  GachaPhase.turning => GachaCue.turning,
  GachaPhase.heat => GachaCue.heat,
  GachaPhase.capsule => GachaCue.drop,
  GachaPhase.confirmed => GachaCue.fanfare,
  GachaPhase.missed => GachaCue.miss,
};

/// [phase]に入ったときに打つ振動の長さ(ミリ秒)。振動しない段はnull。
///
/// 確定は「当たった」と手で分かるよう長く1回。ハズレは短く1回だけにして、
/// 当たりと手触りで区別できるようにする。
int? gachaVibrationMillisFor(GachaPhase phase) => switch (phase) {
  GachaPhase.confirmed => 700,
  GachaPhase.missed => 120,
  GachaPhase.turning || GachaPhase.heat || GachaPhase.capsule => null,
};

/// ガチャの音と振動を出す口。テストでは差し替える。
abstract interface class GachaFeedback {
  /// [cue]を鳴らす。鳴っている別の音は止める(飛ばしたときに前の段の音が
  /// 残らないように)。
  Future<void> play(GachaCue cue);

  /// 鳴っている音をすべて止める。
  Future<void> stop();

  /// [durationMillis]ミリ秒振動させる。振動できない端末では何もしない。
  Future<void> vibrate(int durationMillis);
}

/// 端末で実際に鳴らす[GachaFeedback]。
///
/// **メディアの音量で鳴らす**(通知の音量・チャンネルは使わない)。隠れている
/// 間の通知音は今まで通りOFFのまま(`local_notifications.dart`)。ほかの
/// アプリの音楽は止めず、重ねて鳴らす。
class AudioGachaFeedback implements GachaFeedback {
  final _players = <GachaCue, AudioPlayer>{};

  static final AudioContext _context = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  // 再生と停止は前の操作が終わってから順に行う。飛ばしたとき、前の段の
  // 再生準備が後から終わって次の段の音に重なるのを防ぐ。
  Future<void> _last = Future.value();

  Future<void> _enqueue(Future<void> Function() action) =>
      _last = _last.then((_) => action()).catchError((Object e) {
        // 音が出ないだけで演出は進められるので、止めずにログに落とす。
        debugPrint('[GachaFeedback] 音を鳴らせなかった: $e');
      });

  @override
  Future<void> play(GachaCue cue) => _enqueue(() async {
    await _stopAll();
    final player = _players[cue] ??= AudioPlayer();
    await player.play(
      AssetSource('sounds/gacha/${cue.fileName}'),
      ctx: _context,
      mode: PlayerMode.lowLatency,
    );
  });

  @override
  Future<void> stop() => _enqueue(_stopAll);

  Future<void> _stopAll() async {
    for (final player in _players.values) {
      await player.stop();
    }
  }

  @override
  Future<void> vibrate(int durationMillis) async {
    try {
      if (!await Vibration.hasVibrator()) return;
      await Vibration.vibrate(duration: durationMillis);
    } on Object catch (e) {
      debugPrint('[GachaFeedback] 振動に失敗: $e');
    }
  }

  /// 持っているプレイヤーを解放する。
  Future<void> dispose() async {
    await _last;
    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();
  }
}

/// ガチャの音と振動を出す口。テストでは偽物に差し替える。
final gachaFeedbackProvider = Provider<GachaFeedback>((ref) {
  final feedback = AudioGachaFeedback();
  ref.onDispose(() => unawaited(feedback.dispose()));
  return feedback;
});
