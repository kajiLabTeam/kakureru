import 'package:permission_handler/permission_handler.dart';

/// BLEの広告・スキャンに必要な権限をまとめて要求する。
///
/// Android 12(API31)+ではBLUETOOTH_SCAN/ADVERTISE/CONNECTが実行時権限になる。
/// flutter_blue_plus/flutter_ble_peripheralはどちらも権限リクエスト自体は
/// 代行しないため、位置情報(LocationPermissionService)と同じくアプリ側で
/// 明示的に要求する必要がある。
class BlePermissionService {
  /// 引数を省略すると実際のプラグイン(permission_handler)を呼ぶ。
  /// テストからのみ差し替える。
  BlePermissionService({
    Future<PermissionStatus> Function(Permission permission)? requestPermission,
  }) : _requestPermission = requestPermission ?? _requestWithHandler;

  final Future<PermissionStatus> Function(Permission permission)
  _requestPermission;

  static Future<PermissionStatus> _requestWithHandler(Permission permission) =>
      permission.request();

  /// 3つとも許可されたかどうかを返す。Android 11以前ではこれらは
  /// インストール時権限扱いのため、要求は即座にgrantedで返る。
  Future<bool> ensureGranted() async {
    final scan = await _requestPermission(Permission.bluetoothScan);
    if (!scan.isGranted) return false;

    final advertise = await _requestPermission(Permission.bluetoothAdvertise);
    if (!advertise.isGranted) return false;

    final connect = await _requestPermission(Permission.bluetoothConnect);
    return connect.isGranted;
  }
}
