import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/repository/location_permission.dart';
import 'package:kakureru/features/location/repository/location_repository.dart';
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

/// [LocationRepository]の差し替え。Firebase・Foreground Serviceへ触れずに、
/// 「送信の開始が成功したか失敗したか」だけをViewModelへ返す。
///
/// extends ではなく implements なのは、LocationRepositoryのコンストラクタが
/// FirebaseDatabase.instance / FirebaseAuth.instance に触れるため
/// (Firebase未初期化のテストでは super() を呼んだ時点で失敗する)。
class _FakeLocationRepository implements LocationRepository {
  _FakeLocationRepository({this.startResult = true});

  /// startSendingLocation() が返す値。Foreground Serviceの起動に失敗した
  /// ケースを再現するときに false にする。
  bool startResult;

  final startedRooms = <String>[];

  @override
  Future<bool> startSendingLocation(String roomId) async {
    startedRooms.add(roomId);
    return startResult;
  }

  @override
  Future<void> stopSendingLocation() async {}

  @override
  Stream<List<UserLocation>> watchLocations(String roomId) =>
      const Stream<List<UserLocation>>.empty();
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

  group('LocationViewModel.start', () {
    // 端末の位置情報(GPS)がONかどうかの確認はMethodChannel越しに実機へ
    // 聞きに行くため、テストではチャンネルの応答だけを差し替える。
    const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');
    var locationServiceEnabled = true;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      locationServiceEnabled = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(geolocatorChannel, (call) async {
            if (call.method == 'isLocationServiceEnabled') {
              return locationServiceEnabled;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(geolocatorChannel, null);
    });

    ProviderContainer buildContainer({
      required _FakeLocationRepository repository,
      required List<bool> permissionResults,
    }) {
      final container = ProviderContainer(
        overrides: [
          locationPermissionServiceProvider.overrideWithValue(
            _SequencedPermissionService([
              for (final granted in permissionResults) Future.value(granted),
            ]),
          ),
          locationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('権限が無いときは permissionDenied だけが立ち、送信の開始は試みない', () async {
      final repository = _FakeLocationRepository();
      final container = buildContainer(
        repository: repository,
        permissionResults: [false],
      );

      await container.read(locationViewModelProvider.notifier).start('room-1');

      final state = container.read(locationViewModelProvider);
      expect(state.permissionDenied, isTrue);
      expect(state.sendingFailed, isFalse);
      expect(state.isSending, isFalse);
      expect(repository.startedRooms, isEmpty);
    });

    test('権限はあるのに送信を開始できなければ、permissionDenied ではなく '
        'sendingFailed が立つ(画面の案内を出し分けるため)', () async {
      final repository = _FakeLocationRepository(startResult: false);
      final container = buildContainer(
        repository: repository,
        permissionResults: [true],
      );

      await container.read(locationViewModelProvider.notifier).start('room-1');

      final state = container.read(locationViewModelProvider);
      expect(state.permissionDenied, isFalse);
      expect(state.sendingFailed, isTrue);
      // 開始できていないのに「送信中」と表示しない(issue #66の無音の失敗)。
      expect(state.isSending, isFalse);
      expect(repository.startedRooms, ['room-1']);
    });

    test('送信を開始できたら、どちらの失敗フラグも立たず isSending になる', () async {
      final repository = _FakeLocationRepository();
      final container = buildContainer(
        repository: repository,
        permissionResults: [true],
      );

      await container.read(locationViewModelProvider.notifier).start('room-1');

      final state = container.read(locationViewModelProvider);
      expect(state.permissionDenied, isFalse);
      expect(state.sendingFailed, isFalse);
      expect(state.isSending, isTrue);
    });

    test('一度失敗しても、設定で許可して呼び直せば警告の状態は解除される '
        '(アプリ復帰時の再試行が効くこと)', () async {
      final repository = _FakeLocationRepository();
      final container = buildContainer(
        repository: repository,
        permissionResults: [false, true],
      );
      final notifier = container.read(locationViewModelProvider.notifier);

      await notifier.start('room-1');
      expect(
        container.read(locationViewModelProvider).permissionDenied,
        isTrue,
      );

      await notifier.start('room-1');

      final state = container.read(locationViewModelProvider);
      expect(state.permissionDenied, isFalse);
      expect(state.sendingFailed, isFalse);
      expect(state.isSending, isTrue);
    });
  });
}
