import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/view/mission_card.dart';
import 'package:kakureru/features/mission/view/mission_palette.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';

/// ごほうびを引いたあとに出す画面(モック4)。
///
/// 引いた瞬間に効果は出ている(持ち歩かせない)。この画面は知らせるだけで、
/// 閉じても効果は変わらない。
class RewardPage extends StatelessWidget {
  /// [reward]は引いたごほうび。
  const RewardPage({super.key, required this.reward});

  /// 引いたごほうび。
  final RewardType reward;

  /// `GamePage`の上に重ねて開く。`GamePage`は破棄しないので、位置情報の
  /// 送信は止まらない。
  static Future<void> show(BuildContext context, RewardType reward) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RewardPage(reward: reward)),
      );

  @override
  Widget build(BuildContext context) {
    final others = RewardType.values.where((r) => r != reward).toList();
    return Scaffold(
      backgroundColor: gameBackground,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: missionSoft,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
              child: const Column(
                children: [
                  Text(
                    'ミッション達成',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: missionInk,
                    ),
                  ),
                  SizedBox(height: 10),
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Color(0x33C98A1E),
                    child: CircleAvatar(
                      radius: 33,
                      backgroundColor: missionAccent,
                      child: Icon(
                        Icons.card_giftcard,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'ごほうびをひいた！',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: gameInk,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                children: [
                  RewardCard(reward: reward),
                  const SizedBox(height: 16),
                  const Text(
                    'ほかに入っているごほうび',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: gameMuted,
                    ),
                  ),
                  const SizedBox(height: 9),
                  for (final other in others) ...[
                    _OtherRewardRow(reward: other),
                    const SizedBox(height: 9),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: fugitiveDeep,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () =>
                          unawaited(Navigator.of(context).maybePop()),
                      child: const Text('地図にもどる'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reward.duration > Duration.zero
                        ? '残り時間は地図の上の帯にも出る'
                        : '次の撮影タイムは知らせが来ない',
                    style: const TextStyle(fontSize: 11, color: gameMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 引いたごほうびのカード。「鬼をジャマする／自分がトクする」と効いている時間を書く。
class RewardCard extends StatelessWidget {
  /// [reward]は引いたごほうび。
  const RewardCard({super.key, required this.reward});

  /// 引いたごほうび。
  final RewardType reward;

  @override
  Widget build(BuildContext context) {
    final seconds = reward.duration.inSeconds;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: missionAccent, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RewardTargetTag(target: reward.target, fontSize: 11),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: missionSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  seconds > 0 ? '$seconds秒' : '1回',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: missionInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _RewardIcon(reward: reward, size: 44),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: gameInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      reward.description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: gameMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OtherRewardRow extends StatelessWidget {
  const _OtherRewardRow({required this.reward});

  final RewardType reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gameBorder),
      ),
      child: Row(
        children: [
          _RewardIcon(reward: reward, size: 38),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: gameInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reward.description,
                  style: const TextStyle(fontSize: 11, color: gameMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          RewardTargetTag(target: reward.target),
        ],
      ),
    );
  }
}

/// ごほうびのアイコン。
IconData rewardIcon(RewardType reward) => switch (reward) {
  RewardType.blockClues => Icons.wifi_off,
  RewardType.bigDemonIcon => Icons.zoom_out_map,
  RewardType.skipFootPhoto => Icons.no_photography_outlined,
};

class _RewardIcon extends StatelessWidget {
  const _RewardIcon({required this.reward, required this.size});

  final RewardType reward;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDemon = reward.target == RewardTarget.demon;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDemon ? demonSoft : selfSoft,
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Icon(
        rewardIcon(reward),
        size: size * 0.5,
        color: isDemon ? demonDeep : const Color(0xFF2F5FC4),
      ),
    );
  }
}
