import 'package:flutter/material.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';

/// タブ帯の高さ(モックの46px)。
const double mapPhotoTabBarHeight = 46;

/// 地図タブ/写真タブを切り替えるセグメントコントロール(GamePage用)。
///
/// [selectedIndex]は0=地図、1=写真。選択状態と`PageView`との連動は
/// 呼び出し側(GamePage)が持ち、このウィジェットは見た目とタップ通知だけを
/// 担う(widgetテストで単体確認できるようにするため。GameHeaderBarと同じ方針)。
class MapPhotoTabBar extends StatelessWidget {
  const MapPhotoTabBar({
    required this.selectedIndex,
    required this.onSelect,
    this.hasNewPhotos = false,
    super.key,
  });

  /// 現在選択中のページ番号(0=地図、1=写真)。
  final int selectedIndex;

  /// タブがタップされたときに呼ばれる(引数は選択されたページ番号)。
  final ValueChanged<int> onSelect;

  /// まだ見ていない写真があるか。trueなら「写真」の横に赤い点を出す。
  final bool hasNewPhotos;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: mapPhotoTabBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: gameBorder)),
      ),
      child: Row(
        children: [
          _Segment(
            icon: Icons.map_outlined,
            label: '地図',
            selected: selectedIndex == 0,
            onTap: () => onSelect(0),
          ),
          const SizedBox(width: 6),
          _Segment(
            icon: Icons.photo_camera_outlined,
            label: '写真',
            selected: selectedIndex == 1,
            showBadge: hasNewPhotos,
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
    this.showBadge = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool showBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? gameInk : gameMuted;
    return Expanded(
      // 見た目の丸は32dpだが、帯の高さ(46dp)いっぱいをタップ領域にして
      // 44dp以上を確保する。
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: mapPhotoTabBarHeight - 1,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 32,
              decoration: BoxDecoration(
                color: selected ? gameSelected : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                  if (showBadge) ...[
                    const SizedBox(width: 6),
                    Container(
                      key: const ValueKey('newPhotoBadge'),
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: gameNewBadge,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
