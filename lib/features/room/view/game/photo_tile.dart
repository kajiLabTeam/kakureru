import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kakureru/features/room/clock_time_format.dart';
import 'package:kakureru/features/room/model/photo_tile_visibility.dart';
import 'package:kakureru/features/room/model/room_photo.dart';
import 'package:kakureru/features/room/view/game/downloaded_photo_image.dart';

/// 「鬼」バッジの色。[role_theme.dart]の`_demonColor`と同じ値だが、あちらは
/// ファイル内限定の定数のため公開できず、ここで同じ値を持つ。
const demonBadgeColor = Color(0xFFE5484D);

/// 写真一覧グリッドのタイル1枚。
///
/// [visibility]が`visible`のときだけ実際にダウンロードする
/// (「見られない写真は絶対にダウンロードしない」)。それ以外はぼかし表示
/// にし、下地はその人の色ベースの単色プレースホルダーにする(実データは
/// 取得しないため、本物の写真をぼかしているわけではない)。
class PhotoTile extends HookWidget {
  const PhotoTile({
    super.key,
    required this.roomId,
    required this.photo,
    required this.visibility,
    required this.personColor,
    required this.personName,
    required this.personIsDemon,
    this.onTap,
  });

  final String roomId;
  final RoomPhoto photo;
  final PhotoTileVisibility visibility;
  final Color personColor;
  final String personName;
  final bool personIsDemon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GestureDetector(
        onTap: visibility == PhotoTileVisibility.visible ? onTap : null,
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              switch (visibility) {
                PhotoTileVisibility.visible => DownloadedPhotoImage(
                  roomId: roomId,
                  photoId: photo.id,
                ),
                PhotoTileVisibility.lockedCurrentSlot ||
                PhotoTileVisibility.missedPastSlot => _BlurredPlaceholder(
                  color: personColor,
                ),
              },
              Container(color: Colors.black.withValues(alpha: 0.26)),
              Center(
                child: Text(
                  formatClockTime(photo.takenAt),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (visibility == PhotoTileVisibility.lockedCurrentSlot)
                const _CenteredHint(icon: Icons.lock, label: '撮ると見られます'),
              if (visibility == PhotoTileVisibility.missedPastSlot)
                const _CenteredHint(icon: null, label: '撮り逃しました'),
              Positioned(
                left: 8,
                bottom: 8,
                right: 8,
                child: _PersonLabel(
                  color: personColor,
                  name: personName,
                  isDemon: personIsDemon,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.55),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) Icon(icon, color: Colors.white, size: 18),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PersonLabel extends StatelessWidget {
  const _PersonLabel({
    required this.color,
    required this.name,
    required this.isDemon,
  });

  final Color color;
  final String name;
  final bool isDemon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.favorite, color: color, size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (isDemon)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: demonBadgeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '鬼',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _BlurredPlaceholder extends StatelessWidget {
  const _BlurredPlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(color: color.withValues(alpha: 0.55)),
    );
  }
}
