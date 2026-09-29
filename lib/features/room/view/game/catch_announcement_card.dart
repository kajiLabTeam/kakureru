import 'package:flutter/material.dart';
import 'package:kakureru/features/room/view/game/catch_button_strip.dart';
import 'package:kakureru/features/room/view/game/downloaded_photo_image.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';

/// 取り消しの期限を過ぎた捕獲を全員に知らせる、地図の上のカード(issue #140)。
///
/// 写真が無ければサムネイルを省く。タップで写真タブを開く。
class CatchAnnouncementCard extends StatelessWidget {
  /// [photoId]は捕まえた瞬間の写真のID。まだ無ければnull。
  const CatchAnnouncementCard({
    super.key,
    required this.roomId,
    required this.message,
    required this.remainingFugitives,
    required this.photoId,
    required this.onTap,
  });

  /// ルームID。
  final String roomId;

  /// 「AがBを捕まえた」。
  final String message;

  /// 残っている逃走者の人数。
  final int remainingFugitives;

  /// サムネイルに出す写真。
  final String? photoId;

  /// タップしたとき(写真タブを開く)。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final id = photoId;
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: const Color(0x33000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: gameBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (id != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: DownloadedPhotoImage(roomId: roomId, photoId: id),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: gameInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '逃走者 のこり $remainingFugitives人',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: catchSurfaceColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'タップして写真を見る',
                      style: TextStyle(fontSize: 11, color: gameFaint),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: gameFaint),
            ],
          ),
        ),
      ),
    );
  }
}
