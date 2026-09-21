import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _plugin = FlutterLocalNotificationsPlugin();

/// テストから出力を検証するためだけの差し替え口。省略すると[debugPrint]。
@visibleForTesting
void Function(String message)? notificationLogOverride;

/// 通知プラグインの呼び出しを実行し、失敗しても呼び出し側へ投げ返さず
/// ログにだけ残す。
///
/// 通知は「出せなかったらそれまで」の付随機能で、失敗を呼び出し側が
/// 回復できる余地が無い。一方で投げっぱなしにすると未処理の非同期エラーに
/// なり、エリア外警告のように**周期的に呼び直すもの**では同じエラーが
/// 延々と出続ける。RTDB書き込みの[writeOrLogFailure]
/// (lib/core/utils/rtdb_write.dart)と同じ方針で、ここで必ず捕まえる。
///
/// なお呼び出し側で`unawaited()`を付けてもエラーは処理されない
/// (アナライザに意図を伝えるだけ)。握りつぶすのはこの関数の仕事。
Future<void> _runOrLogFailure(
  Future<void> Function() call, {
  required String what,
}) async {
  try {
    await call();
  } on Object catch (e) {
    (notificationLogOverride ?? debugPrint)(
      '[LocalNotifications] $whatに失敗: $e',
    );
  }
}

/// アプリ起動時に一度だけ呼ぶ(main.dart参照)。
///
/// 初期化のついでに、前回の起動で出しっぱなしになったエリア外警告の通知を
/// 消す。あの通知を消すのはゲーム画面のフックのdisposeだけで、プロセスが
/// 落ちた・Recentsからスワイプされた場合にはdisposeが走らない。放っておくと
/// ゲームが終わっても再起動しても残り続けるため、起動時に必ず片付ける
/// (エリア外にいるなら、判定側が周期的に出し直す)。
///
/// **失敗しても起動は止めない**。main()はこれを`runApp()`より前でawaitして
/// いるため、ここで例外を投げるとアプリがまったく立ち上がらない(黒画面で
/// 何のメッセージも出ない)。通知が出ないだけならゲーム自体は遊べるので、
/// 起動を巻き添えにする方が明らかに損。
Future<void> initLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _runOrLogFailure(
    () => _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    ),
    what: '通知の初期化',
  );
  await cancelOutsideAreaNotification();
}

/// 鬼放出の瞬間に出す通知。失敗してもログに残すだけ。
Future<void> showDemonReleasedNotification() {
  const androidDetails = AndroidNotificationDetails(
    'kakureru_release',
    '鬼放出の通知',
    channelDescription: '鬼が放出されたタイミングで通知します',
    importance: Importance.high,
    priority: Priority.high,
  );
  return _runOrLogFailure(
    () => _plugin.show(
      id: 0,
      title: 'かくれんぼ',
      body: '鬼が放出されました！',
      notificationDetails: const NotificationDetails(android: androidDetails),
    ),
    what: '鬼放出の通知',
  );
}

/// ゲーム終了の瞬間に出す通知(issue #71)。失敗してもログに残すだけ。
///
/// チャンネルは鬼放出と同じ`kakureru_release`にする。どちらも「ゲームの
/// 進行が切り替わった一度きりの合図」で性格が同じなので、端末側で通知の
/// 設定をいじるときも1つにまとまっていた方が扱いやすい。エリア外警告
/// (`kakureru_area`)だけは「戻るまで消えない警告」で性格が違うため分けている。
Future<void> showGameOverNotification() {
  const androidDetails = AndroidNotificationDetails(
    'kakureru_release',
    '鬼放出の通知',
    channelDescription: '鬼が放出されたタイミングで通知します',
    importance: Importance.high,
    priority: Priority.high,
  );
  return _runOrLogFailure(
    () => _plugin.show(
      id: _gameOverNotificationId,
      title: 'かくれんぼ',
      body: 'ゲームが終了しました',
      notificationDetails: const NotificationDetails(android: androidDetails),
    ),
    what: 'ゲーム終了の通知',
  );
}

/// エリア外警告の通知ID。鬼放出の通知(id: 0)とは別に取る。同じidだと
/// 互いに上書きし合ってしまう。
const _outsideAreaNotificationId = 1;

/// ゲーム終了の通知ID。鬼放出(0)・エリア外(1)とも別に取る。
const _gameOverNotificationId = 2;

/// プレイエリアの外に出ている間、出しっぱなしにする通知(issue #61)。
///
/// チャンネルを鬼放出用(`kakureru_release`)と分けているのは、通知の性格が
/// 違うため。こちらは「戻るまで消えない警告」なので、端末側でチャンネル
/// ごとに設定をいじられても鬼放出の通知と巻き添えにならないようにする。
///
/// `ongoing: true` + `autoCancel: false` は「タップでは消えない・通知一覧から
/// 自動では消えない」ための指定だが、**これだけでは残り続けない**。
/// Android 14(API 34)以降、`ongoing`の通知もユーザーがスワイプで消せる
/// ようになっており、このアプリの`targetSdk`は`flutter.targetSdkVersion`
/// (36)に解決される(android/app/build.gradle.kts)。
///
/// そのため呼び出し側は、振動と同じ周期でこれを呼び直すこと
/// (`useOutsideAreaNotifications`)。同じIDの`show`は更新扱いなので、
/// 繰り返し呼んでも通知が増えることはなく、消されたまま振動だけが続く
/// 状態を防げる。消すときは[cancelOutsideAreaNotification]を呼ぶ。
/// 失敗してもログに残すだけ。周期的に呼び直されるため、投げ返すと同じ
/// エラーが8秒ごとに出続ける。
Future<void> showOutsideAreaNotification() {
  const androidDetails = AndroidNotificationDetails(
    'kakureru_area',
    'エリア外の警告',
    channelDescription: 'プレイエリアの外に出ている間、警告を出し続けます',
    importance: Importance.high,
    priority: Priority.high,
    ongoing: true,
    autoCancel: false,
  );
  return _runOrLogFailure(
    () => _plugin.show(
      id: _outsideAreaNotificationId,
      title: 'プレイエリアの外です',
      // バナー(outsideAreaBannerSubtitle)と同じ文言にする。以前は「アプリを
      // 開いている間」と限定していたが、判定を画面の描画から切り離した
      // (issue #71)ので、画面を消していても検知・解除されるようになった。
      body: 'エリアに戻るまで振動と通知が続きます',
      notificationDetails: const NotificationDetails(android: androidDetails),
    ),
    what: 'エリア外警告の通知',
  );
}

/// エリア内に戻ったとき(とゲーム画面を離れたとき)に警告通知を消す。
/// 失敗してもログに残すだけ。
Future<void> cancelOutsideAreaNotification() => _runOrLogFailure(
  () => _plugin.cancel(id: _outsideAreaNotificationId),
  what: 'エリア外警告の通知の取り消し',
);
