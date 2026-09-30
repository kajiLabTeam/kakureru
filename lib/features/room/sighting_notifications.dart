import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/utils/local_notifications.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/model/sighting.dart';
import 'package:kakureru/features/room/sighting_rules.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// 鬼に知らせる、新しく撮られた目撃写真。
///
/// 足元の写真の通知(`photosToNotify`)と同じ判定にする:
/// - 基準([previousIds]。最初に届いた一覧)ができるまでは出さない
///   (画面に入った時点で既にある写真を、まとめて通知しないため)
/// - 自分が鬼のときだけ出す(鬼全員に出す。どの鬼が写っているかは記録
///   していないため)
/// - 自分が撮ったものは出さない
///
/// [sightings]は今のゲームのものに絞ってから渡すこと
/// ([sightingsOfCurrentGame])。
List<Sighting> sightingsToNotify({
  required Set<String>? previousIds,
  required List<Sighting> sightings,
  required String? myUid,
  required UserRole? myRole,
}) {
  if (previousIds == null) return const [];
  if (myRole != UserRole.demon) return const [];
  return [
    for (final sighting in sightings)
      if (!previousIds.contains(sighting.id) && sighting.uid != myUid) sighting,
  ];
}

/// 通知とSnackBarの文言。撮った人が複数なら「、」でつなぐ。
String sightingTakenMessage(List<Sighting> sightings, List<RoomUser> users) {
  final uids = <String>{for (final sighting in sightings) sighting.uid};
  final names = [
    for (final uid in uids) '${findUser(users, uid)?.displayName ?? '誰か'}さん',
  ];
  return '${names.join('、')}が鬼の写真を撮りました';
}

/// 鬼のとき、逃走者が目撃写真を撮ったら端末通知とSnackBarで知らせるフック。
///
/// 作りは足元の写真の通知(`usePhotoTakenNotifications`)と同じ。
void useSightingTakenNotifications(
  WidgetRef ref,
  BuildContext context, {
  required String roomId,
  required String? myUid,
}) {
  final previousIds = useRef<Set<String>?>(null);

  // 届いている一覧とルームで判定する。写真の一覧とルームは別々の購読なので、
  // どちらが先に届いても取りこぼさないよう、両方の更新から呼ぶ。
  void evaluate() {
    final all = ref.read(sightingsStreamProvider(roomId)).value;
    if (all == null) return;
    final ids = {for (final sighting in all) sighting.id};

    final room = ref.read(roomStreamProvider(roomId)).value;
    if (room == null) {
      // ルームがまだ届いていない(役割が分からない)間は基準を進めない。
      // 進めると、その間に撮られた写真が「もう見た」扱いになり、ルームが
      // 届いた後も通知されない。最初に届いた一覧だけは基準にする(画面に
      // 入った時点で既にある写真は通知しない)。
      previousIds.value ??= ids;
      return;
    }

    final users = room.users;
    final newSightings = sightingsToNotify(
      previousIds: previousIds.value,
      sightings: sightingsOfCurrentGame(all, startedAt: room.startedAt),
      myUid: myUid,
      myRole: roleOf(users, myUid),
    );
    previousIds.value = ids;
    if (newSightings.isEmpty) return;

    final message = sightingTakenMessage(newSightings, users);
    // 画面OFF・バックグラウンドでも気づけるよう、端末通知は必ず出す。
    unawaited(showSightingTakenNotification(message));
    // 画面を見ているときはSnackBarでも出す(別の画面を上に開いているときは
    // 出さない。usePhotoTakenNotificationsと同じガード)。
    if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ルームの購読を保つ(値は判定の時点の最新を読む)。
  ref.watch(roomStreamProvider(roomId));

  // 一覧がすでに読み込まれていると、ref.listenはその値では呼ばれない。
  // 増えた写真を見落とさないよう、読み込み済みの一覧を先に基準にする。
  previousIds.value ??= ref
      .read(sightingsStreamProvider(roomId))
      .value
      ?.map((sighting) => sighting.id)
      .toSet();

  ref
    ..listen(sightingsStreamProvider(roomId), (_, _) => evaluate())
    // ルームが写真より後に届いたとき、その間に撮られた写真をここで知らせる。
    ..listen(roomStreamProvider(roomId), (_, _) => evaluate());
}
