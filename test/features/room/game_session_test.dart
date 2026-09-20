import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/room/game_session.dart';

/// start()が呼ばれた回数だけを記録する差し替え。本物のstart()はGeolocatorや
/// Foreground Serviceへ触れるため、ここでは呼ばせない。
class _RecordingLocationViewModel extends LocationViewModel {
  _RecordingLocationViewModel(this._initialState);

  final LocationState _initialState;
  final startedRooms = <String>[];

  @override
  LocationState build() => _initialState;

  @override
  Future<void> start(String roomId) async {
    startedRooms.add(roomId);
  }
}

/// [useLocationRetryOnResume]だけを貼ったテスト用ウィジェット。
/// useGameSession 全体はBLE・Wi-Fi・気圧のプラグインまで触るため、
/// 復帰時の再試行だけを切り出して確認する。
class _RetryHarness extends HookConsumerWidget {
  const _RetryHarness({required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useLocationRetryOnResume(ref, roomId: roomId);
    return const SizedBox.shrink();
  }
}

/// アプリのライフサイクル変化を、実際と同じ経路(flutter/lifecycleチャンネル)
/// でフレームワークへ流し込む。
Future<void> _sendLifecycle(
  WidgetTester tester,
  AppLifecycleState state,
) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/lifecycle',
    const StringCodec().encodeMessage(state.toString()),
    (_) {},
  );
}

Future<_RecordingLocationViewModel> _pumpHarness(
  WidgetTester tester,
  LocationState initialState,
) async {
  final viewModel = _RecordingLocationViewModel(initialState);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [locationViewModelProvider.overrideWith(() => viewModel)],
      child: const _RetryHarness(roomId: 'room-1'),
    ),
  );
  return viewModel;
}

void main() {
  group('useLocationRetryOnResume', () {
    testWidgets('権限を拒否したままアプリへ戻ってきたら、位置送信を始め直す', (tester) async {
      final viewModel = await _pumpHarness(
        tester,
        const LocationState(permissionDenied: true),
      );

      await _sendLifecycle(tester, AppLifecycleState.paused);
      await tester.pump();
      expect(viewModel.startedRooms, isEmpty, reason: '離脱しただけでは始め直さない');

      // 設定画面で許可して戻ってきた、に相当する。
      await _sendLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();

      expect(viewModel.startedRooms, ['room-1']);
    });

    testWidgets('送信の開始に失敗したままでも、戻ってきたら始め直す', (tester) async {
      final viewModel = await _pumpHarness(
        tester,
        const LocationState(sendingFailed: true),
      );

      await _sendLifecycle(tester, AppLifecycleState.paused);
      await _sendLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();

      expect(viewModel.startedRooms, ['room-1']);
    });

    testWidgets('正常に送信できているときは、戻ってきても始め直さない', (tester) async {
      // 無駄に始め直すとForeground Serviceを止めて起動し直すことになり、
      // 送信が一瞬途切れてしまう。
      final viewModel = await _pumpHarness(
        tester,
        const LocationState(isSending: true),
      );

      await _sendLifecycle(tester, AppLifecycleState.paused);
      await _sendLifecycle(tester, AppLifecycleState.resumed);
      await tester.pump();

      expect(viewModel.startedRooms, isEmpty);
    });
  });
}
