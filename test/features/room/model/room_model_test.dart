import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_setting.dart';
import 'package:kakureru/features/room/model/room_user.dart';

void main() {
  group('RoomSetting', () {
    test('fromMap parses RTDB-shaped Map<dynamic, dynamic> including gameArea', () {
      final Map<dynamic, dynamic> raw = {
        'gameArea': [
          {'lat': 35.0, 'lng': 139.0},
          {'lat': 35.1, 'lng': 139.1},
        ],
        'releaseWaitSec': 30,
        'gameDurationSec': 900,
        'photoIntervalSec': 120,
        'fugitiveInfoDelaySec': 45,
        'senseDistanceRadiusM': 80,
      };

      final setting = RoomSetting.fromMap(raw);

      expect(setting.gameArea.length, 2);
      expect(setting.gameArea.first.lat, 35.0);
      expect(setting.releaseWaitSec, 30);
      expect(setting.gameDurationSec, 900);
    });

    test('fromMap falls back to defaults for missing fields', () {
      final setting = RoomSetting.fromMap({});
      expect(setting.gameArea, isEmpty);
      expect(setting.releaseWaitSec, 60);
      expect(setting.gameDurationSec, 1800);
    });

    test('toMap excludes updatedAt', () {
      const setting = RoomSetting(updatedAt: 123);
      expect(setting.toMap().containsKey('updatedAt'), isFalse);
    });

    test('toMap serializes gameArea as plain Maps, not raw LatLng instances', () {
      // 回帰テスト: json_serializableのデフォルト(explicitToJson: false)だと
      // ネストしたLatLngがtoJson()されず生のオブジェクトのまま入ってしまい、
      // Firebaseへの書き込みが「invalid argument: instance of '_LatLng'」で
      // 失敗した(build.yamlでexplicit_to_json: trueにして修正)。
      const setting = RoomSetting(
        gameArea: [LatLng(lat: 35.0, lng: 139.0), LatLng(lat: 35.1, lng: 139.1)],
      );

      final map = setting.toMap();
      final gameArea = map['gameArea'] as List;

      expect(gameArea, isNot(isA<List<LatLng>>()));
      for (final entry in gameArea) {
        expect(entry, isA<Map<String, dynamic>>());
      }
      expect(gameArea.first, {'lat': 35.0, 'lng': 139.0});
    });
  });

  group('RoomUser', () {
    test('fromMap injects id from the map key, not from the value', () {
      final Map<dynamic, dynamic> raw = {
        'displayName': 'host',
        'deviceId': 'd1',
        'isHost': true,
        'role': 'DEMON',
        'joinedAt': 10,
      };

      final user = RoomUser.fromMap('uid-1', raw);

      expect(user.id, 'uid-1');
      expect(user.role, UserRole.demon);
      expect(user.isHost, isTrue);
    });

    test('fromMap defaults role to fugitive when missing or unrecognized', () {
      expect(RoomUser.fromMap('u', {}).role, UserRole.fugitive);
      expect(RoomUser.fromMap('u', {'role': 'UNKNOWN'}).role, UserRole.fugitive);
    });

    test('toMap excludes id', () {
      const user = RoomUser(id: 'uid-1', displayName: 'x');
      expect(user.toMap().containsKey('id'), isFalse);
      expect(user.toMap()['displayName'], 'x');
    });
  });

  group('Room', () {
    Map<dynamic, dynamic> buildRoomMap({required String status}) => {
      'meta': {
        'status': status,
        'hostUserId': 'host-uid',
        'roomCode': '1234',
        'createdAt': 100,
      },
      'setting': {'gameDurationSec': 1800},
      'users': {
        'host-uid': {'displayName': 'host', 'isHost': true, 'joinedAt': 1},
        'guest-uid': {'displayName': 'guest', 'isHost': false, 'joinedAt': 2},
      },
    };

    test('fromMap flattens meta and turns users map into a List<RoomUser>', () {
      final room = Room.fromMap('room-1', buildRoomMap(status: 'WAITING'));

      expect(room.id, 'room-1');
      expect(room.hostUserId, 'host-uid');
      expect(room.roomCode, '1234');
      expect(room.setting.gameDurationSec, 1800);
      expect(room.users.map((u) => u.id), containsAll(['host-uid', 'guest-uid']));
    });

    test('fromMap parses PLAYING status correctly', () {
      final room = Room.fromMap('room-1', buildRoomMap(status: 'PLAYING'));
      expect(room.status, RoomStatus.playing);
    });

    test('fromMap parses FINISHED status correctly', () {
      final room = Room.fromMap('room-1', buildRoomMap(status: 'FINISHED'));
      expect(room.status, RoomStatus.finished);
    });

    test('fromMap defaults to waiting for null/unrecognized status', () {
      expect(Room.fromMap('r', buildRoomMap(status: 'WAITING')).status, RoomStatus.waiting);
      expect(Room.fromMap('r', buildRoomMap(status: 'GARBAGE')).status, RoomStatus.waiting);
    });
  });
}
