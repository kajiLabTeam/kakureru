import 'package:flutter/material.dart';
import 'package:kakureru/features/room/clock_time_format.dart';
import 'package:kakureru/features/room/model/catch_photo.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/catch_button_strip.dart';
import 'package:kakureru/features/room/view/game/downloaded_photo_image.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';

/// 捕まえた瞬間の写真のタイルの高さ(モックの186px)。
const double catchPhotoTileHeight = 186;

/// 「AがBを捕まえた」の文言に使う名前。見つからなければ「???」。
String catchPersonName(List<RoomUser> users, String? uid) {
  if (uid == null) return '???';
  final name = findUser(users, uid)?.displayName;
  return name == null || name.isEmpty ? '???' : name;
}

/// 写真タブ・結果画面の「捕まえた瞬間」のセクション(issue #140)。
///
/// 足元の写真と違い**全員が見られる**。見る人が撮ったかどうかで伏せたり
/// しない。[catchPhotos]は`catchPhotosForGallery`で絞り込み済みのものを渡す
/// (取り消しの期限を過ぎた捕獲の写真だけ・新しい順)。
class CatchPhotoSection extends StatelessWidget {
  /// 引数は呼び出し側(写真タブ・結果画面)が解決して渡す。
  const CatchPhotoSection({
    super.key,
    required this.roomId,
    required this.users,
    required this.catchPhotos,
  });

  /// ルームID(写真本体のダウンロードに使う)。
  final String roomId;

  /// 名前を引くための参加者一覧。
  final List<RoomUser> users;

  /// 並べる写真。
  final List<CatchPhoto> catchPhotos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GallerySectionHeader(title: '捕まえた瞬間', note: '全員が見られます'),
        const SizedBox(height: 8),
        if (catchPhotos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'まだありません',
              style: TextStyle(fontSize: 12, color: gameFaint),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: catchPhotos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: catchPhotoTileHeight,
            ),
            itemBuilder: (context, index) {
              final photo = catchPhotos[index];
              return CatchPhotoTile(
                roomId: roomId,
                photo: photo,
                demonName: catchPersonName(users, photo.demonUid),
                fugitiveName: catchPersonName(users, photo.fugitiveUid),
              );
            },
          ),
      ],
    );
  }
}

/// 写真タブのセクション見出し(左に題名、右に「誰が見られるか」)。
class GallerySectionHeader extends StatelessWidget {
  /// [note]は右端の小さな注記。
  const GallerySectionHeader({
    super.key,
    required this.title,
    required this.note,
  });

  /// 見出し。
  final String title;

  /// 右端の注記。
  final String note;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: gameInk,
          ),
        ),
        Text(note, style: const TextStyle(fontSize: 11, color: gameMuted)),
      ],
    );
  }
}

/// 捕まえた瞬間の写真1枚ぶんのタイル。左上に時刻、下に「AがBを捕まえた」。
class CatchPhotoTile extends StatelessWidget {
  /// 名前は呼び出し側で引いて渡す。
  const CatchPhotoTile({
    super.key,
    required this.roomId,
    required this.photo,
    required this.demonName,
    required this.fugitiveName,
  });

  /// ルームID。
  final String roomId;

  /// 写真のメタデータ。
  final CatchPhoto photo;

  /// 捕まえた鬼の名前。
  final String demonName;

  /// 捕まった人の名前。
  final String fugitiveName;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: const Color(0xFFE5E7EB),
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CatchPhotoViewerPage(
                roomId: roomId,
                photo: photo,
                caption: '$demonName が $fugitiveName を捕まえた',
              ),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DownloadedPhotoImage(roomId: roomId, photoId: photo.id),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x99000000)],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: catchSurfaceColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    formatClockTime(photo.takenAt),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  '$demonName が\n$fugitiveName を捕まえた',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 捕まえた瞬間の写真を1枚だけ全画面で見る画面。
///
/// 足元の写真のビューア(`PhotoViewerPage`)は撮影スロットや`RoomPhoto`に
/// 結びついているため使い回さず、拡大できるだけの簡素な画面にしている。
class CatchPhotoViewerPage extends StatelessWidget {
  /// [caption]は上部に出す「AがBを捕まえた」。
  const CatchPhotoViewerPage({
    super.key,
    required this.roomId,
    required this.photo,
    required this.caption,
  });

  /// ルームID。
  final String roomId;

  /// 写真のメタデータ。
  final CatchPhoto photo;

  /// 上部に出す説明。
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '$caption ${formatClockTime(photo.takenAt)}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: InteractiveViewer(
        child: Center(
          child: DownloadedPhotoImage(
            roomId: roomId,
            photoId: photo.id,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
