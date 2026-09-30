import 'package:flutter/material.dart';
import 'package:kakureru/features/mission/mission_rules.dart';
import 'package:kakureru/features/mission/view/mission_palette.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/repository/proximity_calculator.dart';

/// 「鬼に近づけ」の間だけ、手がかりカードの上に大きく出す「Wi-Fi の重なり」
/// (モック5)。
///
/// 判定は既存のもの(`wifiProximityLevelsProvider`)をそのまま使い、ここでは
/// その結果と、判定に使っている数値を並べるだけ。
class WifiOverlapPanel extends StatelessWidget {
  /// [level]は選んでいる鬼との判定。まだ無ければnull。
  const WifiOverlapPanel({
    super.key,
    required this.demonName,
    required this.level,
    required this.metrics,
  });

  /// 選んでいる鬼の名前。
  final String demonName;

  /// 選んでいる鬼との判定。
  final ProximityLevel? level;

  /// 判定に使っている数値。スキャンがまだ無ければnull。
  final WifiOverlapMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final reacting = level == ProximityLevel.close;
    final m = metrics;
    final median = m?.medianDiffDbm;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gameBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gameBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi, size: 15, color: gameMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$demonName との Wi-Fi の重なり',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: gameMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StateBox(
                  title: reacting ? '反応あり' : '反応なし',
                  caption: 'いま',
                  highlighted: false,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 18, color: missionDeep),
              ),
              const Expanded(
                child: _StateBox(
                  title: '反応あり',
                  caption: 'これで達成',
                  highlighted: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MetricRow(
            label: '同じアクセスポイント',
            value: m == null ? '--' : '${m.commonCount} / ${m.selfCount} 個',
          ),
          const SizedBox(height: 6),
          _MetricRow(
            label: '電波の差（中央値）',
            value: median == null ? '--' : '${median.round()} dB',
          ),
          const SizedBox(height: 6),
          const _MetricRow(
            label: 'あり と出るめやす',
            value: '${ProximityThresholds.rssiDiffCloseThresholdDbm} dB 以下',
            emphasized: false,
          ),
        ],
      ),
    );
  }
}

class _StateBox extends StatelessWidget {
  const _StateBox({
    required this.title,
    required this.caption,
    required this.highlighted,
  });

  final String title;
  final String caption;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? missionSoft : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? missionAccent : gameBorder,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: highlighted ? missionInk : gameInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: TextStyle(
              fontSize: 10,
              color: highlighted ? missionInk : gameMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.emphasized = true,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: gameMuted),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
            color: emphasized ? gameInk : gameMuted,
          ),
        ),
      ],
    );
  }
}
