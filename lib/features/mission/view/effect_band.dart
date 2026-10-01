import 'package:flutter/material.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/view/mission_palette.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';

/// 効果の残り時間(ミリ秒)を「0:18」の形にする。秒は切り上げ(0:00 の
/// まま効いている時間を作らないため)。
String formatEffectRemaining(int remainingMillis) {
  final totalSeconds = remainingMillis <= 0
      ? 0
      : (remainingMillis / 1000).ceil();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// 帯の文言。同じ効果でも、見る人の役割で言い方を変える
/// (鬼に「鬼の手がかりを止めている」と出すと、誰がやっているのか分からない)。
String effectBandText(RewardType type, {required UserRole? viewerRole}) {
  final isDemon = viewerRole == UserRole.demon;
  return switch (type) {
    RewardType.blockClues => isDemon ? '逃走者のごほうびで止められている' : '鬼の手がかりを止めている',
    RewardType.bigDemonIcon => isDemon ? '逃走者の地図で鬼が大きく出ている' : '鬼のアイコンを大きくしている',
    // 本人にだけ出す帯なので、鬼視点の文言は使われない。
    RewardType.enlargeSelfIcon => 'あなたのアイコンが大きくなっている',
    // 回数ものは帯に出さない(呼ばれない)が、switchを網羅するために置く。
    RewardType.skipFootPhoto => '足元写真を1回まぬがれる',
  };
}

/// 効果が効いているあいだ地図の上に出す細い帯(モック5)。
class EffectBand extends StatelessWidget {
  /// [remainingMillis]は `startedAt + durationMs` からサーバー時刻で求めた値。
  ///
  /// [drawerName]は引いた人の表示名。逃走者が見る帯にだけ渡し、誰が
  /// 止めているかを伝える(例:「みお のごほうび」)。鬼が見る帯には
  /// 絶対に渡さない(どこにいる逃走者か特定できてしまうため)。
  const EffectBand({
    super.key,
    required this.type,
    required this.viewerRole,
    required this.remainingMillis,
    this.drawerName,
  });

  /// 効いている効果。
  final RewardType type;

  /// 見ている人の役割。
  final UserRole? viewerRole;

  /// 残り時間(ミリ秒)。
  final int remainingMillis;

  /// 引いた人の表示名。鬼視点では渡さないこと。
  final String? drawerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: double.infinity,
      color: missionSoft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type == RewardType.blockClues ? Icons.wifi_off : Icons.zoom_out_map,
            size: 15,
            color: missionInk,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              drawerName != null
                  ? '$drawerName のごほうび：'
                        '${effectBandText(type, viewerRole: viewerRole)}'
                  : effectBandText(type, viewerRole: viewerRole),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: missionInk,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: missionDeep,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'のこり ${formatEffectRemaining(remainingMillis)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `block_clues` が効いているあいだ、鬼の端末で手がかりカード(Wi-Fiと気圧)
/// の代わりに出すカード。
class ClueBlockedCard extends StatelessWidget {
  /// [remainingMillis]は残り時間(ミリ秒)。
  const ClueBlockedCard({super.key, required this.remainingMillis});

  /// 残り時間(ミリ秒)。
  final int remainingMillis;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gameBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 28, color: missionDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '逃走者のごほうびで止められている（のこり '
                  '${formatEffectRemaining(remainingMillis)}）',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: gameInk,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '逃走者がごほうびを使った。そのあいだ Wi-Fi と気圧は見えない',
                  style: TextStyle(fontSize: 12, color: gameMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
