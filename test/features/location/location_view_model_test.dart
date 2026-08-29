import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/location/repository/location_permission.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';

/// [LocationPermissionService.ensureGranted]の結果を、呼び出された順に
/// 渡されたFutureで差し替えるテスト用サブクラス。
///
/// ensureGranted()は内部で複数の権限を順番に要求する多段の処理だが、
/// ここではその内部手順ではなく「複数の呼び出しがどの順で完了するか」
/// (LocationViewModel側の競合状態)だけを検証したいので、内部手順ごと
/// 丸ごと差し替えている。
class _SequencedPermissionService extends LocationPermissionService {
  _SequencedPermissionService(this._results);

  final List<Future<bool>> _results;
  var _calls = 0;

  @override
  Future<bool> ensureGranted() {
    final result = _results[_calls];
    _calls++;
    return result;
  }
}

void main() {
  group('LocationViewModel.ensurePermission', () {
    test(
      '先に呼ばれた要求が後から解決しても、後に呼ばれた要求の結果を上書きしない '
      '(起動時のMyAppとゲーム開始時のstart()が同時に権限確認する競合の再発防止)',
      () async {
        final earlyCallResult = Completer<bool>();
        final lateCallResult = Completer<bool>();
        final container = ProviderContainer(
          overrides: [
            locationPermissionServiceProvider.overrideWithValue(
              _SequencedPermissionService([
                earlyCallResult.future,
                lateCallResult.future,
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(locationViewModelProvider.notifier);

        // 先に呼ばれた要求(例: 起動時のMyApp)。すぐには解決しない。
        final earlyCall = notifier.ensurePermission();
        // 後から呼ばれた要求(例: ゲーム開始時のstart())。先に解決する。
        final lateCall = notifier.ensurePermission();

        lateCallResult.complete(true); // 後の要求は許可された
        await lateCall;
        expect(
          container.read(locationViewModelProvider).permissionDenied,
          isFalse,
        );

        earlyCallResult.complete(false); // 先の要求は(後から)拒否と分かる
        await earlyCall;

        // 呼び出し順としては古い結果なので、後の要求が書いた
        // permissionDenied:false を上書きしてはいけない。
        expect(
          container.read(locationViewModelProvider).permissionDenied,
          isFalse,
        );
      },
    );

    test('権限確認が例外を投げても握りつぶし、permissionDenied:trueにする', () async {
      final container = ProviderContainer(
        overrides: [
          locationPermissionServiceProvider.overrideWithValue(
            _SequencedPermissionService([
              Future<bool>.error(Exception('プラグイン呼び出しの失敗を模擬')),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(locationViewModelProvider.notifier);

      // 例外がensurePermission()の外へ漏れず、falseとして完了することを
      // 確認する(呼び出し側はunawaitedで呼ぶことがあるため、ここで
      // catchしないと未処理の非同期エラーとして無音で消えてしまう)。
      final granted = await notifier.ensurePermission();

      expect(granted, isFalse);
      expect(
        container.read(locationViewModelProvider).permissionDenied,
        isTrue,
      );
    });

    test('許可されれば permissionDenied は false になる', () async {
      final container = ProviderContainer(
        overrides: [
          locationPermissionServiceProvider.overrideWithValue(
            _SequencedPermissionService([Future.value(true)]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(locationViewModelProvider.notifier);

      final granted = await notifier.ensurePermission();

      expect(granted, isTrue);
      expect(
        container.read(locationViewModelProvider).permissionDenied,
        isFalse,
      );
    });
  });
}
