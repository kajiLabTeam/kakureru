import 'package:kakureru/features/room/model/room_user.dart';

/// 直前の参加者一覧(previous)と最新の参加者一覧(current)を比較し、
/// 離脱した(leftAtが新たに立った、またはcurrentから消えた)ユーザーを返す。
///
/// RoomRepository.leaveRoomはusers/{uid}を消さずleftAtを立てるだけの
/// ソフト離脱なので、通常はleftAtの新規発生で検出する。usersから完全に
/// 消えるケース(将来の実装・手動操作等)も互換のため合わせて検出する。
///
/// 離脱後の表示名はcurrent側から分からない場合があるため、previous側の
/// RoomUserをそのまま返す。
List<RoomUser> detectLeftUsers({
  required List<RoomUser> previous,
  required List<RoomUser> current,
}) {
  final currentById = {for (final u in current) u.id: u};
  return previous.where((prevUser) {
    final currentUser = currentById[prevUser.id];
    if (currentUser == null) return true;
    return !prevUser.hasLeft && currentUser.hasLeft;
  }).toList();
}

/// 直前の参加者一覧(previous)と最新の参加者一覧(current)を比較し、
/// 猶予時間内に復帰した(leftAtが消えた)ユーザーを返す。
List<RoomUser> detectRejoinedUsers({
  required List<RoomUser> previous,
  required List<RoomUser> current,
}) {
  final previousById = {for (final u in previous) u.id: u};
  return current.where((currentUser) {
    final prevUser = previousById[currentUser.id];
    if (prevUser == null) return false;
    return prevUser.hasLeft && !currentUser.hasLeft;
  }).toList();
}
