import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/room_setting_page.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _roomId = 'room1';

Room _room() => const Room(
  id: _roomId,
  roomCode: '1234',
  hostUserId: 'host',
  status: RoomStatus.waiting,
  createdAt: 0,
  setting: RoomSetting(),
  users: [RoomUser(id: 'host', displayName: 'ホスト', isHost: true)],
);

/// ホストとして設定画面を開き、エリア描画モードに入るまで済ませる。
Future<void> _openInDrawingMode(WidgetTester tester) async {
  // 既定の800x600だと「エリアを描く」ボタンが画面外に出てタップできない。
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final controller = StreamController<Room>.broadcast();
  addTearDown(controller.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myUidProvider.overrideWithValue('host'),
        roomStreamProvider(_roomId).overrideWith((ref) => controller.stream),
      ],
      child: const MaterialApp(home: RoomSettingPage(roomId: _roomId)),
    ),
  );
  await tester.pump();
  controller.add(_room());
  await tester.pump();

  await tester.tap(find.text('エリアを描く'));
  await tester.pump();
}

/// 地図の上で、[from] から [to] へドラッグしたことにする(座標は地図ローカル)。
///
/// `tester.drag` は使えない。flutter_map は `InteractiveFlag.none` でも
/// ScaleGestureRecognizer を必ず登録し、それがジェスチャーアリーナの
/// team captain になるため、地図を包む親の GestureDetector の pan は
/// アリーナで負けて onPanStart が一度も呼ばれない(実測)。ここでは
/// アリーナを介さず、地図を包む GestureDetector のコールバックを直接呼んで
/// 「ドラッグが認識された後」の画面の挙動だけを検証する。
Future<void> _dragOnMap(WidgetTester tester, Offset from, Offset to) async {
  final detector = tester.widget<GestureDetector>(
    find.ancestor(
      of: find.byType(FlutterMap),
      matching: find.byType(GestureDetector),
    ),
  );
  detector.onPanStart!(DragStartDetails(localPosition: from));
  detector.onPanUpdate!(
    DragUpdateDetails(globalPosition: to, localPosition: to),
  );
  detector.onPanEnd!(DragEndDetails());
  await tester.pump();
}

void main() {
  testWidgets('サイズが範囲外のドラッグでは、仮矩形を赤枠のまま残す', (tester) async {
    await _openInDrawingMode(tester);

    // 2px=数mのドラッグはエリアのサイズ下限(対角線10m)に届かず弾かれる。
    await _dragOnMap(tester, const Offset(400, 160), const Offset(402, 162));

    expect(find.textContaining('エリアが小さすぎます'), findsOneWidget);

    // 弾かれた仮矩形は消さず、赤枠にしてエラーと視覚的に結びつける。
    final layer = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
    expect(layer.polygons, hasLength(1));
    expect(layer.polygons.single.borderColor, Colors.red);

    // 弾かれた矩形はエリアとして採用しない(未設定のまま)。
    expect(find.textContaining('未設定です'), findsOneWidget);
  });

  testWidgets('サイズが範囲内のドラッグでは、エリアを確定して仮矩形を消す', (tester) async {
    await _openInDrawingMode(tester);

    // 100px=概ね200mなのでサイズは範囲内。
    await _dragOnMap(tester, const Offset(350, 110), const Offset(450, 210));

    expect(find.textContaining('エリアが小さすぎます'), findsNothing);
    expect(find.textContaining('エリアが大きすぎます'), findsNothing);
    expect(find.textContaining('未設定です'), findsNothing);

    // 確定したエリア(青枠)だけが残り、仮矩形(赤/橙)は消えている。
    final layer = tester.widget<PolygonLayer>(find.byType(PolygonLayer));
    expect(layer.polygons, hasLength(1));
    expect(layer.polygons.single.borderColor, Colors.blue);
  });

  testWidgets('弾かれた後に新しいドラッグを始めると、赤枠とエラーは消える', (tester) async {
    await _openInDrawingMode(tester);

    await _dragOnMap(tester, const Offset(400, 160), const Offset(402, 162));
    expect(find.textContaining('エリアが小さすぎます'), findsOneWidget);

    final detector = tester.widget<GestureDetector>(
      find.ancestor(
        of: find.byType(FlutterMap),
        matching: find.byType(GestureDetector),
      ),
    );
    detector.onPanStart!(
      DragStartDetails(localPosition: const Offset(100, 60)),
    );
    await tester.pump();

    expect(find.textContaining('エリアが小さすぎます'), findsNothing);
  });
}
