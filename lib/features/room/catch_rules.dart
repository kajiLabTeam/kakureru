import 'package:kakureru/features/ble/model/ble_detection.dart';
import 'package:kakureru/features/ble/repository/ble_proximity_calculator.dart';
import 'package:kakureru/features/room/model/catch_photo.dart';
import 'package:kakureru/features/room/model/room_catch.dart';
import 'package:kakureru/features/room/model/room_user.dart';

/// 捕まった側が「取り消す」を押せる時間。**この期限の定義はここ1か所だけ**。
///
/// 次の3つがすべてこの値を基準に動く(issue #140)。
/// - 逃走者の画面の「取り消す」ボタンと「あと N秒」の表示([isCatchUndoable])
/// - 取り消しの書き込み前の最終確認(`RoomRepository.undoCatch`。サーバー時刻で判定)
/// - 全員への「AがBを捕まえた」通知の遅延([catchesToAnnounce])
///
/// 起点はRTDBの`catches/{catchId}/caughtAt`(鬼が確定した瞬間のサーバー時刻)。
/// 端末ごとの時計のずれで期限が人によって変わらないよう、比較する「今」も
/// 必ずサーバー時刻(`serverNowMillis`)を渡すこと。
const catchUndoWindow = Duration(seconds: 10);

/// 取り消せる期限(サーバー時刻のエポックミリ秒)。この時刻ちょうどからは取り消せない。
int catchUndoDeadline(int caughtAt) =>
    caughtAt + catchUndoWindow.inMilliseconds;

/// まだ取り消せるか。
bool isCatchUndoable({required int caughtAt, required int nowMillis}) =>
    nowMillis < catchUndoDeadline(caughtAt);

/// 取り消せる残り秒数(切り上げ)。期限を過ぎていれば0。
int catchUndoRemainingSeconds({required int caughtAt, required int nowMillis}) {
  final remaining = catchUndoDeadline(caughtAt) - nowMillis;
  if (remaining <= 0) return 0;
  return (remaining / 1000).ceil();
}

/// BLEで3m以内にいる逃走者のuid一覧。近い順に並べる。
///
/// 鬼は対象外(既に捕まっている人を2度捕まえられないようにする)。自分自身も
/// 除く。[detections]は短縮uid→直近の検知結果(`bleViewModelProvider`)。
/// 検知時刻は端末時計なので、[nowMillis]も端末時計で渡すこと。
List<String> fugitivesWithinCatchRange({
  required Map<String, BleDetection> detections,
  required List<RoomUser> users,
  required String? myUid,
  required int nowMillis,
}) {
  final inRange = <({String uid, double distance})>[];
  for (final user in users) {
    if (user.id == myUid || user.role != UserRole.fugitive) continue;
    final detection = detections[shortenUid(user.id)];
    if (detection == null) continue;
    if (!isDetectionFresh(
      detectedAtMillis: detection.detectedAtMillis,
      nowMillis: nowMillis,
    )) {
      continue;
    }
    final distance = estimateDistanceMeters(detection.rssiDbm);
    if (!isWithinCatchRange(distance)) continue;
    inRange.add((uid: user.id, distance: distance));
  }
  inRange.sort((a, b) => a.distance.compareTo(b.distance));
  return [for (final entry in inRange) entry.uid];
}

/// 捕まえた相手の選択シートで、最初から選んでおく相手。
/// 候補が1人だけのときだけその人を選ぶ(2人以上なら選び間違いを避けて空)。
String? preselectedCatchTarget(List<String> candidateUids) =>
    candidateUids.length == 1 ? candidateUids.single : null;

/// 今のゲームの捕獲だけを、捕まえた順(古い順)に返す。
///
/// 「同じメンバーでもう一回」(`restartRoom`)は`catches`を消さないため、
/// 前のゲームの捕獲が残っている。[startedAt]より前のものを除かないと、
/// 次のゲームの開始直後に前回捕まった人がまた鬼になってしまう。
/// [startedAt]がnull(開始前)なら空。
List<RoomCatch> catchesOfCurrentGame(
  List<RoomCatch> catches, {
  required int? startedAt,
}) {
  if (startedAt == null) return const [];
  return catches.where((c) => c.caughtAt >= startedAt).toList()
    ..sort((a, b) => a.caughtAt.compareTo(b.caughtAt));
}

