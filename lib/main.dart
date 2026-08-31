import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/core/utils/local_notifications.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/room/view/room_home_page.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Foreground Service(位置情報送信用)のisolate間通信ポートを初期化する。
  // main()のできるだけ早い段階で呼ぶ必要がある。
  FlutterForegroundTask.initCommunicationPort();
  await initLocalNotifications();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuth.instance.signInAnonymously();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends HookConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 位置情報の権限はゲーム開始時ではなく、アプリを開いた直後に要求する。
    // 最初のフレームを描く前に呼ぶとActivityがまだ権限リクエストを受け取れず
    // ダイアログが出ないことがあるため、描画後のコールバックで呼ぶ。
    // 拒否されてもここでは何も出さない(送信を始めるGamePage側で警告を出す)。
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          ref.read(locationViewModelProvider.notifier).ensurePermission(),
        );
      });
      return null;
    }, const []);

    return MaterialApp(theme: buildAppTheme(), home: const RoomHomePage());
  }
}
