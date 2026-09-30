import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/wifi/clue_scans.dart';
import 'package:kakureru/features/wifi/model/wifi_scan_result.dart';

const _fixedAp = '00:1a:2b:3c:4d:50';
const _aliceHotspot = '6a:11:22:33:44:50';
const _bobHotspot = '7e:55:66:77:88:90';

UserLocation _location(String uid, WifiScanResult? scan) =>
    UserLocation(uid: uid, latitude: 0, longitude: 0, wifiScan: scan);

WifiScanResult _scan({String? hotspotBssid}) => WifiScanResult(
  bssidRssi: const {_fixedAp: -60, _aliceHotspot: -30, _bobHotspot: -50},
  hotspotBssid: hotspotBssid,
);

void main() {
  group('clueBssidRssiByUid(issue #142)', () {
    test('参加中の人が共有したホットスポットを、全員のスキャンから除く', () {
      final scans = clueBssidRssiByUid(
        locations: [
          _location('alice', _scan(hotspotBssid: _aliceHotspot)),
          _location('carol', _scan()),
        ],
        users: const [
          RoomUser(id: 'alice'),
          RoomUser(id: 'carol'),
        ],
      );

      // テザリングしていないcarolのスキャンからもaliceのホットスポットを除く。
      expect(scans['alice'], {_fixedAp: -60, _bobHotspot: -50});
      expect(scans['carol'], {_fixedAp: -60, _bobHotspot: -50});
    });

    test('退出した人の古いhotspotBssidでは除かない', () {
      // 退出してもlocations/{uid}は消さないので、古い値が残っている。
      final scans = clueBssidRssiByUid(
        locations: [
          _location('alice', _scan(hotspotBssid: _aliceHotspot)),
          _location('bob', _scan(hotspotBssid: _bobHotspot)),
        ],
        users: const [
          RoomUser(id: 'alice'),
          RoomUser(id: 'bob', online: false),
        ],
      );

      expect(scans['alice'], {_fixedAp: -60, _bobHotspot: -50});
    });

    test('ルームの参加者がまだ届いていなければ、全員分で除く', () {
      final scans = clueBssidRssiByUid(
        locations: [
          _location('alice', _scan(hotspotBssid: _aliceHotspot)),
          _location('bob', _scan(hotspotBssid: _bobHotspot)),
        ],
        users: null,
      );

      expect(scans['alice'], {_fixedAp: -60});
    });

    test('誰も共有していなければ、スキャン結果をそのまま使う', () {
      final scans = clueBssidRssiByUid(
        locations: [_location('alice', _scan())],
        users: const [RoomUser(id: 'alice')],
      );

      expect(scans['alice'], _scan().bssidRssi);
    });

    test('スキャン結果がまだ無い人は含めない', () {
      final scans = clueBssidRssiByUid(
        locations: [_location('alice', _scan()), _location('bob', null)],
        users: const [
          RoomUser(id: 'alice'),
          RoomUser(id: 'bob'),
        ],
      );

      expect(scans.keys, ['alice']);
    });
  });
}
