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

/// 通知の本文。新しい写真[photos]を撮った人の名前を「さん」付けで並べる。
///
/// 同じ人が続けて撮っても名前は1回だけ出す。同一人物かどうかは名前では
/// なくuidで判断する(同じ名前の別人を1人にまとめてしまわないため)。
/// 参加者一覧[users]に見つからない人は「誰か」と出す。
String photoTakenMessage(List<RoomPhoto> photos, List<RoomUser> users) {
  final uids = <String>{for (final photo in photos) photo.uid};
  final names = [for (final uid in uids) '${_displayNameOf(users, uid)}さん'];
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
  // 役割と名前を引くためのルーム。他に購読している人がいないと値が
  // 読めないので、自分でもwatchして購読を保つ。値そのものは、写真が届いた
  // 時点の最新をコールバックの中で読む(buildの時点の値をとっておくと、
  // ルームと写真が同時に届いたとき古い役割で判定してしまうため)。
  ref.watch(roomStreamProvider(roomId));

  // 写真の一覧がすでに読み込まれている(写真タブで先に購読していた等)と、
  // ref.listenはその値では呼ばれず、次の更新が基準になってしまう。そこで
  // 増えた写真を見落とさないよう、読み込み済みの一覧を先に基準にする。
  // まだ読み込み中ならnullのままで、最初に届いた一覧が基準になる。
  previousIds.value ??= ref
      .read(photosStreamProvider(roomId))
      .value
      ?.map((photo) => photo.id)
      .toSet();

  ref.listen(photosStreamProvider(roomId), (prev, next) {
    final photos = next.value;
    if (photos == null) return;

    final users = ref.read(roomStreamProvider(roomId)).value?.users ?? const [];
    final newPhotos = photosToNotify(
      previousIds: previousIds.value,
      photos: photos,
      myUid: myUid,
      myRole: roleOf(users, myUid),
    );
    previousIds.value = {for (final photo in photos) photo.id};
    if (newPhotos.isEmpty) return;

    final message = photoTakenMessage(newPhotos, users);
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
