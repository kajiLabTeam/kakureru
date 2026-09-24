import 'package:flutter/material.dart';
import 'package:kakureru/core/theme/app_theme.dart';

/// 地図タブ/写真タブを切り替えるセグメントコントロール(GamePage用)。
///
/// [selectedIndex]は0=地図、1=写真。選択状態と`PageView`との連動は
/// 呼び出し側(GamePage)が持ち、このウィジェットは見た目とタップ通知だけを
/// 担う(widgetテストで単体確認できるようにするため。GameHeaderBarと同じ方針)。
class MapPhotoTabBar extends StatelessWidget {
  const MapPhotoTabBar({
    required this.selectedIndex,
    required this.onSelect,
    super.key,
  });

  /// 現在選択中のページ番号(0=地図、1=写真)。
  final int selectedIndex;

  /// タブがタップされたときに呼ばれる(引数は選択されたページ番号)。
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: appFaintBorder,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _Segment(
            icon: Icons.map_outlined,
            label: '地図',
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          _Segment(
            icon: Icons.photo_camera_outlined,
            label: '写真',
            selected: selectedIndex == 1,
            onTap: () => onSelect(1),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? appInk : appMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? appInk : appMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
