import 'package:kakureru/features/room/model/room_user.dart';

/// 直前の参加者一覧(previous)と最新の参加者一覧(current)を比較し、
/// 離脱した(currentから消えた)ユーザーを返す。
///
/// 離脱後の表示名は消えた側からは分からないため、previous側の
/// RoomUserをそのまま返す。
List<RoomUser> detectLeftUsers({
  required List<RoomUser> previous,
  required List<RoomUser> current,
}) {
  final currentIds = current.map((u) => u.id).toSet();
  return previous.where((u) => !currentIds.contains(u.id)).toList();
}
