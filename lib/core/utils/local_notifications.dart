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
