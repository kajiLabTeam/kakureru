import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/catch_photo.dart';
import 'package:kakureru/features/room/model/photo_capture_state.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_photo.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/photo_gallery_page.dart';
import 'package:kakureru/features/room/view_model/photo_capture_controller.dart';

void main() {
  // releasedAt=0, photoIntervalSec=300 -> 撮影スケジュールの基準は300000ms。
  // スロット0は[300000, 600000)、いまはスロット2(900000ms)にいるので
  // スロット0は過去のスロットになる。
  const startedAt = 300000;
  const nowMillis = 900000;

  const room = Room(
    id: 'room1',
    roomCode: 'ABCD',
    hostUserId: 'other',
    status: RoomStatus.playing,
    createdAt: 0,
    releasedAt: 0,
    setting: RoomSetting(),
    users: [
      RoomUser(id: 'me', displayName: '自分'),
      RoomUser(id: 'other', displayName: '相手'),
    ],
  );

  final photoCapture = PhotoCaptureController(
    state: const PhotoCaptureState(),
    capture: () async {},
    resend: () async {},
  );

  Future<void> pump(
    WidgetTester tester, {
    required List<RoomPhoto> photos,
    required Set<int> skippedSlots,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoGalleryPage(
            roomId: 'room1',
            room: room,
            myUid: 'me',
            photos: photos,
            catchPhotos: const <CatchPhoto>[],
            nowMillis: nowMillis,
            photoCapture: photoCapture,
            skippedSlots: skippedSlots,
          ),
        ),
      ),
    );
  }

  const othersPhotoInSlot0 = RoomPhoto(
    id: 'p1',
    uid: 'other',
    takenAt: startedAt + 100000,
  );

  testWidgets('まぬがれたスロットは自分の枠に「まぬがれました」と出て、'
      'みんなの写真も見られる', (tester) async {
    await pump(tester, photos: [othersPhotoInSlot0], skippedSlots: {0});

    expect(find.text('まぬがれました'), findsOneWidget);
    expect(find.text('撮り逃しました'), findsNothing);
  });

  testWidgets('まぬがれていないスロットで撮っていなければ、'
      '撮り逃し扱いのままぼかされる', (tester) async {
    await pump(tester, photos: [othersPhotoInSlot0], skippedSlots: const {});

    expect(find.text('まぬがれました'), findsNothing);
    expect(find.text('撮り逃しました'), findsOneWidget);
  });

  testWidgets('誰も撮っていないスロットでも、まぬがれていれば'
      '自分の枠だけは一覧に出る', (tester) async {
    await pump(tester, photos: const [], skippedSlots: {0});

    expect(find.text('まぬがれました'), findsOneWidget);
  });

  testWidgets('そのスロットで自分も実際に撮っていれば、'
      '「まぬがれました」枠は二重に出ない', (tester) async {
    const myPhotoInSlot0 = RoomPhoto(
      id: 'p2',
      uid: 'me',
      takenAt: startedAt + 50000,
    );
    await pump(
      tester,
      photos: [othersPhotoInSlot0, myPhotoInSlot0],
      skippedSlots: {0},
    );

    expect(find.text('まぬがれました'), findsNothing);
  });

  testWidgets('まだ始まっていない未来のスロットをまぬがれていても、'
      'その時間が来るまで一覧に出さない', (tester) async {
    // nowMillis=900000はスロット2。次に引いた直後は current+1(スロット3)
    // を飛ばすスロットとして渡しうる(footPhotoSlotToSkip参照)。
    await pump(tester, photos: const [], skippedSlots: {3});

    expect(find.text('まぬがれました'), findsNothing);
  });
}
