import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/area_alert.dart';
import 'package:kakureru/features/room/area_alert_notifications.dart';

/// エリア外アラートのフック(issue #61)のテスト。
///
/// GamePage全体は位置情報・Wi-Fi・気圧・BLEなど多数のproviderに依存して
/// いてwidgetテストから組みにくいため、restart_recovery_test.dartと同じく
/// フックだけを載せた最小のWidgetをヘッドレスに回す。
///
/// 時刻は[_Harness]へ渡す`clock`で作る。widgetテストの`pump`は
/// `DateTime.now`を進めないため、猶予時間(10秒)や保持時間(30秒)の経過を
/// 実時間を待たずに再現するにはこの差し替えが要る(`Timer.periodic`の方は
/// `pump(duration)`で進むので、通知の出し直しはそちらで確認する)。
class _Harness extends HookWidget {
  const _Harness({
    required this.observation,
    required this.tick,
    required this.clock,
  });

  final OutsideAreaObservation observation;
  final int tick;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final isWarning = useOutsideAreaWarning(
      observation: observation,
      tick: tick,
      clock: clock,
    );
    // GamePageと同じく、警告の有無をそのまま振動・通知の条件にする。
    useOutsideAreaNotifications(isOutside: isWarning);
    return Text(
      isWarning ? '警告中' : '警告なし',
      textDirection: TextDirection.ltr,
    );
  }
}

