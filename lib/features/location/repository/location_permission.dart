import 'package:flutter_foreground_task/flutter_foreground_task.dart';
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
  }) : _requestPermission = requestPermission ?? _requestWithHandler,
       _checkNotificationPermission =
           checkNotificationPermission ??
           FlutterForegroundTask.checkNotificationPermission,
       _requestNotificationPermission =
           requestNotificationPermission ??
           FlutterForegroundTask.requestNotificationPermission;

  final Future<PermissionStatus> Function(Permission permission)
  _requestPermission;
  final Future<NotificationPermission> Function() _checkNotificationPermission;
  final Future<NotificationPermission> Function()
  _requestNotificationPermission;

  static Future<PermissionStatus> _requestWithHandler(Permission permission) =>
      permission.request();

  /// 位置情報(常に許可)とForeground Serviceの通知の権限を要求し、
  /// すべて許可されたかどうかを返す。
  ///
  /// ポケットに入れたまま遊ぶ運用のため「常に許可」(バックグラウンド位置情報)まで
  /// 必要とする。Android 11+では「使用中のみ許可」と同時には付与できないため、
  /// まず使用中の許可を確定させてから、改めて常時許可をリクエストする。
  /// 加えてForeground Serviceの通知(Android 13+)の権限も確認する。
  Future<bool> ensureGranted() async {
    final whileInUse = await _requestPermission(Permission.locationWhenInUse);
    if (!whileInUse.isGranted) return false;

    final always = await _requestPermission(Permission.locationAlways);
    if (!always.isGranted) return false;

    var notification = await _checkNotificationPermission();
    if (notification != NotificationPermission.granted) {
      notification = await _requestNotificationPermission();
    }
    return notification == NotificationPermission.granted;
  }
}
