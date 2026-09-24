import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room_photo.dart';
import 'package:kakureru/features/room/photo_gallery_section.dart';

void main() {
  const startedAt = 1000000;
  const intervalSec = 300;
  const intervalMillis = intervalSec * 1000;

  RoomPhoto photo({
    required String id,
    required String uid,
    required int takenAt,
  }) {
    return RoomPhoto(id: id, uid: uid, takenAt: takenAt);
  }

  group('buildPhotoGallerySections', () {
    test('写真が無ければ空リストを返す', () {
      final sections = buildPhotoGallerySections(
        photos: const [],
        startedAt: startedAt,
        intervalSec: intervalSec,
      );
      expect(sections, isEmpty);
    });

    test('スロットごとにまとめ、新しいスロットが先頭に来る', () {
      final sections = buildPhotoGallerySections(
        photos: [
          photo(id: 'p0', uid: 'u1', takenAt: startedAt),
          photo(id: 'p1', uid: 'u2', takenAt: startedAt + intervalMillis),
        ],
        startedAt: startedAt,
        intervalSec: intervalSec,
      );

      expect(sections.map((s) => s.slotIndex).toList(), [1, 0]);
    });

    test('スロット内は撮影時刻の新しい順になる', () {
      final sections = buildPhotoGallerySections(
        photos: [
          photo(id: 'earlier', uid: 'u1', takenAt: startedAt),
          photo(id: 'later', uid: 'u2', takenAt: startedAt + 100),
        ],
        startedAt: startedAt,
        intervalSec: intervalSec,
      );

      expect(sections, hasLength(1));
      expect(sections.first.photos.map((p) => p.id).toList(), [
        'later',
        'earlier',
      ]);
    });

    test('写真が1枚も無いスロットのセクションは作らない', () {
      final sections = buildPhotoGallerySections(
        photos: [
          photo(id: 'p0', uid: 'u1', takenAt: startedAt + intervalMillis * 5),
        ],
        startedAt: startedAt,
        intervalSec: intervalSec,
      );

      expect(sections, hasLength(1));
      expect(sections.first.slotIndex, 5);
    });
  });

  group('photoGallerySectionSubtitle', () {
    test('現在のスロットは「つぎの撮影まで M:SS」', () {
      expect(
        photoGallerySectionSubtitle(
          isCurrentSlot: true,
          photoCount: 3,
          remainingSec: 65,
        ),
        'つぎの撮影まで 1:05',
      );
    });

    test('残り秒数が0未満でも0として表示する', () {
      expect(
        photoGallerySectionSubtitle(
          isCurrentSlot: true,
          photoCount: 0,
          remainingSec: -5,
        ),
        'つぎの撮影まで 0:00',
      );
    });

    test('過去のスロットは「N人ぶん」', () {
      expect(
        photoGallerySectionSubtitle(
          isCurrentSlot: false,
          photoCount: 4,
          remainingSec: 0,
        ),
        '4人ぶん',
      );
    });
  });

  group('visiblePhotosOf', () {
    final photos = [
      photo(id: 'mine-old', uid: 'me', takenAt: startedAt),
      photo(id: 'other-old', uid: 'other', takenAt: startedAt + 10),
      photo(
        id: 'other-uncaptured-slot',
        uid: 'other',
        takenAt: startedAt + intervalMillis,
      ),
    ];

    test('鬼には全ての写真が見える', () {
      final visible = visiblePhotosOf(
        photos: photos,
        myUid: 'demon',
        viewerIsDemon: true,
        startedAt: startedAt,
        intervalSec: intervalSec,
        nowMillis: startedAt + intervalMillis,
      );

      expect(visible.map((p) => p.id).toSet(), photos.map((p) => p.id).toSet());
    });

    test('逃走者は自分が撮ったスロットの他人の写真だけ見える', () {
      final visible = visiblePhotosOf(
        photos: photos,
        myUid: 'me',
        viewerIsDemon: false,
        startedAt: startedAt,
        intervalSec: intervalSec,
        nowMillis: startedAt + intervalMillis,
      );

      expect(visible.map((p) => p.id).toSet(), {'mine-old', 'other-old'});
    });

    test('撮っていないスロットの写真は見えない', () {
      final visible = visiblePhotosOf(
        photos: photos,
        myUid: 'someone-who-never-captured',
        viewerIsDemon: false,
        startedAt: startedAt,
        intervalSec: intervalSec,
        nowMillis: startedAt + intervalMillis,
      );

      expect(visible, isEmpty);
    });
  });
}
