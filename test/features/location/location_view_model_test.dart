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

  final List<Future<LocationPermissionResult>> _results;
  var _calls = 0;

  @override
  Future<LocationPermissionResult> ensureGranted() {
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
  final stoppedCalls = <String>[];

  /// watchLocations() に渡された roomId。購読が張られたかどうかを
  /// 見るために記録する。
  final watchedRooms = <String>[];

  @override
  Future<bool> startSendingLocation(String roomId) async {
    startedRooms.add(roomId);
    return startResult;
  }

  @override
  Future<void> stopSendingLocation() async {
    stoppedCalls.add('stop');
  }

  /// 空ストリームにしない。空だと「購読した」と「購読していない」が
  /// 見分けられず、購読を張り忘れる回帰を検知できないため
  /// (issue #66のレビュー指摘)。
  @override
  Stream<List<UserLocation>> watchLocations(String roomId) {
    watchedRooms.add(roomId);
    return Stream.value([
      const UserLocation(
        uid: 'other',
        latitude: 35,
        longitude: 139,
        updatedAt: 1,
      ),
    ]);
  }
}

/// listen したストリームの1件目が state に反映されるまで待つ。
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('LocationViewModel.ensurePermission', () {
    test(
      '先に呼ばれた要求が後から解決しても、後に呼ばれた要求の結果を上書きしない '
      '(起動時のMyAppとゲーム開始時のstart()が同時に権限確認する競合の再発防止)',
      () async {
        final earlyCallResult = Completer<LocationPermissionResult>();
        final lateCallResult = Completer<LocationPermissionResult>();
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

        lateCallResult.complete(LocationPermissionResult.granted);
        await lateCall;
        expect(
          container.read(locationViewModelProvider).failure,
          LocationFailure.none,
        );

        // 先の要求は(後から)拒否と分かる。
        earlyCallResult.complete(LocationPermissionResult.locationDenied);
        await earlyCall;

        // 呼び出し順としては古い結果なので、後の要求が書いた
        // 「問題なし」を上書きしてはいけない。
        expect(
          container.read(locationViewModelProvider).failure,
          LocationFailure.none,
        );
      },
    );

    test('権限確認が例外を投げても握りつぶし、位置情報の権限の失敗として扱う', () async {
      final container = ProviderContainer(
        overrides: [
          locationPermissionServiceProvider.overrideWithValue(
            _SequencedPermissionService([
              Future<LocationPermissionResult>.error(
                Exception('プラグイン呼び出しの失敗を模擬'),
              ),
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
        container.read(locationViewModelProvider).failure,
        LocationFailure.locationPermission,
      );
    });

    test('許可されれば failure は none になる', () async {
      final container = ProviderContainer(
        overrides: [
          locationPermissionServiceProvider.overrideWithValue(
            _SequencedPermissionService([
              Future.value(LocationPermissionResult.granted),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(locationViewModelProvider.notifier);

      final granted = await notifier.ensurePermission();

      expect(granted, isTrue);
      expect(
        container.read(locationViewModelProvider).failure,
        LocationFailure.none,
      );
    });

    // 通知を拒否したのに「位置情報を許可してください」と案内すると、設定で
    // 位置情報が許可済みなのを確認して詰む(issue #66のレビュー指摘)。
    test('通知が拒否されたときは、位置情報ではなく通知の失敗として区別する', () async {
      final container = ProviderContainer(
        overrides: [
          locationPermissionServiceProvider.overrideWithValue(
            _SequencedPermissionService([
              Future.value(LocationPermissionResult.notificationDenied),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final granted = await container
          .read(locationViewModelProvider.notifier)
          .ensurePermission();

      expect(granted, isFalse);
      expect(
        container.read(locationViewModelProvider).failure,
        LocationFailure.notificationPermission,
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
      required List<LocationPermissionResult> permissionResults,
    }) {
      final container = ProviderContainer(
        overrides: [
          locationPermissionServiceProvider.overrideWithValue(
            _SequencedPermissionService([
              for (final result in permissionResults) Future.value(result),
            ]),
          ),
          locationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('権限が無いときは権限の失敗だけが立ち、送信の開始は試みない', () async {
      final repository = _FakeLocationRepository();
      final container = buildContainer(
        repository: repository,
        permissionResults: [LocationPermissionResult.locationDenied],
      );

      await container.read(locationViewModelProvider.notifier).start('room-1');

      final state = container.read(locationViewModelProvider);
      expect(state.failure, LocationFailure.locationPermission);
      expect(state.isSending, isFalse);
      expect(repository.startedRooms, isEmpty);
    });

    // 自分が送れないことと、相手の位置を見られないことは別。ここを飛ばすと
    // 地図・Wi-Fi距離感・気圧の上下まで全部空になる(issue #66のレビュー指摘)。
    test('権限が無くても、他の参加者の位置の購読は張る', () async {
      final repository = _FakeLocationRepository();
      final container = buildContainer(
        repository: repository,
        permissionResults: [LocationPermissionResult.locationDenied],
      );

      await container.read(locationViewModelProvider.notifier).start('room-1');
      await _settle();

      expect(repository.watchedRooms, ['room-1']);
      expect(container.read(locationViewModelProvider).locations, hasLength(1));
    });

    test('送信の開始に失敗しても、他の参加者の位置の購読は張る', () async {
      final repository = _FakeLocationRepository(startResult: false);
      final container = buildContainer(
        repository: repository,
        permissionResults: [LocationPermissionResult.granted],
      );

      await container.read(locationViewModelProvider.notifier).start('room-1');
      await _settle();

      expect(repository.watchedRooms, ['room-1']);
      expect(container.read(locationViewModelProvider).locations, hasLength(1));
    });

    test('端末の位置情報がOFFなら、権限ではなくGPS自体の失敗として区別する', () async {
      locationServiceEnabled = false;
      final repository = _FakeLocationRepository();
      final container = buildContainer(
        repository: repository,
        permissionResults: [LocationPermissionResult.granted],
      );

      await container.read(locationViewModelProvider.notifier).start('room-1');

      expect(
        container.read(locationViewModelProvider).failure,
        LocationFailure.serviceDisabled,
      );
      expect(repository.startedRooms, isEmpty);
    });

    test('権限はあるのに送信を開始できなければ、権限ではなく送信の失敗が立つ '
        '(画面の案内を出し分けるため)', () async {
      final repository = _FakeLocationRepository(startResult: false);
      final container = buildContainer(
        repository: repository,
        permissionResults: [LocationPermissionResult.granted],
      );

      await container.read(locationViewModelProvider.notifier).start('room-1');

      final state = container.read(locationViewModelProvider);
      expect(state.failure, LocationFailure.sendingFailed);
      // 開始できていないのに「送信中」と表示しない(issue #66の無音の失敗)。
      expect(state.isSending, isFalse);
      expect(repository.startedRooms, ['room-1']);
    });

    test('送信を開始できたら failure は none になり isSending になる', () async {
      final repository = _FakeLocationRepository();
      final container = buildContainer(
        repository: repository,
        permissionResults: [LocationPermissionResult.granted],
      );

      await container.read(locationViewModelProvider.notifier).start('room-1');

      final state = container.read(locationViewModelProvider);
      expect(state.failure, LocationFailure.none);
      expect(state.isSending, isTrue);
    });

    test('一度失敗しても、設定で許可して呼び直せば警告の状態は解除される '
        '(アプリ復帰時の再試行が効くこと)', () async {
      final repository = _FakeLocationRepository();
      final container = buildContainer(
        repository: repository,
        permissionResults: [
          LocationPermissionResult.locationDenied,
          LocationPermissionResult.granted,
        ],
      );
      final notifier = container.read(locationViewModelProvider.notifier);

      await notifier.start('room-1');
      expect(
        container.read(locationViewModelProvider).failure,
        LocationFailure.locationPermission,
      );

      await notifier.start('room-1');

      final state = container.read(locationViewModelProvider);
      expect(state.failure, LocationFailure.none);
      expect(state.isSending, isTrue);
    });

    // locationViewModelProviderはアプリ生存期間のproviderなので、消さないと
    // 次に入ったルームの初回描画にいきなり前のルームの赤い警告が出る。しかも
    // 復帰時の再試行がそれを見て走り出す(issue #66のレビュー指摘)。
    test('stop()すると失敗の表示も畳む(次のルームへ持ち越さない)', () async {
      final repository = _FakeLocationRepository();
      final container = buildContainer(
        repository: repository,
        permissionResults: [LocationPermissionResult.locationDenied],
      );
      final notifier = container.read(locationViewModelProvider.notifier);

      await notifier.start('room-1');
      expect(
        container.read(locationViewModelProvider).failure,
        LocationFailure.locationPermission,
      );

      notifier.stop();

      final state = container.read(locationViewModelProvider);
      expect(state.failure, LocationFailure.none);
      expect(state.isSending, isFalse);
    });
  });
}
