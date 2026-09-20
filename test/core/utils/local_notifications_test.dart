import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/core/utils/local_notifications.dart';

/// ローカル通知(issue #61のエリア外警告)のテスト。
///
/// 通知プラグインのメソッドチャネルを差し替えて、呼び出しの記録として
/// 受け取る。端末が無いテストではプラグインの登録が走らないため、
/// Android実装を自分で登録してから差し替える。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> calls;
  List<String> methods() => calls.map((c) => c.method).toList();

  setUp(() {
    calls = [];
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          // initializeの戻り値はboolなので、nullを返すと型で落ちる。
          return call.method == 'initialize' ? true : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('起動時の初期化で、残っているエリア外警告の通知を消す', () async {
    await initLocalNotifications();

    // エリア外警告は消えない通知として出すため、プロセスが落ちたり
    // Recentsからスワイプされたりしてフックのdisposeが走らないと、
    // ゲーム後も再起動後も残り続ける。起動時に必ず片付ける。
    expect(methods(), containsAllInOrder(['initialize', 'cancel']));
  });

  test('エリア外警告の通知は、出すのも消すのも同じIDで行う', () async {
    await showOutsideAreaNotification();
    await cancelOutsideAreaNotification();

    expect(methods(), ['show', 'cancel']);
    // 出す側と消す側でIDが食い違うと、戻っても通知が消えなくなる。
    final shownId = (calls[0].arguments as Map<Object?, Object?>)['id'];
    final cancelledId = (calls[1].arguments as Map<Object?, Object?>)['id'];
    expect(cancelledId, shownId);
    // 鬼放出の通知(id: 0)とは別のIDを使う(互いに上書きし合わないため)。
    expect(shownId, isNot(0));
  });
}
