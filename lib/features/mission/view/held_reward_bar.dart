import 'package:flutter/material.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/view/mission_palette.dart';
import 'package:kakureru/features/mission/view/reward_page.dart';

/// 持っていてまだ使っていないごほうびの帯。「つかう」を押すとその場で
/// 効き始める(`MissionRepository.useHeldReward`)。逃走者の地図の上に出す。
class HeldRewardBar extends StatelessWidget {
  /// [onUse]がnullなら「つかう」を押せない([disabledReason]を出す)。
  const HeldRewardBar({
    super.key,
    required this.type,
    required this.onUse,
    this.disabledReason,
  });

  /// 持っているごほうび。
  final RewardType type;

  /// 「つかう」を押したとき。nullなら押せない。
  final VoidCallback? onUse;

  /// 押せない理由(例:「いま効いている」)。押せるときは出さない。
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final durationLabel = type.durationLabel;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: missionSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        children: [
          Icon(rewardIcon(type), size: 18, color: missionInk),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  durationLabel == null
                      ? type.title
                      : '${type.title}($durationLabel)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: missionInk,
                  ),
                ),
                Text(
                  onUse == null && disabledReason != null
                      ? disabledReason!
                      : '持っている。好きなときに使える',
                  style: const TextStyle(fontSize: 11, color: missionInk),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 44px以上の押せる大きさにする(外で走りながら押すため)。
          SizedBox(
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                // テーマの最小サイズは幅が無限(Size.fromHeight)で、Rowの中では
                // レイアウトが失敗して画面が白くなる。幅は0から始める。
                minimumSize: const Size(0, 44),
                backgroundColor: missionAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onUse,
              child: const Text(
                'つかう',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
