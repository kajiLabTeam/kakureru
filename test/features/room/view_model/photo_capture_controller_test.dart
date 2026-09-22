import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/view_model/photo_capture_controller.dart';

/// [usePhotoCaptureController]をそのまま画面に見立てた最小のテスト用ウィジェット。
///
/// `doCapture`/`doResend`はImagePicker/FirebaseDatabase.instanceを直接呼ぶため
/// (PhotoRepositoryと違い注入口が無い)、実機かエミュレータ無しでは検証できない。
/// ここでは注入無しに検証できる「間隔が来たらisDueを立てる」タイマー挙動だけを見る。
class _Harness extends HookWidget {
  const _Harness({required this.intervalSec, required this.lastPhotoAt});

  final int intervalSec;
  final int? lastPhotoAt;

  @override
  Widget build(BuildContext context) {
    final controller = usePhotoCaptureController(
      context,
      roomId: 'room1',
      myUid: 'uid1',
      intervalSec: intervalSec,
      lastPhotoAt: lastPhotoAt,
    );
    return Text(controller.state.isDue ? 'due' : 'not-due');
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required int intervalSec,
  required int? lastPhotoAt,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _Harness(intervalSec: intervalSec, lastPhotoAt: lastPhotoAt),
      ),
    ),
  );
}

void main() {
  testWidgets('間隔をまだ過ぎていなければisDueはfalseのまま', (tester) async {
    await _pump(tester, intervalSec: 300, lastPhotoAt: null);

    expect(find.text('not-due'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('not-due'), findsOneWidget);
  });

  testWidgets('マウント時点で既に間隔を過ぎていれば、次フレームでisDueが立つ', (tester) async {
    final pastMillis = DateTime.now().millisecondsSinceEpoch -
        const Duration(minutes: 10).inMilliseconds;

    await _pump(tester, intervalSec: 300, lastPhotoAt: pastMillis);
    // addPostFrameCallback経由でstateHookを更新するため、反映には次のpumpが要る。
    await tester.pump();
    expect(find.text('due'), findsOneWidget);
  });

  testWidgets('間隔が経過した時点でタイマーによりisDueが立つ', (tester) async {
    await _pump(tester, intervalSec: 5, lastPhotoAt: null);
    expect(find.text('not-due'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    expect(find.text('due'), findsOneWidget);
  });

  testWidgets('lastPhotoAtがアプリ再起動をまたいでも間隔の基準になる', (tester) async {
    // 5秒間隔のうち3秒が経過済み。残りは2秒。
    final threeSecondsAgo = DateTime.now().millisecondsSinceEpoch -
        const Duration(seconds: 3).inMilliseconds;

    await _pump(tester, intervalSec: 5, lastPhotoAt: threeSecondsAgo);
    expect(find.text('not-due'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('not-due'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('due'), findsOneWidget);
  });

  testWidgets('画面が破棄されるとタイマーは片付き、残タイマーで失敗しない', (tester) async {
    await _pump(tester, intervalSec: 300, lastPhotoAt: null);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    expect(tester.takeException(), isNull);
    // pending timerが残っていればtestWidgetsが末尾で例外を出すため、
    // ここまで到達すること自体がdisposeでのcancelを保証している。
  });
}
