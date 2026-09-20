import 'package:flutter/material.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/core/utils/avatar_initial.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';

/// 対象役割の相手を選ぶチップ一覧(UI改修モック2a-03
/// 「逃走者を選んで詳細を見る」)。タップで詳細カードに出す
/// 相手を切り替えられる。選択中の相手は本人の役割色の枠+薄い背景で
/// 強調し、Wi-Fi判定が「検知なし」の相手は薄く表示して目立たなくする。
class OpponentSelectorChips extends StatelessWidget {
  /// すべての引数はGamePageが計算して渡す(このウィジェットはproviderを
  /// 一切読まない)。
  const OpponentSelectorChips({
    super.key,
    required this.roster,
    required this.entries,
    required this.selectedUid,
    required this.onSelect,
  });

  /// チップに並べる相手(自分と逆の役割で、いま見えている人だけ)。
  final List<RoomUser> roster;

  /// 各チップにWi-Fiの3段階判定を出すための一覧。
  final List<WifiProximityEntry> entries;

  /// 選択中の相手のuid。未選択ならnull。
  final String? selectedUid;

  /// チップがタップされたときに、そのuidを返す。
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < roster.length; i++) ...[
          Expanded(child: _buildChip(roster[i])),
          if (i != roster.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _buildChip(RoomUser user) {
    final level = levelFor(entries, user.id);
    final color = colorForRole(user.role);
    final isSelected = user.id == selectedUid;
    final isNotDetected = level == null || level == ProximityLevel.notDetected;

    return Opacity(
      opacity: isNotDetected ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: () => onSelect(user.id),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10),
            color: isSelected ? color.withValues(alpha: 0.07) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color,
                child: Text(
                  avatarInitial(user.displayName),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                user.displayName,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isSelected ? appInk : appMuted,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                _levelLabel(level),
                style: TextStyle(fontSize: 10, color: _levelColor(level)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _levelLabel(ProximityLevel? level) {
    switch (level) {
      case ProximityLevel.close:
        return '近い';
      case ProximityLevel.far:
        return '遠い';
      case ProximityLevel.notDetected:
      case null:
        return '検知なし';
    }
  }

  /// 近接度に応じた文字色。「近い」だけ強調色(赤)にし、それ以外は
  /// 目立たないグレーにする(UI改修モックの強弱付けに合わせる)。
  Color _levelColor(ProximityLevel? level) {
    return level == ProximityLevel.close
        ? const Color(0xFFE5484D)
        : const Color(0xFFAAAAAA);
  }
}
