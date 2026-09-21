import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kakureru/features/room/repository/room_repository.dart';

/// 部屋からの退出(`users/{uid}`・`locations/{uid}`の削除)を投げっぱなしで
/// 走らせる。失敗はログに残すだけで、呼び出し元へは伝えない。
///
/// awaitしないのは、退出の成否で画面が詰まらないようにするため(issue #94)。
/// ユーザーはもう画面を離れる意思を示しているので、RTDBの往復が遅い・失敗する
/// 状況でも戻り道を塞がない。失敗したときに残るのは幽霊参加者であり、
/// それは元々の既知の制約(RoomRepository.leaveRoomのコメント参照)と同じ形。
void leaveRoomInBackground(
  RoomRepository roomRepo,
  String roomId, {
  required String tag,
}) {
  unawaited(
    roomRepo.leaveRoom(roomId).catchError((Object e) {
      debugPrint('[$tag] leaveRoom 失敗: $e');
    }),
  );
}

/// 部屋から退出して、ホーム(最初のルート)まで戻る。
///
/// 退出を待たずに戻すため、退出に失敗しても画面は必ずホームへ戻る。
void leaveRoomAndGoHome(
  BuildContext context,
  RoomRepository roomRepo,
  String roomId, {
  required String tag,
}) {
  leaveRoomInBackground(roomRepo, roomId, tag: tag);
  Navigator.of(context).popUntil((route) => route.isFirst);
}
