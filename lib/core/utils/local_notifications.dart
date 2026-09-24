import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

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

/// 撮影タイミングの通知ID。鬼放出(0)・エリア外(1)・ゲーム終了(2)とも別に取る。
const _photoCaptureDueNotificationId = 3;

/// 撮影間隔が来たタイミングで出す通知(issue #107フォローアップ)。
///
/// バナーは画面内表示のため、他のタブ(地図/写真)を見ている・アプリを
/// バックグラウンドにしている等で気づかれないことがある。役割を問わず出す
/// (鬼は撮影ボタン自体が出ない=押しても何も起きないため、通知だけ届いても
/// 実害は無い。むしろ鬼だけ通知が来ないと「気づいていないだけでは」と
/// 混乱させる)。チャンネルを`kakureru_release`/`kakureru_area`と分けるのは、
/// こちらは1ゲーム中に何度も繰り返し出るため、性格が違う通知と一緒に
/// 端末側の設定をいじられたくないため。失敗してもログに残すだけ。
Future<void> showPhotoCaptureDueNotification() {
  return _runOrLogFailure(
    () => _plugin.show(
      id: _photoCaptureDueNotificationId,
      title: _photoCaptureDueTitle,
      body: _photoCaptureDueBody,
      notificationDetails: const NotificationDetails(
        android: _photoCaptureDueAndroidDetails,
      ),
    ),
    what: '撮影タイミングの通知',
  );
}

const _photoCaptureDueTitle = 'かくれんぼ';
const _photoCaptureDueBody = '足元の写真を撮ってください';
const _photoCaptureDueAndroidDetails = AndroidNotificationDetails(
  'kakureru_photo',
  '撮影タイミングの通知',
  channelDescription: '足元写真を撮るタイミングになったら通知します',
  importance: Importance.high,
  priority: Priority.high,
);

/// 撮影タイミングの通知を[at]に出すよう、OS(AlarmManager)へ予約する。
///
/// 以前はゲーム画面のDartの`Timer`が発火したときに[showPhotoCaptureDueNotification]
/// を呼んでいたが、画面を消してポケットに入れるとDoze等でTimerが止まり、
/// **撮影直後(=画面を見ている)の1回目しか通知が届かない**ことがあった。
/// AlarmManagerに予約すればアプリの状態に関係なくOSが時刻どおりに出す。
///
/// 同じIDで予約し直すと前の予約は置き換わる。予約を取り消すには
/// [cancelPhotoCaptureDueNotification]を呼ぶ。[at]が過去だとプラグインが
/// 例外を投げるが、他の通知と同じくログに残すだけにする。
Future<void> schedulePhotoCaptureDueNotification(DateTime at) {
  return _runOrLogFailure(() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canExact = await android?.canScheduleExactNotifications();
    await _plugin.zonedSchedule(
      id: _photoCaptureDueNotificationId,
      title: _photoCaptureDueTitle,
      body: _photoCaptureDueBody,
      // 絶対時刻さえ合っていればよいので、端末のタイムゾーンを調べずUTCで渡す。
      scheduledDate: tz.TZDateTime.from(at, tz.UTC),
      notificationDetails: const NotificationDetails(
        android: _photoCaptureDueAndroidDetails,
      ),
      androidScheduleMode: photoCaptureDueScheduleMode(
        canScheduleExact: canExact,
      ),
    );
  }, what: '撮影タイミングの通知の予約');
}

/// 撮影通知の予約方式を決める。
///
/// 正確なアラームの権限(AndroidManifestのUSE_EXACT_ALARM /
/// SCHEDULE_EXACT_ALARM)があれば、Doze中でも時刻どおりに出す
/// `exactAllowWhileIdle`。権限が無い端末で`exact`系を使うとプラグインが
/// 例外を投げて通知が一切出なくなるため、数分遅れうるが確実に出る
/// `inexactAllowWhileIdle`に落とす(判定できない=nullも権限なし扱い)。
@visibleForTesting
AndroidScheduleMode photoCaptureDueScheduleMode({
  required bool? canScheduleExact,
}) => (canScheduleExact ?? false)
    ? AndroidScheduleMode.exactAllowWhileIdle
    : AndroidScheduleMode.inexactAllowWhileIdle;

/// 撮影通知の予約と、表示中の撮影通知をまとめて取り消す(撮影を済ませた・
/// ゲーム画面を離れたとき用)。失敗してもログに残すだけ。
Future<void> cancelPhotoCaptureDueNotification() => _runOrLogFailure(
  () => _plugin.cancel(id: _photoCaptureDueNotificationId),
  what: '撮影タイミングの通知の取り消し',
);
