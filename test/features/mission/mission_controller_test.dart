import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/mission/repository/mission_repository.dart';
import 'package:kakureru/features/mission/view_model/mission_view_model.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_proximity_entry.dart';
import 'package:kakureru/features/wifi/view_model/wifi_view_model.dart';

/// [MissionController]のテスト。`GameAlerts`と同じく、画面(フレーム)が
/// 無くても1秒ごとのタイマーだけで判定が進むことを`ProviderContainer`で見る。
void main() {
  const roomId = 'room1';
  const hostUid = 'host';
  const fugitiveUid = 'me';

  int nowMs() => DateTime.now().millisecondsSinceEpoch;

  Room roomWith({required int releasedAgoSec}) => Room(
    id: roomId,
    roomCode: '1234',
    hostUserId: hostUid,
    createdAt: 0,
    status: RoomStatus.playing,
    startedAt: 0,
    releasedAt: nowMs() - releasedAgoSec * 1000,
    setting: const RoomSetting(),
    users: const [
      RoomUser(id: hostUid, displayName: 'ほすと'),
      RoomUser(id: fugitiveUid, displayName: 'わたし'),
      RoomUser(id: 'demon', displayName: 'おに', role: UserRole.demon),
    ],
  );

  ProviderContainer containerWith({
    required String myUid,
    required Room room,
    List<Mission> Function()? missions,
    UserLocation? Function()? location,
    List<WifiProximityEntry> Function()? levels,
    _RecordingRepository? repository,
  }) {
    final container = ProviderContainer(
      overrides: [
        myUidProvider.overrideWithValue(myUid),
        serverTimeOffsetProvider.overrideWith((ref) => Stream.value(0)),
        roomStreamProvider(roomId).overrideWith((ref) => Stream.value(room)),
        missionsStreamProvider(roomId).overrideWith(
          (ref) => Stream.periodic(
            const Duration(milliseconds: 500),
            (_) => missions?.call() ?? const <Mission>[],
          ),
        ),
        locationViewModelProvider.overrideWith(
          () => _StubLocationViewModel(location ?? () => null),
        ),
        wifiProximityLevelsProvider(roomId).overrideWith(
          () => _StubLevels(roomId, levels ?? () => const []),
        ),
        missionRepositoryProvider.overrideWithValue(
          repository ?? _RecordingRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ミッションの生成', () {
    test('ホストの端末だけが、放出から30秒で1件だけ書く', () {
      fakeAsync((async) {
        final repository = _RecordingRepository();
        final container = containerWith(
          myUid: hostUid,
          room: roomWith(releasedAgoSec: 31),
          repository: repository,
        );
        container.read(missionControllerProvider.notifier).start(roomId);
        // 書いたミッションが購読に戻ってこない状態で毎秒判定が回っても、
        // 二重に書かないよう間隔を置く(5秒に1回まで)。
        async.elapse(const Duration(seconds: 3));
        expect(repository.createCalls, 1);
      });
    });

    test('ホスト以外の端末は書かない', () {
      fakeAsync((async) {
        final repository = _RecordingRepository();
        final container = containerWith(
          myUid: fugitiveUid,
          room: roomWith(releasedAgoSec: 31),
          repository: repository,
        );
        container.read(missionControllerProvider.notifier).start(roomId);
        async.elapse(const Duration(seconds: 10));
        expect(repository.createCalls, 0);
      });
    });

    test('放出から30秒たつまでは書かない', () {
      fakeAsync((async) {
        final repository = _RecordingRepository();
        final container = containerWith(
          myUid: hostUid,
          room: roomWith(releasedAgoSec: 10),
          repository: repository,
        );
        container.read(missionControllerProvider.notifier).start(roomId);
        async.elapse(const Duration(seconds: 5));
        expect(repository.createCalls, 0);
      });
    });
  });

  group('自分の進み具合', () {
    test('アクセスポイントの範囲内が2回続いたら、画面が無くても到着になる', () {
      fakeAsync((async) {
        final created = nowMs();
        final mission = Mission(
          id: 'm1',
          type: MissionType.accessPoint,
          createdAt: created,
          expiresAt: created + 180000,
          lat: 35,
          lng: 137,
          radiusM: 15,
        );
        var sample = 0;
        final container = containerWith(
          myUid: fugitiveUid,
          room: roomWith(releasedAgoSec: 60),
          missions: () => [mission],
          // 呼ばれるたびに新しい読み取り(updatedAtが進む)を返す。
          location: () => UserLocation(
            uid: fugitiveUid,
            latitude: 35,
            longitude: 137,
            accuracy: 5,
            updatedAt: ++sample,
          ),
        );
        container.read(missionControllerProvider.notifier).start(roomId);
        async.elapse(const Duration(seconds: 5));

        final progress = container.read(missionControllerProvider);
        expect(progress.missionId, 'm1');
        expect(progress.arrival.arrived, isTrue);
      });
    });

    test('「鬼に近づけ」は反応なし → ありで達成になる', () {
      fakeAsync((async) {
        final created = nowMs();
        final mission = Mission(
          id: 'a1',
          type: MissionType.approachDemon,
          createdAt: created,
          expiresAt: created + 120000,
        );
        var close = false;
        final container = containerWith(
          myUid: fugitiveUid,
          room: roomWith(releasedAgoSec: 60),
          missions: () => [mission],
          levels: () => [
            WifiProximityEntry(
              uid: 'demon',
              level: close ? ProximityLevel.close : ProximityLevel.far,
            ),
          ],
        );
        container.read(missionControllerProvider.notifier).start(roomId);
        async.elapse(const Duration(seconds: 3));
        expect(
          container.read(missionControllerProvider).approach.achieved,
          isFalse,
        );

        close = true;
        async.elapse(const Duration(seconds: 3));
        expect(
          container.read(missionControllerProvider).approach.achieved,
          isTrue,
        );
      });
    });
  });
}

/// `createMission`の呼び出し回数だけを記録するリポジトリ。
class _RecordingRepository extends MissionRepository {
  int createCalls = 0;

  @override
  Future<void> createMission(
    String roomId, {
    required List<LatLng> area,
    required LatLng? previousPoint,
    required int nowMillis,
  }) async {
    createCalls++;
  }
}

class _StubLocationViewModel extends LocationViewModel {
  _StubLocationViewModel(this._read);

  final UserLocation? Function() _read;

  @override
  LocationState build() {
    final timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => state = _current(),
    );
    ref.onDispose(timer.cancel);
    return _current();
  }

  LocationState _current() {
    final location = _read();
    return LocationState(locations: location == null ? const [] : [location]);
  }
}

class _StubLevels extends WifiProximityLevelsNotifier {
  _StubLevels(super.roomId, this._read);

  final List<WifiProximityEntry> Function() _read;

  @override
  List<WifiProximityEntry> build() {
    final timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => state = _read(),
    );
    ref.onDispose(timer.cancel);
    return _read();
  }
}
