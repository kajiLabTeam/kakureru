import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/catch_rules.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/room/role_visibility.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// 誰かがDEMONになったら(ホストの指名受諾など)SnackBarで全員に知らせるフック。
///
/// 表示制御(役割による可視性)とは別軸の情報のため、見える/見えないに
/// 関わらず通知する。自分自身が鬼になった場合は除く(GamePage側が
/// 「あなたは鬼になった」の全画面を出すため)。「捕まえた」で鬼になった人も
/// 除く。そちらは取り消しの期限を過ぎてから`useCatchAnnouncements`が
/// 「AがBを捕まえた」として知らせる(issue #140)。
void useDemonChangeNotifications(
  WidgetRef ref,
  BuildContext context, {
  required String roomId,
  required String? myUid,
}) {
  final previousDemonUids = useRef<Set<String>?>(null);
  ref.listen(roomStreamProvider(roomId), (prev, next) {
    final nextRoom = next.value;
    if (nextRoom == null) return;
    final currentDemonUids = nextRoom.users
        .where((u) => u.role == UserRole.demon)
        .map((u) => u.id)
        .toSet();

    final previous = previousDemonUids.value;
    if (previous != null) {
      final caughtUids = {
        for (final c in catchesOfCurrentGame(
          ref.read(catchesStreamProvider(roomId)).value ?? const [],
          startedAt: nextRoom.startedAt,
        ))
          c.fugitiveUserId,
      };
      final demonTheme = roleThemeOf(UserRole.demon);
      final uidsToNotify = uidsToNotifyOfDemonChange(
        previousDemonUids: previous,
        currentDemonUids: currentDemonUids,
        myUid: myUid,
        excludedUids: caughtUids,
      );
      for (final uid in uidsToNotify) {
        final name = _displayNameOf(nextRoom.users, uid);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: demonTheme.color,
            content: Row(
              children: [
                Icon(demonTheme.icon, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$nameが鬼になりました',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    previousDemonUids.value = currentDemonUids;
  });
}

/// 通知文に出す名前。参加者一覧に見つからなければ「誰か」で代替する
/// (離脱直後など、SnackBarを出す瞬間にusersから消えている場合がある)。
String _displayNameOf(List<RoomUser> users, String uid) {
  for (final user in users) {
    if (user.id == uid) return user.displayName;
  }
  return '誰か';
}
