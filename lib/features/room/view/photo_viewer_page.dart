import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kakureru/features/room/clock_time_format.dart';
import 'package:kakureru/features/room/model/room_photo.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/user_color.dart';
import 'package:kakureru/features/room/view/game/downloaded_photo_image.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/room/view/game/photo_tile.dart'
    show demonBadgeColor;

/// 写真の全画面拡大表示。
///
/// [photos]は同じスロット(同じ可視性)の写真のみを渡すこと。「まえの人」
/// 「つぎの人」はこのリスト内だけを移動する。呼び出し側([PhotoGalleryPage])
/// が可視性を判定済みで、`visible`なタイルからしか遷移させないため、ここでは
/// 可視性の再判定は行わない。
class PhotoViewerPage extends HookWidget {
  const PhotoViewerPage({
    super.key,
    required this.roomId,
    required this.users,
    required this.photos,
    required this.initialIndex,
    required this.slotStartMillis,
  });

  final String roomId;
  final List<RoomUser> users;
  final List<RoomPhoto> photos;
  final int initialIndex;
  final int slotStartMillis;

  @override
  Widget build(BuildContext context) {
    final index = useState(initialIndex);
    final pageController = usePageController(initialPage: initialIndex);
    final photo = photos[index.value];
    final person = findUser(users, photo.uid);
    final personColor = userColorOf(photo.uid);
    final personName = person == null || person.displayName.isEmpty
        ? '???'
        : person.displayName;
    final personIsDemon = person?.role == UserRole.demon;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  '${formatClockTime(slotStartMillis)}の写真',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: photos.length,
                onPageChanged: (i) => index.value = i,
                itemBuilder: (context, i) {
                  return InteractiveViewer(
                    child: Center(
                      child: DownloadedPhotoImage(
                        roomId: roomId,
                        photoId: photos[i].id,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: personColor, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      personName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (personIsDemon)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: demonBadgeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '鬼',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    formatClockTime(photo.takenAt),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: index.value > 0
                        ? () => pageController.previousPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          )
                        : null,
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    label: const Text(
                      'まえの人',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: index.value < photos.length - 1
                        ? () => pageController.nextPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          )
                        : null,
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'つぎの人',
                      style: TextStyle(color: Colors.white),
                    ),
                    iconAlignment: IconAlignment.end,
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
