import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_photo.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/photo_taken_notifications.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _me = 'me';

RoomPhoto _photo(String id, String uid) =>
    RoomPhoto(id: id, uid: uid, takenAt: 0);

const _roomId = 'room1';

class _Harness extends HookConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    usePhotoTakenNotifications(ref, context, roomId: _roomId, myUid: _me);
    return const Scaffold(body: SizedBox());
  }
}

/// 自分の役割が[myRole]のルームで、写真の一覧を[photos]から流す地図なしの
/// 画面を立ち上げる。
Future<void> _pumpHarness(
  WidgetTester tester, {
  required UserRole myRole,
  required StreamController<List<RoomPhoto>> photos,
}) async {
  final room = Room(
    id: _roomId,
    roomCode: '1234',
    hostUserId: _me,
    status: RoomStatus.playing,
    createdAt: 0,
    setting: const RoomSetting(),
    users: [
      RoomUser(id: _me, displayName: 'わたし', role: myRole),
      const RoomUser(id: 'a', displayName: 'たろう'),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomStreamProvider(_roomId).overrideWith((ref) => Stream.value(room)),
        photosStreamProvider(_roomId).overrideWith((ref) => photos.stream),
      ],
      child: const MaterialApp(home: _Harness()),
    ),
  );
  await tester.pump();
}

void main() {
  group('photosToNotify (issue #120)', () {
    test('最初に受け取った一覧は基準にするだけで、何も知らせない', () {
      // 途中参加やアプリの再起動で、過去の写真をまとめて知らせないため。
      final result = photosToNotify(
        previousIds: null,
        photos: [_photo('p1', 'a'), _photo('p2', 'b')],
        myUid: _me,
        myRole: UserRole.demon,
      );
      expect(result, isEmpty);
    });

    test('鬼なら、新しく増えた他人の写真を知らせる', () {
      final result = photosToNotify(
        previousIds: {'p1'},
        photos: [_photo('p1', 'a'), _photo('p2', 'b')],
        myUid: _me,
        myRole: UserRole.demon,
      );
      expect(result.map((p) => p.id), ['p2']);
    });

    test('同時に複数枚増えたら、全部を知らせる', () {
      final result = photosToNotify(
        previousIds: {'p1'},
        photos: [_photo('p1', 'a'), _photo('p2', 'b'), _photo('p3', 'c')],
        myUid: _me,
        myRole: UserRole.demon,
      );
      expect(result.map((p) => p.id), ['p2', 'p3']);
    });

    test('自分が撮った写真は知らせない', () {
      final result = photosToNotify(
        previousIds: const {},
        photos: [_photo('p1', _me)],
        myUid: _me,
        myRole: UserRole.demon,
      );
      expect(result, isEmpty);
    });

    test('逃走者には知らせない', () {
      final result = photosToNotify(
        previousIds: const {},
        photos: [_photo('p1', 'a')],
        myUid: _me,
        myRole: UserRole.fugitive,
      );
      expect(result, isEmpty);
    });

    test('役割が分からない間は知らせない', () {
      final result = photosToNotify(
        previousIds: const {},
        photos: [_photo('p1', 'a')],
        myUid: _me,
        myRole: null,
      );
      expect(result, isEmpty);
    });
  });

  group('photoTakenMessage', () {
    test('1人なら名前にさんを付ける', () {
      expect(photoTakenMessage(['たろう']), 'たろうさんが足元の写真を撮りました');
    });

    test('複数人なら読点でつなぎ、同じ人は1回だけ出す', () {
      expect(
        photoTakenMessage(['たろう', 'はなこ', 'たろう']),
        'たろうさん、はなこさんが足元の写真を撮りました',
      );
    });
  });

  group('shouldNotifyPhotoCaptureDue', () {
    test('鬼には撮影タイミングの通知を出さない', () {
      expect(shouldNotifyPhotoCaptureDue(UserRole.demon), isFalse);
    });

    test('逃走者と、役割がまだ分からない人には出す', () {
      expect(shouldNotifyPhotoCaptureDue(UserRole.fugitive), isTrue);
      expect(shouldNotifyPhotoCaptureDue(null), isTrue);
    });
  });

  group('usePhotoTakenNotifications', () {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('鬼なら、逃走者が撮ったときに通知とSnackBarを出す', (tester) async {
      final photos = StreamController<List<RoomPhoto>>.broadcast();
      addTearDown(photos.close);
      await _pumpHarness(tester, myRole: UserRole.demon, photos: photos);

      photos.add([_photo('p1', 'a')]);
      await tester.pump();
      // 最初の一覧では知らせない。
      expect(calls, isEmpty);

      photos.add([_photo('p1', 'a'), _photo('p2', 'a')]);
      await tester.pump();

      expect(calls.map((c) => c.method), ['show']);
      expect(find.text('たろうさんが足元の写真を撮りました'), findsOneWidget);
    });

    testWidgets('逃走者なら、他の人が撮っても何も出さない', (tester) async {
      final photos = StreamController<List<RoomPhoto>>.broadcast();
      addTearDown(photos.close);
      await _pumpHarness(tester, myRole: UserRole.fugitive, photos: photos);

      photos
        ..add([_photo('p1', 'a')])
        ..add([_photo('p1', 'a'), _photo('p2', 'a')]);
      await tester.pump();

      expect(calls, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
