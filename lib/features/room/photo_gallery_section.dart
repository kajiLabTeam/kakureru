import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kakureru/features/room/model/photo_slot.dart';
import 'package:kakureru/features/room/model/room_photo.dart';

part 'photo_gallery_section.freezed.dart';

/// 写真一覧の1スロットぶん(見出し+写真一覧)。
///
/// [photos]は同じスロットに属する写真(新しい順)のみを持つ。可視性
/// (`PhotoTileVisibility`)はスロット内の全写真で共通のため、ここでは
/// 持たず呼び出し側([visiblePhotosOf]、および一覧画面側)で都度求める。
@freezed
abstract class PhotoGallerySection with _$PhotoGallerySection {
  const factory PhotoGallerySection({
    required int slotIndex,
    required List<RoomPhoto> photos,
  }) = _PhotoGallerySection;
}

/// [photos]をスロットごとにまとめ、新しいスロットが先頭に来るよう並べる。
///
/// 各スロット内も撮影時刻の新しい順にする。写真が1枚も無いスロットは
/// セクションを作らない(「写真が1枚も無い時間帯のセクションは作らない」)。
List<PhotoGallerySection> buildPhotoGallerySections({
  required List<RoomPhoto> photos,
  required int startedAt,
  required int intervalSec,
}) {
  final bySlot = <int, List<RoomPhoto>>{};
  for (final photo in photos) {
    final slotIndex = photoSlotIndexOf(
      takenAt: photo.takenAt,
      startedAt: startedAt,
      intervalSec: intervalSec,
    );
    bySlot.putIfAbsent(slotIndex, () => []).add(photo);
  }

  final slotIndices = bySlot.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final slotIndex in slotIndices)
      PhotoGallerySection(
        slotIndex: slotIndex,
        photos: bySlot[slotIndex]!
          ..sort((a, b) => b.takenAt.compareTo(a.takenAt)),
      ),
  ];
}

/// セクション見出しの右側に出す補足文言。
///
/// 現在のスロットなら「つぎの撮影まで M:SS」、過去のスロットなら
/// 「N人ぶん」(そのスロットで写真を撮った人数=[photoCount])。
String photoGallerySectionSubtitle({
  required bool isCurrentSlot,
  required int photoCount,
  required int remainingSec,
}) {
  if (isCurrentSlot) {
    final clamped = remainingSec < 0 ? 0 : remainingSec;
    final minutes = clamped ~/ 60;
    final seconds = clamped % 60;
    final paddedSeconds = seconds.toString().padLeft(2, '0');
    return 'つぎの撮影まで $minutes:$paddedSeconds';
  }
  return '$photoCount人ぶん';
}

/// [photos]のうち、[myUid]の視点で「見られる」ものだけを返す。
///
/// - 鬼は常に全て見られる。
/// - 逃走者は、自分がそのスロットで撮っていれば同スロットの他人の写真も
///   見られる。撮っていないスロットの写真は(過去・現在どちらも)見えない。
///
/// [photoTileVisibilityOf]と同じ判定基準を、写真一覧全体に対してまとめて
/// 適用するためのヘルパー(スロット内の可視性は写真によらず一定なので、
/// スロットごとに1回だけ「自分がそのスロットで撮ったか」を求めれば足りる)。
List<RoomPhoto> visiblePhotosOf({
  required List<RoomPhoto> photos,
  required String? myUid,
  required bool viewerIsDemon,
  required int startedAt,
  required int intervalSec,
  required int nowMillis,
}) {
  if (viewerIsDemon) return photos;

  final capturedSlots = <int>{
    for (final photo in photos)
      if (photo.uid == myUid)
        photoSlotIndexOf(
          takenAt: photo.takenAt,
          startedAt: startedAt,
          intervalSec: intervalSec,
        ),
  };

  return photos.where((photo) {
    final slotIndex = photoSlotIndexOf(
      takenAt: photo.takenAt,
      startedAt: startedAt,
      intervalSec: intervalSec,
    );
    return capturedSlots.contains(slotIndex);
  }).toList();
}
