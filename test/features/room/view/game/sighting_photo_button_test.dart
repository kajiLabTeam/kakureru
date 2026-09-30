import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/model/sighting.dart';
import 'package:kakureru/features/room/view/game/sighting_photo_button.dart';
import 'package:kakureru/features/room/view/game/sighting_sheet.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _roomId = 'room-1';
const _startedAt = 1000000;

const _room = Room(
  id: _roomId,
  roomCode: '1234',
  hostUserId: 'me',
  status: RoomStatus.playing,
  createdAt: 0,
  startedAt: _startedAt,
  setting: RoomSetting(),
  users: [
    RoomUser(id: 'me', displayName: 'わたし'),
    RoomUser(id: 'koki', displayName: 'こうき'),
  ],
);

Sighting _s(String id, {String uid = 'koki', int? takenAt}) => Sighting(
  id: id,
  uid: uid,
  takenAt: takenAt ?? _startedAt + id.codeUnitAt(0),
);

Finder get _badge => find.byKey(const ValueKey('sightingUnreadBadge'));

void main() {
  group('SightingPhotoButton', () {
    Future<void> pump(
      WidgetTester tester, {
      required int unreadCount,
      VoidCallback? onPressed,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SightingPhotoButton(
                unreadCount: unreadCount,
                onPressed: onPressed ?? () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('未読が無ければバッジを出さない', (tester) async {
      await pump(tester, unreadCount: 0);

      expect(_badge, findsNothing);
    });

    testWidgets('未読の数をバッジに出す', (tester) async {
      await pump(tester, unreadCount: 3);

      expect(find.descendant(of: _badge, matching: find.text('3')), findsOne);
    });

    testWidgets('100以上は「99+」にする', (tester) async {
      await pump(tester, unreadCount: 150);

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('押すとonPressedを呼び、44px以上ある', (tester) async {
      var pressed = 0;
      await pump(tester, unreadCount: 0, onPressed: () => pressed++);

      await tester.tap(find.byType(SightingPhotoButton));
      expect(pressed, 1);
      final size = tester.getSize(find.byType(SightingPhotoButton));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('useSightingBadge', () {
    late StreamController<List<Sighting>> sightings;

    setUp(() {
      sightings = StreamController<List<Sighting>>();
      addTearDown(sightings.close);
    });

    Future<void> pump(WidgetTester tester) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            myUidProvider.overrideWithValue('me'),
            roomStreamProvider(
              _roomId,
            ).overrideWith((ref) => Stream.value(_room)),
            sightingsStreamProvider(
              _roomId,
            ).overrideWith((ref) => sightings.stream),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HookConsumer(
                builder: (context, ref, _) {
                  final badge = useSightingBadge(
                    context,
                    ref,
                    roomId: _roomId,
                    startedAt: _startedAt,
                    myUid: 'me',
                  );
                  return Center(
                    child: SightingPhotoButton(
                      unreadCount: badge.unreadCount,
                      onPressed: () => unawaited(badge.openSheet()),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    Future<void> emit(WidgetTester tester, List<Sighting> value) async {
      sightings.add(value);
      // 1回目で値が届き、2回目でそれを反映した描き直しが走る。
      await tester.pump();
      await tester.pump();
    }

    testWidgets('画面に入った時点で既にある写真は見たことにする', (tester) async {
      await pump(tester);
      await emit(tester, [_s('a'), _s('b')]);

      expect(_badge, findsNothing);
    });

    testWidgets('後から増えた他人の写真だけを未読に数える', (tester) async {
      await pump(tester);
      await emit(tester, [_s('a')]);
      await emit(tester, [_s('a'), _s('b')]);

      expect(find.descendant(of: _badge, matching: find.text('1')), findsOne);

      // 自分が撮った写真は未読にしない。
      await emit(tester, [_s('a'), _s('b'), _s('c', uid: 'me')]);
      expect(find.descendant(of: _badge, matching: find.text('1')), findsOne);
    });

    testWidgets('前のゲームの写真は数えない', (tester) async {
      await pump(tester);
      await emit(tester, []);
      await emit(tester, [_s('old', takenAt: _startedAt - 1)]);

      expect(_badge, findsNothing);
    });

    testWidgets('シートを開いたら既読になり、開いている間に届いた分も既読にする', (
      tester,
    ) async {
      await pump(tester);
      await emit(tester, []);
      await emit(tester, [_s('a')]);
      expect(_badge, findsOneWidget);

      await tester.tap(find.byType(SightingPhotoButton));
      await _settleSheet(tester);
      expect(find.byType(SightingSheet), findsOneWidget);
      expect(_badge, findsNothing);

      await emit(tester, [_s('a'), _s('b')]);
      await tester.tap(find.byTooltip('閉じる'));
      await _settleSheet(tester);

      expect(find.byType(SightingSheet), findsNothing);
      expect(_badge, findsNothing);
    });
  });
}

/// シートの開閉のアニメーションを終わらせる。写真の読み込み中のスピナーが
/// 回り続けることがあるので`pumpAndSettle`は使えない。
Future<void> _settleSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
