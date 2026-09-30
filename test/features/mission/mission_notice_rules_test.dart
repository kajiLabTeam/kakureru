import 'package:flutter_test/flutter_test.dart';
import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/mission/mission_notice_rules.dart';
import 'package:kakureru/features/mission/mission_timing.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/mission/model/mission_notice.dart';

const _created = 1000000;
final int _expires = _created + missionTimeLimit.inMilliseconds;

Mission _mission({List<MissionSpot>? spots, int? finishedAt}) => Mission(
  id: 'm1',
  round: 1,
  createdAt: _created,
  expiresAt: _expires,
  finishedAt: finishedAt,
  spots:
      spots ??
      const [
        MissionSpot(id: 's0', lat: 35, lng: 137, radiusM: 15),
        MissionSpot(id: 's1', lat: 35.01, lng: 137, radiusM: 15),
      ],
);

String _nameOf(String uid) => switch (uid) {
  'a' => 'こうき',
  'b' => 'みお',
  _ => uid,
};

List<MissionNotice> _due(
  Mission? mission,
  int now, {
  Set<String> notified = const {},
  UserLocation? location,
}) => dueMissionNotices(
  mission: mission,
  nowMillis: now,
  notified: notified,
  location: location,
  nameOf: _nameOf,
);

void main() {
  group('文言', () {
    test('出た: 制限時間と先着の人数、近い地点までの距離', () {
      expect(
        missionCreatedMessage(_mission()),
        'アクセスポイントへ行こう。5分以内、先着2人',
      );
      final message = missionCreatedMessage(
        _mission(),
        location: const UserLocation(
          uid: 'me',
          latitude: 35.0005,
          longitude: 137,
          accuracy: 5,
        ),
      );
      expect(message, startsWith('アクセスポイントへ行こう。5分以内、先着2人。近いのは '));
      expect(message, endsWith('m 先'));
    });

    test('のこり1分: 空いている数', () {
      final mission = _mission(
        spots: const [
          MissionSpot(id: 's0', lat: 35, lng: 137, radiusM: 15, claimedBy: 'a'),
          MissionSpot(id: 's1', lat: 35.01, lng: 137, radiusM: 15),
        ],
      );
      expect(missionOneMinuteLeftMessage(mission), 'のこり1分。まだ1つ空いている');
    });

    test('終わった: 取った人の名前。誰もいなければ時間切れ', () {
      final mission = _mission(
        spots: const [
          MissionSpot(id: 's0', lat: 35, lng: 137, radiusM: 15, claimedBy: 'a'),
          MissionSpot(
            id: 's1',
            lat: 35.01,
            lng: 137,
            radiusM: 15,
            claimedBy: 'b',
          ),
        ],
      );
      expect(
        missionFinishedMessage(mission, nameOf: _nameOf),
        'こうき と みお が ごほうび を引いた',
      );
      expect(
        missionFinishedMessage(_mission(), nameOf: _nameOf),
        'アクセスポイントは時間切れ。だれも取れなかった',
      );
    });
  });

  group('dueMissionNotices', () {
    test('ミッションが無い・まだ出ていなければ何も出さない', () {
      expect(_due(null, _created), isEmpty);
      expect(_due(_mission(), _created - 1), isEmpty);
    });

    test('出た直後は「出た」だけ', () {
      final notices = _due(_mission(), _created + 1000);
      expect(notices.map((n) => n.kind), [MissionNoticeKind.created]);
    });

    test('のこり1分になったら「のこり1分」', () {
      final warnAt = _expires - missionLastMinuteWarning.inMilliseconds;
      expect(
        _due(_mission(), warnAt).map((n) => n.kind),
        [MissionNoticeKind.oneMinuteLeft],
      );
    });

    test('期限が切れたら「終わった」。しばらくたったら今さら出さない', () {
      expect(
        _due(_mission(), _expires).map((n) => n.kind),
        [MissionNoticeKind.finished],
      );
      expect(
        _due(
          _mission(),
          _expires + missionFinishedNoticeGrace.inMilliseconds,
        ),
        isEmpty,
      );
    });

    test('すべて取られて早く終わったら、その時点で「終わった」', () {
      const finishedAt = _created + 60000;
      final mission = _mission(
        finishedAt: finishedAt,
        spots: const [
          MissionSpot(id: 's0', lat: 35, lng: 137, radiusM: 15, claimedBy: 'a'),
          MissionSpot(
            id: 's1',
            lat: 35.01,
            lng: 137,
            radiusM: 15,
            claimedBy: 'b',
          ),
        ],
      );
      final notices = _due(mission, finishedAt + 1000);
      expect(notices.map((n) => n.kind), [MissionNoticeKind.finished]);
      expect(notices.single.message, 'こうき と みお が ごほうび を引いた');
    });

    test('一度出したお知らせは二度出さない', () {
      final first = _due(_mission(), _created + 1000).single;
      expect(
        _due(_mission(), _created + 2000, notified: {first.key}),
        isEmpty,
      );
    });
  });
}
