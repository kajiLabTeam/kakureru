/// ミッションのお知らせ(出た・のこり1分・終わった)を、いつ・何と出すかの
/// 純粋な計算。出し方(バナー/OSの通知/振動)は`MissionController`が決める。
library;

import 'package:kakureru/features/location/model/user_location.dart';
import 'package:kakureru/features/mission/mission_rules.dart';
import 'package:kakureru/features/mission/mission_timing.dart';
import 'package:kakureru/features/mission/model/mission.dart';
import 'package:kakureru/features/mission/model/mission_notice.dart';

/// 「出た」のお知らせの文言。
///
/// 例: 「アクセスポイントへ行こう。5分以内、先着2人。近いのは 62m 先」
/// 位置がまだ無ければ距離は付けない。
String missionCreatedMessage(Mission mission, {UserLocation? location}) {
  final head =
      'アクセスポイントへ行こう。${missionTimeLimit.inMinutes}分以内、'
      '先着${mission.spots.length}人';
  final spot = nearestOpenSpot(mission, location);
  final distance = readAccessPoint(spot: spot, location: location).distanceM;
  if (distance == null) return head;
  return '$head。近いのは ${distance.round()}m 先';
}

/// 「のこり1分」のお知らせの文言。例: 「まだ1つ空いている」
String missionOneMinuteLeftMessage(Mission mission) =>
    'のこり${missionLastMinuteWarning.inMinutes}分。'
    'まだ${openSpots(mission).length}つ空いている';

/// 「終わった」のお知らせの文言。例: 「こうき と みお が ごほうび を引いた」
/// 誰も取れなかったら時間切れと伝える。
String missionFinishedMessage(
  Mission mission, {
  required String Function(String uid) nameOf,
}) {
  final names = [
    for (final spot in mission.spots)
      if (spot.claimedBy case final uid?) nameOf(uid),
  ];
  if (names.isEmpty) return 'アクセスポイントは時間切れ。だれも取れなかった';
  return '${names.join(' と ')} が ごほうび を引いた';
}

/// いま出すべきお知らせ。[notified]に入っているキーは出さない。
///
/// - 出た: 受けられる間、かつ「のこり1分」になる前
/// - のこり1分: 期限の[missionLastMinuteWarning]前から期限まで、空きがある間
/// - 終わった: 終わってから[missionFinishedNoticeGrace]の間だけ
///   (入り直したときに、ずっと前に終わったものを今さら知らせない)
///
/// [mission]は今のゲームの最新1件(`missionsOfCurrentGame(...).last`)。
List<MissionNotice> dueMissionNotices({
  required Mission? mission,
  required int nowMillis,
  required Set<String> notified,
  required UserLocation? location,
  required String Function(String uid) nameOf,
}) {
  if (mission == null || nowMillis < mission.createdAt) return const [];
  final warnAt = mission.expiresAt - missionLastMinuteWarning.inMilliseconds;
  final active = isMissionActive(mission, nowMillis: nowMillis);
  final endedAt = missionEndedAt(mission);
  final candidates = <MissionNotice>[
    if (active && nowMillis < warnAt)
      MissionNotice(
        kind: MissionNoticeKind.created,
        missionId: mission.id,
        message: missionCreatedMessage(mission, location: location),
      ),
    if (active && nowMillis >= warnAt)
      MissionNotice(
        kind: MissionNoticeKind.oneMinuteLeft,
        missionId: mission.id,
        message: missionOneMinuteLeftMessage(mission),
      ),
    if (!active &&
        nowMillis >= endedAt &&
        nowMillis < endedAt + missionFinishedNoticeGrace.inMilliseconds)
      MissionNotice(
        kind: MissionNoticeKind.finished,
        missionId: mission.id,
        message: missionFinishedMessage(mission, nameOf: nameOf),
      ),
  ];
  return [
    for (final notice in candidates)
      if (!notified.contains(notice.key)) notice,
  ];
}
