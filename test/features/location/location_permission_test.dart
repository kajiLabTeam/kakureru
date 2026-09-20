import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/repository/location_permission.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  // 実際のプラグイン呼び出しを差し替えたサービスを組み立てる。
  // requested には要求された権限が順番に記録されるので、
  // 「どこで打ち切ったか」をテストから確認できる。
  LocationPermissionService buildService({
    required List<Permission> requested,
    PermissionStatus whileInUse = PermissionStatus.granted,
    PermissionStatus always = PermissionStatus.granted,
    NotificationPermission notificationBefore = NotificationPermission.granted,
    NotificationPermission notificationAfter = NotificationPermission.granted,
    List<String>? notificationCalls,
  }) {
    return LocationPermissionService(
      requestPermission: (permission) async {
        requested.add(permission);
        return permission == Permission.locationWhenInUse ? whileInUse : always;
      },
      checkNotificationPermission: () async {
        notificationCalls?.add('check');
        return notificationBefore;
      },
      requestNotificationPermission: () async {
        notificationCalls?.add('request');
        return notificationAfter;
      },
    );
  }

  test('すべて許可されていれば true を返し、使用中→常に許可 の順で要求する', () async {
    final requested = <Permission>[];

    final granted = await buildService(requested: requested).ensureGranted();

    expect(granted, isTrue);
    expect(requested, [
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ]);
  });

  test('使用中の許可が拒否されたら、常に許可は要求せず false を返す', () async {
    final requested = <Permission>[];
    final notificationCalls = <String>[];

    final granted = await buildService(
      requested: requested,
      whileInUse: PermissionStatus.denied,
      notificationCalls: notificationCalls,
    ).ensureGranted();

    expect(granted, isFalse);
    expect(requested, [Permission.locationWhenInUse]);
    expect(notificationCalls, isEmpty);
  });

  // Android 11+では「常に許可」はランタイムのダイアログでは付与されず
  // 設定画面への誘導になるため、要求した直後の戻り値はまず denied になる。
  // これを必須ゲートにしていたせいで、初回プレーだけ位置送信がまるごと
  // 始まらなかった(issue #66)。「使用中のみ許可」と通知があれば
  // Foreground Serviceで位置は取り続けられるので true を返す。
  test('常に許可が拒否されても、使用中の許可と通知があれば true を返す', () async {
    final requested = <Permission>[];
    final notificationCalls = <String>[];

    final granted = await buildService(
      requested: requested,
      always: PermissionStatus.permanentlyDenied,
      notificationCalls: notificationCalls,
    ).ensureGranted();

    expect(granted, isTrue);
    expect(requested, [
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ]);
    // 常に許可で打ち切らず、通知の確認まで進んでいること。
    expect(notificationCalls, ['check']);
  });

  test('常に許可が拒否され、通知も拒否されていれば false を返す', () async {
    final granted = await buildService(
      requested: <Permission>[],
      always: PermissionStatus.permanentlyDenied,
      notificationBefore: NotificationPermission.denied,
      notificationAfter: NotificationPermission.denied,
    ).ensureGranted();

    expect(granted, isFalse);
  });

  test('通知が未許可なら要求し、許可されれば true を返す', () async {
    final notificationCalls = <String>[];

    final granted = await buildService(
      requested: <Permission>[],
      notificationBefore: NotificationPermission.denied,
      notificationCalls: notificationCalls,
    ).ensureGranted();

    expect(granted, isTrue);
    expect(notificationCalls, ['check', 'request']);
  });

  test('通知がすでに許可済みなら、改めて要求はしない', () async {
    final notificationCalls = <String>[];

    final granted = await buildService(
      requested: <Permission>[],
      notificationCalls: notificationCalls,
    ).ensureGranted();

    expect(granted, isTrue);
    expect(notificationCalls, ['check']);
  });

  test('通知の要求が拒否されたら false を返す', () async {
    final granted = await buildService(
      requested: <Permission>[],
      notificationBefore: NotificationPermission.denied,
      notificationAfter: NotificationPermission.denied,
    ).ensureGranted();

    expect(granted, isFalse);
  });
}
