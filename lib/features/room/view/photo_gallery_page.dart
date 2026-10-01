import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kakureru/features/room/clock_time_format.dart';
import 'package:kakureru/features/room/model/catch_photo.dart';
import 'package:kakureru/features/room/model/photo_slot.dart';
import 'package:kakureru/features/room/model/photo_tile_visibility.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_photo.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/photo_capture_config.dart';
import 'package:kakureru/features/room/photo_gallery_section.dart';
import 'package:kakureru/features/room/photo_taken_notifications.dart';
import 'package:kakureru/features/room/user_color.dart';
import 'package:kakureru/features/room/view/game/catch_photo_section.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/room/view/game/photo_capture_banner.dart';
import 'package:kakureru/features/room/view/game/photo_tile.dart';
import 'package:kakureru/features/room/view/photo_viewer_page.dart';
import 'package:kakureru/features/room/view_model/photo_capture_controller.dart';

/// 足元写真の一覧。地図ページ(GamePage本体)は変更せず、`PageView`のもう一方の
/// ページとしてこれを表示する。
///
/// [room]・[myUid]・[photoCapture]は既にGamePage側で解決済みのため、
/// このウィジェット自身はRiverpodを読まずパラメータで受け取る
/// (AsyncValue.whenの二重管理を避けるため)。[photos]だけは
/// `photosStreamProvider`由来のストリーム結果をそのまま渡す。
///
/// 一番上に「捕まえた瞬間」(全員が見られる)、その下に「足元の写真」
/// (撮った人だけ見られる)を並べる(issue #140)。[catchPhotos]は
/// `catchPhotosForGallery`で絞り込み済みのもの。
class PhotoGalleryPage extends StatelessWidget {
  const PhotoGalleryPage({
    super.key,
    required this.roomId,
    required this.room,
    required this.myUid,
    required this.photos,
    required this.catchPhotos,
    required this.nowMillis,
    required this.photoCapture,
    required this.skippedSlots,
  });

  final String roomId;
  final Room room;
  final String? myUid;
  final List<RoomPhoto> photos;
  final List<CatchPhoto> catchPhotos;
  final int nowMillis;
  final PhotoCaptureController photoCapture;

  /// 「足元写真を1回まぬがれる」で自分が撮影を免除したスロット番号
  /// (`skippedFootPhotoSlots`)。撮った扱いにして閲覧できるようにし、
  /// 一覧では自分の枠に「まぬがれました」と出す(issue #157)。
  final Set<int> skippedSlots;

  @override
  Widget build(BuildContext context) {
    final myRole = roleOf(room.users, myUid);
    final viewerIsDemon = myRole == UserRole.demon;
    final showBanner =
        isPhotoFeatureConfigured &&
        takesFootPhotos(myRole) &&
        (photoCapture.state.isDue || photoCapture.state.pendingBytes != null);

    // 画面の上から順に、撮影バナー・捕まえた瞬間・足元の写真の見出しまでは
    // どの状態でも同じ。足元の写真の中身だけが状態で変わる。
    List<Widget> withHeader(List<Widget> footPhotos) => [
      if (showBanner)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _CaptureBannerCard(photoCapture: photoCapture),
        ),
      CatchPhotoSection(
        roomId: roomId,
        users: room.users,
        catchPhotos: catchPhotos,
      ),
      const SizedBox(height: 24),
      const GallerySectionHeader(title: '足元の写真', note: '撮った人だけ見られます'),
      const SizedBox(height: 12),
      ...footPhotos,
    ];

    // 撮影スロットの基準。鬼の放出から1間隔後が1回目(通知と同じ基準)。
    final startedAt = photoScheduleStartMillis(
      releasedAt: room.releasedAt,
      intervalSec: room.setting.photoIntervalSec,
    );
    final intervalSec = room.setting.photoIntervalSec;
    final photoSections = startedAt == null
        ? const <PhotoGallerySection>[]
        : buildPhotoGallerySections(
            photos: photos,
            startedAt: startedAt,
            intervalSec: intervalSec,
          );

