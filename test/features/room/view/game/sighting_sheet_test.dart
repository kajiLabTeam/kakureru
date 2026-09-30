import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/clock_time_format.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/model/sighting.dart';
import 'package:kakureru/features/room/repository/photo_repository.dart';
import 'package:kakureru/features/room/view/game/sighting_sheet.dart';

const _users = [
  RoomUser(id: 'me', displayName: 'わたし'),
  RoomUser(id: 'koki', displayName: 'こうき'),
  RoomUser(id: 'demon', displayName: 'おに', role: UserRole.demon),
];

const _takenAt = 1700000000000;

Future<void> _pump(
  WidgetTester tester, {
  List<Sighting> sightings = const [],
  UserRole? viewerRole = UserRole.fugitive,
  String? myUid = 'me',
  bool canTakePhoto = true,
  bool isBusy = false,
  String? errorMessage,
  VoidCallback? onTakePhoto,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SightingSheetView(
          roomId: 'room-1',
          sightings: sightings,
          users: _users,
          myUid: myUid,
          viewerRole: viewerRole,
          canTakePhoto: canTakePhoto,
          isBusy: isBusy,
          errorMessage: errorMessage,
          onTakePhoto: onTakePhoto ?? () {},
          onClose: () {},
        ),
      ),
    ),
  );
}

void main() {
  group('SightingSheetView', () {
    testWidgets('他人の写真は左、自分の写真は右に置く', (tester) async {
      await _pump(
        tester,
        sightings: const [
          Sighting(id: 'a', uid: 'koki', takenAt: _takenAt, place: '1号館の前'),
          Sighting(id: 'b', uid: 'me', takenAt: _takenAt + 60000),
        ],
      );

      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final other = tester.getCenter(
        find.byKey(const ValueKey('sighting-photo-a')),
      );
      final mine = tester.getCenter(
        find.byKey(const ValueKey('sighting-photo-b')),
      );
      expect(other.dx, lessThan(width / 2));
      expect(mine.dx, greaterThan(width / 2));
    });

    testWidgets('写真の上に名前・時刻・場所を出し、自分のものは「自分」と出す', (tester) async {
      await _pump(
        tester,
        sightings: const [
          Sighting(id: 'a', uid: 'koki', takenAt: _takenAt, place: '1号館の前'),
          Sighting(id: 'b', uid: 'me', takenAt: _takenAt),
        ],
      );

      final time = formatClockTime(_takenAt);
      expect(find.text('こうき ・ $time ・ 1号館の前'), findsOneWidget);
      expect(find.text('自分 ・ $time'), findsOneWidget);
    });

    testWidgets('新しい写真ほど下に並ぶ', (tester) async {
      await _pump(
        tester,
        sightings: const [
          Sighting(id: 'old', uid: 'koki', takenAt: _takenAt),
          Sighting(id: 'new', uid: 'koki', takenAt: _takenAt + 60000),
        ],
      );

      final oldY = tester
          .getCenter(find.byKey(const ValueKey('sighting-old')))
          .dy;
      final newY = tester
          .getCenter(find.byKey(const ValueKey('sighting-new')))
          .dy;
      expect(newY, greaterThan(oldY));
    });

    testWidgets('写真が無ければ「まだありません」', (tester) async {
      await _pump(tester);

      expect(find.text('まだありません'), findsOneWidget);
    });

    testWidgets('逃走者には「鬼の写真を撮る」を出し、押すと撮影を呼ぶ', (tester) async {
      var taken = 0;
      await _pump(tester, onTakePhoto: () => taken++);

      expect(find.text('鬼の写真を撮る'), findsOneWidget);
      await tester.tap(find.text('鬼の写真を撮る'));
      expect(taken, 1);
      // タップできる要素は44px以上。
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(44));
    });

    testWidgets('鬼には「鬼の写真を撮る」を出さないが、写真は見られる', (tester) async {
      await _pump(
        tester,
        viewerRole: UserRole.demon,
        myUid: 'demon',
        sightings: const [Sighting(id: 'a', uid: 'koki', takenAt: _takenAt)],
      );

      expect(find.text('鬼の写真を撮る'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byKey(const ValueKey('sighting-photo-a')), findsOneWidget);
    });

    testWidgets('役割が分からない間は撮るボタンを出さない', (tester) async {
      await _pump(tester, viewerRole: null);

      expect(find.text('鬼の写真を撮る'), findsNothing);
    });

    testWidgets('写真機能が使えない環境では押せない', (tester) async {
      var taken = 0;
      await _pump(tester, canTakePhoto: false, onTakePhoto: () => taken++);

      await tester.tap(find.text('鬼の写真を撮る'));
      expect(taken, 0);
    });

    testWidgets('送っている間は押せず、失敗したら文言を出す', (tester) async {
      var taken = 0;
      await _pump(
        tester,
        isBusy: true,
        errorMessage: '写真を送れませんでした。もう一度撮ってください',
        onTakePhoto: () => taken++,
      );

      expect(find.text('送っています'), findsOneWidget);
      expect(find.text('写真を送れませんでした。もう一度撮ってください'), findsOneWidget);
      await tester.tap(find.text('送っています'));
      expect(taken, 0);
    });

    testWidgets('閉じるボタンは44px以上', (tester) async {
      await _pump(tester);

      final size = tester.getSize(find.byTooltip('閉じる'));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('sendSightingPhoto', () {
    test('画像を上げてからsightingsを書き、成功ならnull', () async {
      final calls = <String>[];
      final result = await sendSightingPhoto(
        upload: () async => calls.add('upload'),
        record: () async => calls.add('record'),
      );

      expect(result, isNull);
      expect(calls, ['upload', 'record']);
    });

    test('アップロードに失敗したらsightingsを書かない', () async {
      var recorded = false;
      final result = await sendSightingPhoto(
        upload: () async => throw PhotoUploadFailedException('status=500'),
        record: () async => recorded = true,
      );

      expect(result, '写真を送れませんでした。もう一度撮ってください');
      expect(recorded, isFalse);
    });

    test('大きすぎる画像はそれと分かる文言にする', () async {
      final result = await sendSightingPhoto(
        upload: () async => throw PhotoTooLargeException(),
        record: () async {},
      );

      expect(result, '画像サイズが大きすぎます。もう一度撮影してください');
    });

    test('sightingsの書き込みに失敗したら失敗の文言を返す', () async {
      final result = await sendSightingPhoto(
        upload: () async {},
        record: () async => throw Exception('permission-denied'),
      );

      expect(result, '写真を送れませんでした。もう一度撮ってください');
    });
  });
}
