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

  // 通知は「出せなかったらそれまで」の付随機能で、呼び出し側に回復の余地が
  // 無い。投げっぱなしにすると未処理の非同期エラーになり、エリア外警告は
  // 8秒ごとに呼び直すので同じエラーが延々と出続ける。
  group('プラグインが失敗したとき', () {
    late List<String> logs;

    setUp(() {
      logs = [];
      notificationLogOverride = logs.add;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'initialize') return true;
            throw PlatformException(code: 'error', message: '端末側の失敗を模擬');
          });
    });

    tearDown(() => notificationLogOverride = null);

    test('エリア外警告を出すのに失敗しても、例外は投げずログに残す', () async {
      await expectLater(showOutsideAreaNotification(), completes);

      expect(logs, hasLength(1));
      expect(logs.single, contains('エリア外警告の通知に失敗'));
    });

    test('エリア外警告を消すのに失敗しても、例外は投げずログに残す', () async {
      await expectLater(cancelOutsideAreaNotification(), completes);

      expect(logs.single, contains('取り消しに失敗'));
    });

    test('鬼放出の通知に失敗しても、例外は投げずログに残す', () async {
      await expectLater(showDemonReleasedNotification(), completes);

      expect(logs.single, contains('鬼放出の通知に失敗'));
    });

    // main()はrunApp()より前でこれをawaitしているので、ここで例外を投げると
    // アプリがまったく立ち上がらない(黒画面で何のメッセージも出ない)。
    // 通知が出ないだけならゲームは遊べるので、起動を巻き添えにしない。
    test('起動時の後片付けに失敗しても、起動を止めない', () async {
      await expectLater(initLocalNotifications(), completes);

      expect(logs, isNotEmpty);
    });
  });
}
