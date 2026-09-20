import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/utils/local_notifications.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/room/role_visibility.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';
import 'package:vibration/vibration.dart';

/// 鬼放出の瞬間に一度だけ端末を振動させ、通知も出すフック。
///
/// ポケットに入れたまま遊ぶ運用のため、振動だけだと画面を見ていないと
/// 気づけない。
///
/// [tick] には毎秒更新されるカウンタを渡すこと。releasedAt 自体は変化
/// しないため、これが無いと releasedAt が確定した最初の一瞬しか判定
/// されない。
void useDemonReleaseNotification({
  required int? releasedAt,
  required int serverTimeOffset,
  required int tick,
}) {
  final hasNotified = useRef(false);
  useEffect(() {
    if (releasedAt == null || hasNotified.value) return null;
    if (serverNowMillis(serverTimeOffset) >= releasedAt) {
      hasNotified.value = true;
      Vibration.hasVibrator().then((hasVibrator) {
        if (hasVibrator) Vibration.vibrate(duration: 800);
      });
      showDemonReleasedNotification();
    }
    return null;
  }, [releasedAt, tick]);
}

/// 誰かがDEMONになったら(ホストの指名受諾・自己申告どちらでも)SnackBarで
/// 全員に知らせるフック。
///
/// 表示制御(役割による可視性)とは別軸の情報のため、見える/見えないに
/// 関わらず通知する。自分自身が鬼になった場合は除く(GamePage側が
/// CaughtTransitionOverlayの全画面演出を出すため。issue #15)。
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
      final demonTheme = roleThemeOf(UserRole.demon);
      final uidsToNotify = uidsToNotifyOfDemonChange(
        previousDemonUids: previous,
        currentDemonUids: currentDemonUids,
        myUid: myUid,
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
