import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/core/utils/permission_queue.dart';
import 'package:kakureru/features/location/repository/location_permission.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  // 実際のプラグイン呼び出しを差し替えたサービスを組み立てる。
  // requested には要求された権限が順番に記録されるので、
  // 「どこで打ち切ったか」をテストから確認できる。
  //
  // queue はテストごとに新しく渡す。既定の PermissionQueue.shared を使うと
  // このファイルの全テストが1本の鎖でつながり、返らない要求を1つ足した
  // 瞬間に後続のテストまで道連れでタイムアウトする(issue #66のレビュー指摘)。
  LocationPermissionService buildService({
    required List<Permission> requested,
    PermissionStatus whileInUse = PermissionStatus.granted,
    PermissionStatus always = PermissionStatus.granted,
    PermissionStatus alwaysStatus = PermissionStatus.denied,
    NotificationPermission notificationBefore = NotificationPermission.granted,
    NotificationPermission notificationAfter = NotificationPermission.granted,
    List<String>? notificationCalls,
  }) {
    return LocationPermissionService(
      requestPermission: (permission) async {
        requested.add(permission);
        return permission == Permission.locationWhenInUse ? whileInUse : always;
      },
      checkPermission: (permission) async => alwaysStatus,
      checkNotificationPermission: () async {
        notificationCalls?.add('check');
        return notificationBefore;
      },
      requestNotificationPermission: () async {
        notificationCalls?.add('request');
        return notificationAfter;
      },
      queue: PermissionQueue(),
    );
  }

  test('すべて許可されていれば granted を返し、使用中→常に許可 の順で要求する', () async {
    final requested = <Permission>[];

    final result = await buildService(requested: requested).ensureGranted();

    expect(result, LocationPermissionResult.granted);
    expect(requested, [
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ]);
  });

  test('使用中の許可が拒否されたら、常に許可は要求せず locationDenied を返す', () async {
    final requested = <Permission>[];
    final notificationCalls = <String>[];

    final result = await buildService(
      requested: requested,
      whileInUse: PermissionStatus.denied,
      notificationCalls: notificationCalls,
    ).ensureGranted();

    expect(result, LocationPermissionResult.locationDenied);
    expect(requested, [Permission.locationWhenInUse]);
    expect(notificationCalls, isEmpty);
  });

  // Android 11+では「常に許可」はランタイムのダイアログでは付与されず
  // 設定画面への誘導になるため、要求した直後の戻り値はまず denied になる。
  // これを必須ゲートにしていたせいで、初回プレーだけ位置送信がまるごと
  // 始まらなかった(issue #66)。「使用中のみ許可」と通知があれば
  // Foreground Serviceで位置は取り続けられるので granted を返す。
  test('常に許可が拒否されても、使用中の許可と通知があれば granted を返す', () async {
    final requested = <Permission>[];
    final notificationCalls = <String>[];

    final result = await buildService(
      requested: requested,
      always: PermissionStatus.permanentlyDenied,
      notificationCalls: notificationCalls,
    ).ensureGranted();

    expect(result, LocationPermissionResult.granted);
    expect(requested, [
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ]);
    // 常に許可で打ち切らず、通知の確認まで進んでいること。
    expect(notificationCalls, ['check']);
  });

  // 未付与のまま毎回要求すると、Android 11+では設定画面へ飛ばされる。戻って
  // きた瞬間が resumed になり、復帰で位置送信を貼り直す仕組みと噛み合って
  // 設定画面へ飛ぶ→戻る→また飛ぶ、のループになる(issue #66のレビュー指摘)。
  test('常に許可が既に granted なら、改めて要求はしない', () async {
    final requested = <Permission>[];

    final result = await buildService(
      requested: requested,
      alwaysStatus: PermissionStatus.granted,
    ).ensureGranted();

    expect(result, LocationPermissionResult.granted);
    expect(requested, [Permission.locationWhenInUse]);
  });

  test('常に許可が permanentlyDenied なら、もう聞けないので要求しない', () async {
    final requested = <Permission>[];

    final result = await buildService(
      requested: requested,
      alwaysStatus: PermissionStatus.permanentlyDenied,
    ).ensureGranted();

    expect(result, LocationPermissionResult.granted);
    expect(requested, [Permission.locationWhenInUse]);
  });

  test('常に許可が拒否され、通知も拒否されていれば notificationDenied を返す', () async {
    final result = await buildService(
      requested: <Permission>[],
      always: PermissionStatus.permanentlyDenied,
      notificationBefore: NotificationPermission.denied,
      notificationAfter: NotificationPermission.denied,
    ).ensureGranted();

    expect(result, LocationPermissionResult.notificationDenied);
  });

  test('通知が未許可なら要求し、許可されれば granted を返す', () async {
    final notificationCalls = <String>[];

    final result = await buildService(
      requested: <Permission>[],
      notificationBefore: NotificationPermission.denied,
      notificationCalls: notificationCalls,
    ).ensureGranted();

    expect(result, LocationPermissionResult.granted);
    expect(notificationCalls, ['check', 'request']);
  });

  test('通知がすでに許可済みなら、改めて要求はしない', () async {
    final notificationCalls = <String>[];

    final result = await buildService(
      requested: <Permission>[],
      notificationCalls: notificationCalls,
    ).ensureGranted();

    expect(result, LocationPermissionResult.granted);
    expect(notificationCalls, ['check']);
  });

  // 位置情報と通知では直し方が違うので、画面の案内を出し分けるために
  // どちらが欠けたのかまで返す必要がある(issue #66のレビュー指摘)。
  test('通知の要求が拒否されたら、位置情報ではなく通知の不足として返す', () async {
    final result = await buildService(
      requested: <Permission>[],
      notificationBefore: NotificationPermission.denied,
      notificationAfter: NotificationPermission.denied,
    ).ensureGranted();

    expect(result, LocationPermissionResult.notificationDenied);
  });
}
