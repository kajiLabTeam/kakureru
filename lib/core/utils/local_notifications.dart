import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _plugin = FlutterLocalNotificationsPlugin();

/// アプリ起動時に一度だけ呼ぶ(main.dart参照)。
Future<void> initLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _plugin.initialize(settings: const InitializationSettings(android: androidSettings));
}

/// 鬼放出の瞬間に出す通知。
Future<void> showDemonReleasedNotification() async {
  const androidDetails = AndroidNotificationDetails(
    'kakureru_release',
    '鬼放出の通知',
    channelDescription: '鬼が放出されたタイミングで通知します',
    importance: Importance.high,
    priority: Priority.high,
  );
  await _plugin.show(
    id: 0,
    title: 'かくれんぼ',
    body: '鬼が放出されました！',
    notificationDetails: const NotificationDetails(android: androidDetails),
  );
}

/// エリア外警告の通知ID。鬼放出の通知(id: 0)とは別に取る。同じidだと
/// 互いに上書きし合ってしまう。
const _outsideAreaNotificationId = 1;

/// プレイエリアの外に出ている間、出しっぱなしにする通知(issue #61)。
///
/// チャンネルを鬼放出用(`kakureru_release`)と分けているのは、通知の性格が
/// 違うため。こちらは「戻るまで消えない警告」なので、端末側でチャンネル
/// ごとに設定をいじられても鬼放出の通知と巻き添えにならないようにする。
///
/// `ongoing: true` + `autoCancel: false` で、スワイプやタップでは消えず、
/// [cancelOutsideAreaNotification]を呼ぶまで残り続ける。
Future<void> showOutsideAreaNotification() async {
  const androidDetails = AndroidNotificationDetails(
    'kakureru_area',
    'エリア外の警告',
    channelDescription: 'プレイエリアの外に出ている間、警告を出し続けます',
    importance: Importance.high,
    priority: Priority.high,
    ongoing: true,
    autoCancel: false,
  );
  await _plugin.show(
    id: _outsideAreaNotificationId,
    title: 'プレイエリアの外です',
    body: 'エリアに戻るまで振動と通知が続きます',
    notificationDetails: const NotificationDetails(android: androidDetails),
  );
}

/// エリア内に戻ったとき(とゲーム画面を離れたとき)に警告通知を消す。
Future<void> cancelOutsideAreaNotification() =>
    _plugin.cancel(id: _outsideAreaNotificationId);