void main() {
  final t0 = DateTime.utc(2026, 9, 20, 12);

  // 通知プラグインのメソッドチャネル。実機では出ているはずの通知を、
  // テストでは呼び出しの記録として受け取る。
  const notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  /// 外にいる観測。[fix]は「何番目の測位か」(判定は大小関係しか見ない)。
  OutsideAreaObservation outside({double meters = 50, int fix = 1}) => (
    status: OutsideAreaStatus.outside,
    outsideMeters: meters,
    bearingDegrees: 180,
    accuracyMeters: 5,
    updatedAt: fix,
  );

  OutsideAreaObservation inside({int fix = 1}) => (
    status: OutsideAreaStatus.inside,
    outsideMeters: 0,
    bearingDegrees: 0,
    accuracyMeters: 0,
    updatedAt: fix,
  );

  late List<String> notificationCalls;
  late DateTime now;
  late int tick;

  setUp(() {
    notificationCalls = [];
    now = t0;
    tick = 0;
    // 端末が無いテストではプラグインの登録が走らないため、Android実装を
    // 自分で登録してからチャネルを差し替える。
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, (call) async {
          notificationCalls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationChannel, null);
  });

  /// 観測と経過時間を与えてフックを1回回す。
  Future<void> pumpAt(
    WidgetTester tester, {
    required OutsideAreaObservation observation,
    Duration elapsed = Duration.zero,
    Widget Function(Widget harness)? wrap,
  }) async {
    now = now.add(elapsed);
    tick++;
    final harness = _Harness(
      observation: observation,
      tick: tick,
      clock: () => now,
    );
    await tester.pumpWidget(wrap == null ? harness : wrap(harness));
  }

  bool isWarningShown() => find.text('警告中').evaluate().isNotEmpty;

  testWidgets('猶予距離を超えたまま猶予時間が経つと警告に切り替わる', (tester) async {
    await pumpAt(tester, observation: outside());
    expect(isWarningShown(), isFalse);

    await pumpAt(
      tester,
      observation: outside(fix: 2),
      elapsed: outsideAreaGraceDuration - const Duration(seconds: 1),
    );
    expect(isWarningShown(), isFalse);

    await pumpAt(
      tester,
      observation: outside(fix: 3),
      elapsed: const Duration(seconds: 1),
    );
    expect(isWarningShown(), isTrue);
  });

  testWidgets('エリア内に戻ると即座に解除される', (tester) async {
    await pumpAt(tester, observation: outside());
    await pumpAt(
      tester,
      observation: outside(fix: 2),
      elapsed: outsideAreaGraceDuration,
    );
    expect(isWarningShown(), isTrue);

    await pumpAt(
      tester,
      observation: inside(fix: 3),
      elapsed: const Duration(seconds: 1),
    );
    expect(isWarningShown(), isFalse);
  });

  testWidgets('位置が古くなっても直前の判定を保ち、保持時間を過ぎたら解除する', (tester) async {
    await pumpAt(tester, observation: outside());
    await pumpAt(
      tester,
      observation: outside(fix: 2),
      elapsed: outsideAreaGraceDuration,
    );
    expect(isWarningShown(), isTrue);

    // 位置送信が止まり、以後の観測が「分からない」に変わる。
    await pumpAt(
      tester,
      observation: unknownOutsideAreaObservation,
      elapsed: outsideAreaUnknownHoldDuration - const Duration(seconds: 1),
    );
    expect(isWarningShown(), isTrue);

    await pumpAt(
      tester,
      observation: unknownOutsideAreaObservation,
      elapsed: const Duration(seconds: 1),
    );
    expect(
      isWarningShown(),
      isFalse,
      reason: '位置が分からないまま永久に振動させない',
    );
  });

  testWidgets('一瞬データが欠けても、猶予の計測は0に戻らない', (tester) async {
    await pumpAt(tester, observation: outside());

    // 猶予の途中で1回だけ観測が欠ける。ここで計測がリセットされると、
    // 短い間隔で欠けるだけで永久に警告が出なくなる。
    await pumpAt(
      tester,
      observation: unknownOutsideAreaObservation,
      elapsed: const Duration(seconds: 5),
    );
    expect(isWarningShown(), isFalse);

    await pumpAt(
      tester,
      observation: outside(fix: 2),
      elapsed: outsideAreaGraceDuration - const Duration(seconds: 5),
    );
    expect(isWarningShown(), isTrue);
  });

  testWidgets('エリア未設定・位置未取得の間は、いつまで経っても警告しない', (tester) async {
    for (var i = 0; i < 20; i++) {
      await pumpAt(
        tester,
        observation: unknownOutsideAreaObservation,
        elapsed: const Duration(seconds: 10),
      );
    }
    expect(isWarningShown(), isFalse);
    expect(notificationCalls, isNot(contains('show')));
  });

  testWidgets('警告になると通知を出し、振動の間隔ごとに出し直す', (tester) async {
    await pumpAt(tester, observation: outside());
    await pumpAt(
      tester,
      observation: outside(fix: 2),
      elapsed: outsideAreaGraceDuration,
    );
    expect(isWarningShown(), isTrue);
    expect(notificationCalls.where((c) => c == 'show'), hasLength(1));

    // Android 14以降は ongoing の通知もユーザーが消せるため、振動と同じ
    // 周期で出し直す(同じIDなので更新扱い)。
    await tester.pump(outsideAreaVibrationInterval);
    expect(notificationCalls.where((c) => c == 'show'), hasLength(2));

    await tester.pump(outsideAreaVibrationInterval);
    expect(notificationCalls.where((c) => c == 'show'), hasLength(3));
  });

  testWidgets('エリア内に戻ると通知を消し、以後は出し直さない', (tester) async {
    await pumpAt(tester, observation: outside());
    await pumpAt(
      tester,
      observation: outside(fix: 2),
      elapsed: outsideAreaGraceDuration,
    );
    expect(notificationCalls, contains('show'));

    await pumpAt(
      tester,
      observation: inside(fix: 3),
      elapsed: const Duration(seconds: 1),
    );
    await tester.pump();
    expect(notificationCalls, contains('cancel'));

    notificationCalls.clear();
    await tester.pump(outsideAreaVibrationInterval * 3);
    expect(notificationCalls, isEmpty, reason: '周期の後始末ができている');
  });

  testWidgets('ゲーム画面を離れると通知を消す', (tester) async {
    await pumpAt(tester, observation: outside());
    await pumpAt(
      tester,
      observation: outside(fix: 2),
      elapsed: outsideAreaGraceDuration,
    );
    expect(notificationCalls, contains('show'));

    notificationCalls.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(notificationCalls, contains('cancel'));

    await tester.pump(outsideAreaVibrationInterval * 3);
    expect(notificationCalls.where((c) => c == 'show'), isEmpty);
  });
}
