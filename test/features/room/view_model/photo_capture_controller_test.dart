import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/view_model/photo_capture_controller.dart';

/// [usePhotoCaptureController]をそのまま画面に見立てた最小のテスト用ウィジェット。
///
/// `doCapture`/`doResend`はImagePicker/FirebaseDatabase.instanceを直接呼ぶため
/// (PhotoRepositoryと違い注入口が無い)、実機かエミュレータ無しでは検証できない。
/// ここでは注入無しに検証できる「スロットで撮っていなければisDueを立てる」
/// タイマー挙動だけを見る。スロットは鬼の放出([releasedAt])から1間隔後に
/// 始まる。
class _Harness extends HookWidget {
  const _Harness({
    required this.intervalSec,
    required this.releasedAt,
    required this.lastPhotoAt,
    this.notifyWhenDue = true,
  });

  final int intervalSec;
  final int? releasedAt;
  final int? lastPhotoAt;
  final bool notifyWhenDue;

  @override
  Widget build(BuildContext context) {
    final controller = usePhotoCaptureController(
      context,
      roomId: 'room1',
      myUid: 'uid1',
      intervalSec: intervalSec,
      releasedAt: releasedAt,
      lastPhotoAt: lastPhotoAt,
      serverTimeOffsetMillis: 0,
      notifyWhenDue: notifyWhenDue,
    );
    return Text(controller.state.isDue ? 'due' : 'not-due');
  }
}

