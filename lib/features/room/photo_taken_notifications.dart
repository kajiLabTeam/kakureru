import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/utils/local_notifications.dart';
import 'package:kakureru/features/room/model/room_photo.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// 撮影タイミングの通知(「足元の写真を撮ってください」)を出すか。
///
/// 鬼は撮影しないので出さない(issue #120)。役割がまだ分からない間は、
/// 逃走者が気づけないほうが困るので出す。
bool shouldNotifyPhotoCaptureDue(UserRole? role) => role != UserRole.demon;

/// 新しく撮られた写真のうち、鬼である自分に知らせるべきものを返す
/// (issue #120)。
///
/// - [previousIds]がnull(最初に一覧を受け取ったとき)は何も知らせない。
///   途中参加やアプリの再起動で、過去の写真をまとめて知らせないため
/// - 自分が鬼でなければ知らせない
/// - 自分が撮った写真は知らせない
List<RoomPhoto> photosToNotify({
  required Set<String>? previousIds,
  required List<RoomPhoto> photos,
  required String? myUid,
  required UserRole? myRole,
}) {
  if (previousIds == null) return const [];
  if (myRole != UserRole.demon) return const [];
  return [
    for (final photo in photos)
      if (!previousIds.contains(photo.id) && photo.uid != myUid) photo,
  ];
}

/// 通知の本文。撮った人の名前を「さん」付けで並べる。
///
/// 同じ人が続けて撮っても名前は1回だけ出す。
String photoTakenMessage(List<String> displayNames) {
  final names = <String>{for (final name in displayNames) '$nameさん'};
  return '${names.join('、')}が足元の写真を撮りました';
}

/// 逃走者が写真を撮ったら、鬼の端末に通知とSnackBarで知らせるフック
/// (issue #120)。
///
/// 直前に見た写真のIDをuseRefで持ち、増えた分だけを知らせる。この
/// ウィジェットが破棄されたら追跡もやめてよい一時状態なのでhooksで持つ
/// (AGENTS.mdの状態管理規約、`useLeftUserNotifications`と同じ形)。
void usePhotoTakenNotifications(
  WidgetRef ref,
  BuildContext context, {
  required String roomId,
  required String? myUid,
}) {
  final previousIds = useRef<Set<String>?>(null);
  // 役割と名前を引くための参加者一覧。listenのコールバックで`ref.read`
  // すると、他に購読している人がいないとき値がまだ無い。自分でwatchして
  // 最新の一覧をrefに入れておく。
  final latestUsers = useRef<List<RoomUser>>(const []);
  latestUsers.value =
      ref.watch(roomStreamProvider(roomId)).value?.users ?? latestUsers.value;

  ref.listen(photosStreamProvider(roomId), (prev, next) {
    final photos = next.value;
    if (photos == null) return;

    final users = latestUsers.value;
    final newPhotos = photosToNotify(
      previousIds: previousIds.value,
      photos: photos,
      myUid: myUid,
      myRole: roleOf(users, myUid),
    );
    previousIds.value = {for (final photo in photos) photo.id};
    if (newPhotos.isEmpty) return;

    final message = photoTakenMessage([
      for (final photo in newPhotos) _displayNameOf(users, photo.uid),
    ]);
    // 画面OFF・バックグラウンドでも気づけるよう、端末通知は必ず出す。
    unawaited(showPhotoTakenNotification(message));
    // 画面を見ているときはSnackBarでも出す。写真の拡大表示など別の画面を
    // 上に開いているときは出さない(useLeftUserNotificationsと同じガード)。
    if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  });
}

/// 通知文に出す名前。参加者一覧に見つからなければ「誰か」で代替する。
String _displayNameOf(List<RoomUser> users, String uid) {
  for (final user in users) {
    if (user.id == uid) return user.displayName;
  }
  return '誰か';
}
