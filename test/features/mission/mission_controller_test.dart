import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/mission/model/mission_notice.dart';
import 'package:kakureru/features/mission/repository/mission_repository.dart';
import 'package:kakureru/features/mission/view_model/mission_view_model.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// [MissionController]のテスト。`GameAlerts`と同じく、画面(フレーム)が
/// 無くても1秒ごとのタイマーだけで判定が進むことを`ProviderContainer`で見る。
void main() {
  const roomId = 'room1';
  const hostUid = 'host';
  const fugitiveUid = 'me';
  const demonUid = 'demon';

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
      RoomUser(id: demonUid, displayName: 'おに', role: UserRole.demon),
    ],
  );

  Mission missionAt({
    required int createdAt,
    List<MissionSpot>? spots,
    int? finishedAt,
  }) => Mission(
    id: 'm1',
    round: 1,
    createdAt: createdAt,
    expiresAt: createdAt + 5 * 60 * 1000,
    finishedAt: finishedAt,
    spots:
        spots ??
        const [
          MissionSpot(id: 's0', lat: 35, lng: 137, radiusM: 15),
          MissionSpot(id: 's1', lat: 35.01, lng: 137, radiusM: 15),
        ],
  );

  ProviderContainer containerWith({
    required String myUid,
    required Room room,
    List<Mission> Function()? missions,
    UserLocation? Function()? location,
    _RecordingRepository? repository,
    _RecordingSink? sink,
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
        missionRepositoryProvider.overrideWithValue(
          repository ?? _RecordingRepository(),
        ),
        missionAlertSinkProvider.overrideWithValue(sink ?? _RecordingSink()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('ミッションの生成', () {
    test('ホストの端末だけが、放出から3分で1件だけ書く(地点は参加人数 - 1)', () {
      fakeAsync((async) {
        final repository = _RecordingRepository();
        final container = containerWith(
          myUid: hostUid,
          room: roomWith(releasedAgoSec: 3 * 60 + 1),
          repository: repository,
        );
        container.read(missionControllerProvider.notifier).start(roomId);
        // 書いたミッションが購読に戻ってこない状態で毎秒判定が回っても、
        // 二重に書かないよう間隔を置く(5秒に1回まで)。
        async.elapse(const Duration(seconds: 3));
        expect(repository.calls, [(spotCount: 2, round: 1)]);
      });
    });

    test('ホスト以外の端末は書かない', () {
      fakeAsync((async) {
        final repository = _RecordingRepository();
        final container = containerWith(
          myUid: fugitiveUid,
          room: roomWith(releasedAgoSec: 3 * 60 + 1),
          repository: repository,
        );
        container.read(missionControllerProvider.notifier).start(roomId);
        async.elapse(const Duration(seconds: 10));
        expect(repository.calls, isEmpty);
      });
    });

    test('放出から3分たつまでは書かない', () {
      fakeAsync((async) {
        final repository = _RecordingRepository();
        final container = containerWith(
          myUid: hostUid,
          room: roomWith(releasedAgoSec: 2 * 60 + 50),
          repository: repository,
        );
        container.read(missionControllerProvider.notifier).start(roomId);
        async.elapse(const Duration(seconds: 5));
        expect(repository.calls, isEmpty);
      });
    });
  });

  group('自分の進み具合', () {
    test('近い地点の範囲内が2回続いたら、画面が無くても到着になる', () {
      fakeAsync((async) {
        final mission = missionAt(createdAt: nowMs());
        var sample = 0;
        final container = containerWith(
          myUid: fugitiveUid,
          room: roomWith(releasedAgoSec: 6 * 60),
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
        expect(progress.spotId, 's0');
        expect(progress.arrival.arrived, isTrue);
      });
    });
  });

  test('前面の判定: 起動直後(null)と一時的な非アクティブも前面、それ以外は裏', () {
    expect(isForegroundLifecycle(null), isTrue);
    expect(isForegroundLifecycle(AppLifecycleState.resumed), isTrue);
    expect(isForegroundLifecycle(AppLifecycleState.inactive), isTrue);
    expect(isForegroundLifecycle(AppLifecycleState.hidden), isFalse);
    expect(isForegroundLifecycle(AppLifecycleState.paused), isFalse);
    expect(isForegroundLifecycle(AppLifecycleState.detached), isFalse);
  });

  group('お知らせ', () {
    test('逃走者には、アプリを開いていればバナーと振動で1回だけ出す', () {
      fakeAsync((async) {
        final mission = missionAt(createdAt: nowMs());
        final sink = _RecordingSink();
        final container = containerWith(
          myUid: fugitiveUid,
          room: roomWith(releasedAgoSec: 6 * 60),
          missions: () => [mission],
          sink: sink,
        );
        container.read(missionControllerProvider.notifier).start(roomId);
        async.elapse(const Duration(seconds: 3));

        final banner = container.read(missionBannerProvider);
        expect(banner?.kind, MissionNoticeKind.created);
        expect(banner?.message, startsWith('アクセスポイントへ行こう'));
        expect(sink.vibrations, 1);
        expect(sink.notified, isEmpty);
      });
    });

    test('アプリを閉じていればOSの通知にする', () {
      fakeAsync((async) {
        final mission = missionAt(createdAt: nowMs());
        final sink = _RecordingSink(foreground: false);
        final container = containerWith(
          myUid: fugitiveUid,
          room: roomWith(releasedAgoSec: 6 * 60),
          missions: () => [mission],
          sink: sink,
        );
        container.read(missionControllerProvider.notifier).start(roomId);
        async.elapse(const Duration(seconds: 3));

        expect(container.read(missionBannerProvider), isNull);
        expect(sink.notified, hasLength(1));
      });
    });

    test('鬼には出さない', () {
      fakeAsync((async) {
        final mission = missionAt(createdAt: nowMs());
        final sink = _RecordingSink();
        final container = containerWith(
          myUid: demonUid,
          room: roomWith(releasedAgoSec: 6 * 60),
          missions: () => [mission],
          sink: sink,
        );
        container.read(missionControllerProvider.notifier).start(roomId);
        async.elapse(const Duration(seconds: 3));

        expect(container.read(missionBannerProvider), isNull);
        expect(sink.vibrations, 0);
        expect(sink.notified, isEmpty);
      });
    });

    test('地点がすべて取られたら「AとBがごほうびを引いた」を出す', () {
      fakeAsync((async) {
        final created = nowMs();
        var mission = missionAt(createdAt: created);
        final sink = _RecordingSink(foreground: false);
        final container = containerWith(
          myUid: fugitiveUid,
          room: roomWith(releasedAgoSec: 6 * 60),
          missions: () => [mission],
          sink: sink,
        );
        container.read(missionControllerProvider.notifier).start(roomId);
        async.elapse(const Duration(seconds: 2));

        mission = missionAt(
          createdAt: created,
          finishedAt: nowMs(),
          spots: const [
            MissionSpot(
              id: 's0',
              lat: 35,
              lng: 137,
              radiusM: 15,
              claimedBy: hostUid,
            ),
            MissionSpot(
              id: 's1',
              lat: 35.01,
              lng: 137,
              radiusM: 15,
              claimedBy: demonUid,
            ),
          ],
        );
        async.elapse(const Duration(seconds: 2));

        expect(sink.notified.last, 'ほすと と おに が ごほうび を引いた');
      });
    });
  });
}

/// `createMission`に渡された地点の数と回を記録するリポジトリ。
class _RecordingRepository extends MissionRepository {
  final calls = <({int spotCount, int round})>[];

  @override
  Future<void> createMission(
    String roomId, {
    required List<LatLng> area,
    required int spotCount,
    required int round,
    required int nowMillis,
  }) async {
    calls.add((spotCount: spotCount, round: round));
  }
}

/// 出したお知らせを記録する出し先。
class _RecordingSink extends MissionAlertSink {
  _RecordingSink({this.foreground = true});

  final bool foreground;
  int vibrations = 0;
  final notified = <String>[];

  @override
  bool get isForeground => foreground;

  @override
  Future<void> vibrate() async => vibrations++;

  @override
  Future<void> notify(String message) async => notified.add(message);
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
