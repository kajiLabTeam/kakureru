import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/location/view_model/location_view_model.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:kakureru/features/wifi/model/proximity_level.dart';
import 'package:kakureru/features/wifi/model/wifi_scan_result.dart';
import 'package:kakureru/features/wifi/view_model/wifi_view_model.dart';
import 'package:kakureru/features/wifi/wifi_clue_math.dart';

const _roomId = 'room-1';

// 固定AP(物理APのキーが被らないよう、末尾から2文字目で分ける)。
const _apA = '00:1a:2b:3c:01:00';
const _apB = '00:1a:2b:3c:02:00';
const _apC = '00:1a:2b:3c:03:00';

// 各参加者のテザリングの親機(ランダムMAC)。
const _myHotspot = '6a:11:22:33:44:50';
const _targetHotspot = '7e:55:66:77:88:90';
const _passerHotspot = '8a:99:aa:bb:cc:d0';

/// 鬼(自分)のすぐ隣にいる逃走者と、少し離れた逃走者。屋外で固定APが
/// 3台しか見えず、各自のホットスポットが自分側で最強に見える状況。
///
/// ホットスポット込みで計算すると、隣の逃走者は「遠い」、最寄りは離れた
/// 方になる。除けば隣の逃走者が「近い」かつ最寄りになる。
final _locations = [
  const UserLocation(
    uid: 'me',
    latitude: 0,
    longitude: 0,
    wifiScan: WifiScanResult(
      bssidRssi: {
        _apA: -70,
        _apB: -75,
        _apC: -80,
        _myHotspot: -25,
        _targetHotspot: -55,
        _passerHotspot: -40,
      },
      hotspotBssid: _myHotspot,
    ),
  ),
  const UserLocation(
    uid: 'target',
    latitude: 0,
    longitude: 0,
    wifiScan: WifiScanResult(
      bssidRssi: {
        _apA: -71,
        _apB: -74,
        _apC: -82,
        _myHotspot: -55,
        _targetHotspot: -25,
        _passerHotspot: -75,
      },
      hotspotBssid: _targetHotspot,
    ),
  ),
  const UserLocation(
    uid: 'passer',
    latitude: 0,
    longitude: 0,
    wifiScan: WifiScanResult(
      bssidRssi: {
        _apA: -62,
        _apB: -83,
        _apC: -70,
        _myHotspot: -40,
        _passerHotspot: -25,
      },
      hotspotBssid: _passerHotspot,
    ),
  ),
];

final _room = Room(
  id: _roomId,
  roomCode: '1234',
  hostUserId: 'me',
  status: RoomStatus.playing,
  createdAt: 0,
  setting: const RoomSetting(),
  users: const [
    RoomUser(id: 'me', isHost: true, role: UserRole.demon),
    RoomUser(id: 'target'),
    RoomUser(id: 'passer'),
  ],
);

/// 位置の購読をせず、固定のlocationsだけを返す差し替え。
class _FakeLocationViewModel extends LocationViewModel {
  @override
  LocationState build() => LocationState(locations: _locations);
}

Future<ProviderContainer> _container() async {
  final container = ProviderContainer(
    overrides: [
      myUidProvider.overrideWithValue('me'),
      locationViewModelProvider.overrideWith(_FakeLocationViewModel.new),
      roomStreamProvider(
        _roomId,
      ).overrideWith((ref) => Stream.value(_room)),
    ],
  );
  addTearDown(container.dispose);
  // 最寄りの判定は役割を見るので、ルームが届くまで待つ。
  container.listen(roomStreamProvider(_roomId), (_, _) {});
  await container.read(roomStreamProvider(_roomId).future);
  return container;
}

Map<String, int> _withoutHotspots(Map<String, int> scan) => {
  for (final e in scan.entries)
    if (!{_myHotspot, _targetHotspot, _passerHotspot}.contains(e.key))
      e.key: e.value,
};

void main() {
  group('Wi-Fiの手がかりはホットスポットを除いて計算する(issue #142)', () {
    test('近い/遠いの判定', () async {
      final container = await _container();

      final levels = container.read(wifiProximityLevelsProvider(_roomId));

      expect(
        levels.firstWhere((e) => e.uid == 'target').level,
        ProximityLevel.close,
      );
    });

    test('最寄りの相手', () async {
      final container = await _container();

      expect(container.read(nearestOpponentUidProvider(_roomId)), 'target');
    });

    test('電波の一致(共通APの比較)にホットスポットが出ない', () async {
      final container = await _container();

      final comparisons = container.read(
        wifiComparisonsForProvider((_roomId, 'target')),
      );

      expect(comparisons.map((c) => c.bssid).toSet(), {_apA, _apB, _apC});
    });

    test('メーター', () async {
      final container = await _container();

      final meter = container.read(clueMeterForProvider((_roomId, 'target')));

      expect(
        meter,
        calculateClueMeter(
          _withoutHotspots(_locations[0].wifiScan!.bssidRssi),
          _withoutHotspots(_locations[1].wifiScan!.bssidRssi),
        ),
      );
      // 除かずに計算した値とは違う(除外が効いている)。
      expect(
        meter,
        isNot(
          calculateClueMeter(
            _locations[0].wifiScan!.bssidRssi,
            _locations[1].wifiScan!.bssidRssi,
          ),
        ),
      );
    });
  });
}
