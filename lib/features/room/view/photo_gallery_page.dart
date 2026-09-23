import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kakureru/features/room/clock_time_format.dart';
import 'package:kakureru/features/room/model/photo_slot.dart';
import 'package:kakureru/features/room/model/photo_tile_visibility.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_photo.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/photo_capture_config.dart';
import 'package:kakureru/features/room/photo_gallery_section.dart';
import 'package:kakureru/features/room/user_color.dart';
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
class PhotoGalleryPage extends StatelessWidget {
  const PhotoGalleryPage({
    super.key,
    required this.roomId,
    required this.room,
    required this.myUid,
    required this.photos,
    required this.nowMillis,
    required this.photoCapture,
  });

  final String roomId;
  final Room room;
  final String? myUid;
  final List<RoomPhoto> photos;
  final int nowMillis;
  final PhotoCaptureController photoCapture;

  @override
  Widget build(BuildContext context) {
    final myRole = roleOf(room.users, myUid);
    final viewerIsDemon = myRole == UserRole.demon;
    final showBanner =
        isPhotoFeatureConfigured &&
        myRole == UserRole.fugitive &&
        (photoCapture.state.isDue || photoCapture.state.pendingBytes != null);

    final startedAt = room.startedAt;
    if (startedAt == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (showBanner) _CaptureBannerCard(photoCapture: photoCapture),
          const _GalleryGuide(),
        ],
      );
    }

    final intervalSec = room.setting.photoIntervalSec;
    final sections = buildPhotoGallerySections(
      photos: photos,
      startedAt: startedAt,
      intervalSec: intervalSec,
    );

    if (sections.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (showBanner) _CaptureBannerCard(photoCapture: photoCapture),
          const _GalleryGuide(),
        ],
      );
    }

    final currentSlot = currentPhotoSlotIndex(
      startedAt: startedAt,
      nowMillis: nowMillis,
      intervalSec: intervalSec,
    );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sections.length + (showBanner ? 1 : 0),
      itemBuilder: (context, index) {
        if (showBanner && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _CaptureBannerCard(photoCapture: photoCapture),
          );
        }

        final section = sections[index - (showBanner ? 1 : 0)];
        final isCurrentSlot = section.slotIndex == currentSlot;
        final viewerCapturedInSlot =
            myUid != null && section.photos.any((p) => p.uid == myUid);
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
                itemCount: section.photos.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1,
                    ),
                itemBuilder: (context, photoIndex) {
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
      },
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
  const _GalleryGuide();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Text(
        'ゲームが始まると、ここに足元の写真が並びます',
        style: TextStyle(color: Colors.black54),
      ),
    );
  }
}