/// ハーネスを描き、フレーム確定後の判定(addPostFrameCallback)まで反映させる。
Future<void> _pump(
  WidgetTester tester, {
  required int intervalSec,
  required int? releasedAt,
  required int? lastPhotoAt,
  bool notifyWhenDue = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _Harness(
          intervalSec: intervalSec,
          releasedAt: releasedAt,
          lastPhotoAt: lastPhotoAt,
          notifyWhenDue: notifyWhenDue,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// テスト開始時点の時刻から[offset]ずらしたエポックミリ秒。
int _at(Duration offset) => DateTime.now().add(offset).millisecondsSinceEpoch;

void main() {
  // 通知プラグインのメソッドチャネルを差し替えて、呼び出しの記録として
  // 受け取る(local_notifications_test.dartと同じ方針)。
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> calls;
  int showCount() => calls.where((c) => c.method == 'show').length;

  setUp(() {
    calls = [];
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'initialize' ? true : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('鬼の放出時刻が無ければisDueは立たず、通知も出さない', (tester) async {
    await _pump(tester, intervalSec: 5, releasedAt: null, lastPhotoAt: null);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('not-due'), findsOneWidget);
    expect(showCount(), 0);
  });

  // プレイテストで、鬼の放出待ちの間にすぐ「撮ってください」が来た。
  // 1回目は鬼が放たれてから1間隔たった時点。
  testWidgets('鬼の放出待ちの間は促さない', (tester) async {
    await _pump(
      tester,
      intervalSec: 5,
      releasedAt: _at(const Duration(seconds: 30)),
      lastPhotoAt: null,
    );

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('not-due'), findsOneWidget);
    expect(showCount(), 0);
  });

  testWidgets('放出後も1間隔たつまでは促さず、たった時点で促す', (tester) async {
    // 5秒間隔で、放出から2秒。1回目は3秒後。
    await _pump(
      tester,
      intervalSec: 5,
      releasedAt: _at(const Duration(seconds: -2)),
      lastPhotoAt: null,
    );
    expect(find.text('not-due'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('not-due'), findsOneWidget);
    expect(showCount(), 0);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('due'), findsOneWidget);
    expect(showCount(), 1);
  });

  // 実データで、最初のスロットに1枚も撮られていなかった。以前は「画面を
  // 開いてから間隔ぶん」待ってから通知しており、スロットの終わりにしか
  // 来なかったため。
  testWidgets('未撮影なら、スロットの途中で画面を開いてもすぐに促す', (tester) async {
    // 放出から5分10秒=1回目のスロットに入って10秒。
    await _pump(
      tester,
      intervalSec: 300,
      releasedAt: _at(const Duration(minutes: -5, seconds: -10)),
      lastPhotoAt: null,
    );

    expect(find.text('due'), findsOneWidget);
    expect(showCount(), 1);
  });

  testWidgets('今のスロットで撮影済みなら、次のスロットの開始で促す', (tester) async {
    // 5秒スロットの4秒目(放出から9秒)。1秒前に撮影済み。次の区切りまで1秒。
    // (以前の「撮影+間隔」だと4秒後まで来なかった。)
    await _pump(
      tester,
      intervalSec: 5,
      releasedAt: _at(const Duration(seconds: -9)),
      lastPhotoAt: _at(const Duration(seconds: -1)),
    );
    expect(find.text('not-due'), findsOneWidget);
    expect(showCount(), 0);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('due'), findsOneWidget);
    expect(showCount(), 1);
  });

  testWidgets('前のスロットの写真しか無ければ、マウント直後から促す', (tester) async {
    // 放出から17分=3回目のスロット(15:00〜)。14分時点の写真は2回目のもの。
    await _pump(
      tester,
      intervalSec: 300,
      releasedAt: _at(const Duration(minutes: -17)),
      lastPhotoAt: _at(const Duration(minutes: -3)),
    );

    expect(find.text('due'), findsOneWidget);
    expect(showCount(), 1);
  });

  testWidgets('通知は1スロットに1回。撮らずに次のスロットに入ったらもう一度出す', (tester) async {
    // 5秒スロットの1秒目(放出から6秒)。
    final releasedAt = _at(const Duration(seconds: -6));
    await _pump(
      tester,
      intervalSec: 5,
      releasedAt: releasedAt,
      lastPhotoAt: null,
    );
    expect(showCount(), 1);

    // 同じスロットのうちに描き直されても(ルームの更新等)重ねて出さない。
    await _pump(
      tester,
      intervalSec: 5,
      releasedAt: releasedAt,
      lastPhotoAt: _at(const Duration(seconds: -60)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(showCount(), 1);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('due'), findsOneWidget);
    expect(showCount(), 2);
  });

  // 撮る側でなければ「撮ってください」の通知は出さない(takesFootPhotos)。
  testWidgets('通知しない指定なら、isDueだけ立てて通知は出さない', (tester) async {
    await _pump(
      tester,
      intervalSec: 5,
      releasedAt: _at(const Duration(seconds: -6)),
      lastPhotoAt: null,
      notifyWhenDue: false,
    );

    await tester.pump(const Duration(seconds: 6));

    expect(find.text('due'), findsOneWidget);
    expect(showCount(), 0);
  });

  testWidgets('タイマーの途中で通知しない指定に変わったら、発火時点の指定に従う', (tester) async {
    // 撮る側として始まり、次のスロットが来る前に撮る側でなくなった状況。
    final releasedAt = _at(const Duration(seconds: -9));
    final lastPhotoAt = _at(const Duration(seconds: -1));
    await _pump(
      tester,
      intervalSec: 5,
      releasedAt: releasedAt,
      lastPhotoAt: lastPhotoAt,
    );
    await _pump(
      tester,
      intervalSec: 5,
      releasedAt: releasedAt,
      lastPhotoAt: lastPhotoAt,
      notifyWhenDue: false,
    );

    await tester.pump(const Duration(seconds: 2));

    expect(find.text('due'), findsOneWidget);
    expect(showCount(), 0);
  });

  testWidgets('画面が破棄されるとタイマーは片付き、残タイマーで失敗しない', (tester) async {
    await _pump(
      tester,
      intervalSec: 300,
      releasedAt: _at(const Duration(minutes: -5, seconds: -1)),
      lastPhotoAt: _at(const Duration(seconds: -1)),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    expect(tester.takeException(), isNull);
    // pending timerが残っていればtestWidgetsが末尾で例外を出すため、
    // ここまで到達すること自体がdisposeでのcancelを保証している。
  });
}
