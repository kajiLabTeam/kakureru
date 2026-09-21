import 'package:flutter/material.dart';
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
class _Harness extends HookConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useGameOverNavigation(
      ref,
      context,
      roomId: _roomId,
      isShowingCaughtTransition: false,
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
                  MaterialPageRoute<void>(builder: (_) => const _Harness()),
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