    // まぬがれたスロットは、誰も写真を撮っていなくても(=セクションが
    // 無くても)自分の「まぬがれました」枠だけは見せる。
    final sectionSlots = {for (final s in photoSections) s.slotIndex};
    final sections =
        [
          ...photoSections,
          for (final slot in skippedSlots)
            if (!sectionSlots.contains(slot))
              PhotoGallerySection(slotIndex: slot, photos: const []),
        ]..sort((a, b) => b.slotIndex.compareTo(a.slotIndex));

    if (startedAt == null || sections.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: withHeader([_GalleryGuide(intervalSec: intervalSec)]),
      );
    }

    final currentSlot = currentPhotoSlotIndex(
      startedAt: startedAt,
      nowMillis: nowMillis,
      intervalSec: intervalSec,
    );

    Widget buildSection(PhotoGallerySection section) {
      final isCurrentSlot = section.slotIndex == currentSlot;
      final viewerSkippedSlot = skippedSlots.contains(section.slotIndex);
      final viewerCapturedInSlot =
          myUid != null &&
          (section.photos.any((p) => p.uid == myUid) || viewerSkippedSlot);
      // 撮った扱いにはなるが、本物の写真は無い(撮っていないため)ので
      // 自分の写真が無ければ専用の「まぬがれました」枠を1件足す。
      final showSkippedTile =
          viewerSkippedSlot &&
          myUid != null &&
          !section.photos.any((p) => p.uid == myUid);
      final visibility = photoTileVisibilityOf(
        viewerIsDemon: viewerIsDemon,
        viewerCapturedInSlot: viewerCapturedInSlot,
        isCurrentSlot: isCurrentSlot,
      );
      final remainingSec = isCurrentSlot
          ? ((photoSlotEndMillis(
                          startedAt: startedAt,
                          slotIndex: section.slotIndex,
                          intervalSec: intervalSec,
                        ) -
                        nowMillis) /
                    1000)
                .ceil()
          : 0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: formatClockTime(
                photoSlotStartMillis(
                  startedAt: startedAt,
                  slotIndex: section.slotIndex,
                  intervalSec: intervalSec,
                ),
              ),
              subtitle: photoGallerySectionSubtitle(
                isCurrentSlot: isCurrentSlot,
                photoCount: section.photos.length,
                remainingSec: remainingSec,
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: section.photos.length + (showSkippedTile ? 1 : 0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, photoIndex) {
                if (photoIndex >= section.photos.length) {
                  final me = findUser(room.users, myUid!);
                  return SkippedPhotoTile(
                    personColor: userColorOf(myUid!),
                    personName: me == null || me.displayName.isEmpty
                        ? '???'
                        : me.displayName,
                    personIsDemon: me?.role == UserRole.demon,
                  );
                }
                final photo = section.photos[photoIndex];
                final person = findUser(room.users, photo.uid);
                return PhotoTile(
                  roomId: roomId,
                  photo: photo,
                  visibility: visibility,
                  personColor: userColorOf(photo.uid),
                  personName: person == null || person.displayName.isEmpty
                      ? '???'
                      : person.displayName,
                  personIsDemon: person?.role == UserRole.demon,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PhotoViewerPage(
                          roomId: roomId,
                          users: room.users,
                          photos: section.photos,
                          initialIndex: photoIndex,
                          slotStartMillis: photoSlotStartMillis(
                            startedAt: startedAt,
                            slotIndex: section.slotIndex,
                            intervalSec: intervalSec,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: withHeader([for (final s in sections) buildSection(s)]),
    );
  }
}

class _CaptureBannerCard extends StatelessWidget {
  const _CaptureBannerCard({required this.photoCapture});

  final PhotoCaptureController photoCapture;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: PhotoCaptureBanner(
        state: photoCapture.state,
        onCapture: () => unawaited(photoCapture.capture()),
        onResend: () => unawaited(photoCapture.resend()),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class _GalleryGuide extends StatelessWidget {
  const _GalleryGuide({required this.intervalSec});

  final int intervalSec;

  @override
  Widget build(BuildContext context) {
    final intervalMinutes = intervalSec ~/ 60;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(
        '鬼が放たれてから$intervalMinutes分ごとに足元の写真を撮ってください',
        style: const TextStyle(color: Colors.black54),
      ),
    );
  }
}
