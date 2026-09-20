import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:kakureru/core/utils/permission_queue.dart';
import 'package:permission_handler/permission_handler.dart';

/// 位置送信に必要な権限をまとめて要求する。
///
/// ゲーム開始時だけでなくアプリ起動直後にも呼ぶため、ViewModelから切り出して
/// 単体で呼べるようにしてある。すでに許可済みなら各リクエストは即座に
/// granted を返すだけでダイアログは出ないため、二重に呼んでも問題ない。
///
/// プラグイン呼び出しはコンストラクタで差し替えられるようにしてある
/// (テストでは実機の権限ダイアログを出さずに要求の順序だけを検証するため)。
class LocationPermissionService {
  /// 引数を省略すると実際のプラグイン(permission_handler /
  /// flutter_foreground_task)を呼ぶ。テストからのみ差し替える。
  LocationPermissionService({
    Future<PermissionStatus> Function(Permission permission)? requestPermission,
    Future<NotificationPermission> Function()? checkNotificationPermission,
    Future<NotificationPermission> Function()? requestNotificationPermission,
    PermissionQueue? queue,
  }) : _requestPermission = requestPermission ?? _requestWithHandler,
       _checkNotificationPermission =
           checkNotificationPermission ??
           FlutterForegroundTask.checkNotificationPermission,
       _requestNotificationPermission =
           requestNotificationPermission ??
           FlutterForegroundTask.requestNotificationPermission,
       _queue = queue ?? PermissionQueue.shared;

  final Future<PermissionStatus> Function(Permission permission)
  _requestPermission;
  final Future<NotificationPermission> Function() _checkNotificationPermission;
  final Future<NotificationPermission> Function()
  _requestNotificationPermission;

  /// 他機能(BLE)の権限要求と同時にダイアログを出さないための順番待ち。
  /// 既定は全機能で共有する[PermissionQueue.shared]。
  final PermissionQueue _queue;

  static Future<PermissionStatus> _requestWithHandler(Permission permission) =>
      permission.request();

  /// 位置情報とForeground Serviceの通知の権限を要求し、位置送信に必要な
  /// 権限がそろったかどうかを返す。
  ///
  /// 必須なのは「使用中のみ許可」とForeground Serviceの通知(Android 13+)の
  /// 2つ。ポケットに入れたまま遊ぶ運用のため「常に許可」(バックグラウンド
  /// 位置情報)も続けて要求するが、**拒否されても false にはしない**。
  /// Android 11+の「常に許可」はランタイムのダイアログでは直接付与されず
  /// 設定画面への誘導になるため、要求した直後の戻り値はまず denied になる。
  /// これを必須ゲートにしていたせいで、初回プレーだけ位置送信がまるごと
  /// 始まらなかった(issue #66)。このアプリは画面表示中に
  /// foregroundServiceType="location" のForeground Serviceを起動するので、
  /// 「使用中のみ許可」があれば位置取得は継続できる。
  ///
  /// Android 11+では「使用中のみ許可」と「常に許可」は同時には付与できない
  /// ため、まず使用中の許可を確定させてから、改めて常時許可をリクエストする
  /// 順序は維持している。
  Future<bool> ensureGranted() => _queue.add(_ensureGranted);

  Future<bool> _ensureGranted() async {
    final whileInUse = await _requestPermission(Permission.locationWhenInUse);
    if (!whileInUse.isGranted) return false;

    // 戻り値は見ない(上のdocコメント参照)。後から設定で「常に許可」に
    // してもらうための導線として要求だけは出しておく。
    await _requestPermission(Permission.locationAlways);

    var notification = await _checkNotificationPermission();
    if (notification != NotificationPermission.granted) {
      notification = await _requestNotificationPermission();
    }
    return notification == NotificationPermission.granted;
  }
}