/// 自分が捕まった捕獲のうち、まだ自分の役割に反映していないもの。
///
/// `users/{uid}`は本人しか書けないため、鬼が`catches`に書いた捕獲を
/// 捕まった本人の端末が見つけて、自分の役割をDEMONに書き換える。
/// 既に鬼なら反映済み(または別の経路で鬼になった)なのでnull。
///
/// [myBecameDemonAt]が捕獲の`caughtAt`以降なら、その捕獲は反映済みとみなす。
/// 役割だけFUGITIVEに戻された人が、残っている同じ捕獲を見つけて再び鬼に
/// ならないようにするため(PRレビュー1)。反映済みかどうかを端末の中の記憶
/// ではなくRTDBの値で決めるので、画面を作り直しても変わらない。
RoomCatch? catchToAcceptAsCaught({
  required List<RoomCatch> catches,
  required String? myUid,
  required UserRole? myRole,
  required int? startedAt,
  int? myBecameDemonAt,
}) {
  if (myUid == null || myRole != UserRole.fugitive) return null;
  final mine = catchesOfCurrentGame(
    catches,
    startedAt: startedAt,
  ).where((c) => c.fugitiveUserId == myUid);
  if (mine.isEmpty) return null;
  final latest = mine.last;
  if (myBecameDemonAt != null && myBecameDemonAt >= latest.caughtAt) {
    return null;
  }
  return latest;
}

/// 全員に「AがBを捕まえた」と知らせる捕獲。
///
/// **取り消しの期限を過ぎたものだけ**を返す。期限内に知らせると、取り消された
/// ときに「捕まえた」と知らせた後で撤回することになるため。取り消された捕獲は
/// `catches`から消えるので、ここには出てこない。[announcedIds]は知らせ済みの
/// catchId。[nowMillis]はサーバー時刻。
List<RoomCatch> catchesToAnnounce({
  required Set<String> announcedIds,
  required List<RoomCatch> catches,
  required int nowMillis,
}) {
  return [
    for (final c in catches)
      if (!announcedIds.contains(c.id) &&
          !isCatchUndoable(caughtAt: c.caughtAt, nowMillis: nowMillis))
        c,
  ];
}

/// 自分(鬼)が報告した捕獲のうち、前回あって今回消えたもの(=取り消された)。
///
/// `catches`から消えるのは捕まった側の「取り消す」だけなので、消えたことを
/// もって取り消しとみなす。
List<RoomCatch> undoneCatchesOf({
  required List<RoomCatch> previous,
  required List<RoomCatch> current,
  required String? myUid,
}) {
  final currentIds = {for (final c in current) c.id};
  return [
    for (final c in previous)
      if (c.demonUserId == myUid && !currentIds.contains(c.id)) c,
  ];
}

/// 写真タブ・結果画面の「捕まえた瞬間」に並べる写真。新しい順。
///
/// 足元の写真と違い、**見る人が撮ったかどうかに関係なく全員が見られる**。
/// ただし取り消しの期限を過ぎて確定した捕獲の写真だけに絞る(期限内は
/// 取り消されるかもしれず、全員への通知もまだ出していないため)。
/// 捕獲が消えた(取り消された)写真や、前のゲームの写真も出さない。
List<CatchPhoto> catchPhotosForGallery({
  required List<CatchPhoto> catchPhotos,
  required List<RoomCatch> catches,
  required int? startedAt,
  required int nowMillis,
}) {
  final confirmedIds = {
    for (final c in catchesOfCurrentGame(catches, startedAt: startedAt))
      if (!isCatchUndoable(caughtAt: c.caughtAt, nowMillis: nowMillis)) c.id,
  };
  return catchPhotos.where((p) => confirmedIds.contains(p.catchId)).toList()
    ..sort((a, b) => b.takenAt.compareTo(a.takenAt));
}

/// 残っている逃走者の人数。
int remainingFugitiveCount(List<RoomUser> users) =>
    users.where((u) => u.role == UserRole.fugitive).length;
