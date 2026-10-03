import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/features/room/game_alerts.dart';
import 'package:kakureru/features/room/game_over_navigation.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';
import 'package:kakureru/features/room/view/game_result_page.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

const _roomId = 'room1';

/// 終了の検知をテストから立てられるようにした[GameAlerts]の差し替え。
/// 本物はbuild()で1秒タイマーとRTDBの購読を始めるため、そこは持ち込まない。
class _FakeGameAlerts extends GameAlerts {
  @override
  GameAlertsState build() => initialGameAlertsState;

  void reportGameOver() =>
      state = (isOutsideAreaWarning: false, isGameOver: true);
}

class _FakeRoomRepository extends RoomRepository {
  @override
  Future<void> leaveRoom(String roomId) async {}
}

/// [useGameOverNavigation]だけを持つ最小のページ(GamePageは位置情報・
/// Wi-Fi・気圧・BLEのproviderを抱えていてテストから組めないため。
/// restart_recovery_test.dartの_Harnessと同じ方針)。
///
/// [blocked]はGamePageの`captureOpen`/`rewardOpen`相当。テスト側が外から
/// 値を差し替えて`isNavigationBlocked`を動かせるようにする(issue #154)。
class _Harness extends HookConsumerWidget {
  const _Harness({this.blocked});

  final ValueNotifier<bool>? blocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBlocked = blocked != null && useValueListenable(blocked!);
    useGameOverNavigation(
      ref,
      context,
      roomId: _roomId,
      isNavigationBlocked: isBlocked,
    );
    return Scaffold(
      body: Center(
        child: TextButton(
          // 購読エラー画面の「ホームに戻る」と同じ操作(issue #95で
          // GamePageに入った出口)。
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text('ホームに戻る'),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('終了を検知したら結果画面へ差し替える', (tester) async {
    final alerts = _FakeGameAlerts();
    await _pumpHarnessOverHome(tester, alerts: alerts);

    alerts.reportGameOver();
    await _pumpNavigation(tester);

    expect(find.byType(GameResultPage), findsOneWidget);
  });

  testWidgets('ホームへ戻る途中に終了が届いても、ホームのルートを置き換えない', (tester) async {
    // pop中(約300ms)はルートが生きていてcontext.mountedもtrueのままで、
    // そこでpushReplacementすると「今いちばん上にある生きたルート」=ホームが
    // 結果画面に置き換わる。結果画面が最初のルートになると、その
    // 「ホームに戻る」(popUntil(isFirst))は何もせず詰む(issue #94)。
    final alerts = _FakeGameAlerts();
    await _pumpHarnessOverHome(tester, alerts: alerts);

    await tester.tap(find.widgetWithText(TextButton, 'ホームに戻る'));
    await tester.pump();
    alerts.reportGameOver();
    await _pumpNavigation(tester);

    expect(find.text('ホーム画面'), findsOneWidget);
    expect(find.byType(GameResultPage), findsNothing);
  });

  testWidgets(
    '遷移を止めている間に終了が届いても結果画面へ移らず、解除すると移る(issue #154)',
    (tester) async {
      // 鬼の「捕まえた」(撮影画面)を想定: 送信を始めた時点でブロックを
      // 立ててから、送信中に終了判定が届く(RTDBのローカル反映は送信完了を
      // 待たずに届く)という順番を再現する。
      final alerts = _FakeGameAlerts();
      final blocked = ValueNotifier<bool>(false);
      addTearDown(blocked.dispose);
      await _pumpHarnessOverHome(tester, alerts: alerts, blocked: blocked);

      blocked.value = true;
      alerts.reportGameOver();
      await _pumpNavigation(tester);
      expect(find.byType(GameResultPage), findsNothing);

      // 撮影画面を閉じた(ブロック解除)。
      blocked.value = false;
      await _pumpNavigation(tester);
      expect(find.byType(GameResultPage), findsOneWidget);
    },
  );
}

/// 遷移(リビルド → useEffect → postFrameCallback → pushReplacement →
/// 遷移アニメーション)が落ち着くまで進める。
///
/// `pumpAndSettle`は使えない。結果画面は部屋が届くまで
/// CircularProgressIndicatorを回し続けるため、いつまでも落ち着かない。
Future<void> _pumpNavigation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// ハーネスを「ホーム画面の上にpushされたルート」として出す。
Future<void> _pumpHarnessOverHome(
  WidgetTester tester, {
  required _FakeGameAlerts alerts,
  ValueNotifier<bool>? blocked,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myUidProvider.overrideWithValue('me'),
        roomRepositoryProvider.overrideWithValue(_FakeRoomRepository()),
        // 結果画面へ遷移できた場合に、そこがRTDBを触らないようにしておく。
        roomStreamProvider(_roomId).overrideWith(
          (ref) => const Stream<Room>.empty(),
        ),
        gameAlertsProvider.overrideWith(() => alerts),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _Harness(blocked: blocked),
                  ),
                ),
                child: const Text('ホーム画面'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ホーム画面'));
  await tester.pumpAndSettle();
}
