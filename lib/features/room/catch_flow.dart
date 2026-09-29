import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/utils/local_notifications.dart';
import 'package:kakureru/core/utils/server_time.dart';
import 'package:kakureru/features/room/catch_rules.dart';
import 'package:kakureru/features/room/model/room_catch.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/role_theme.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// 捕まった本人の端末で、鬼が書いた捕獲を自分の役割に反映するフック(issue #140)。
///
/// `users/{uid}`は本人しか書けないため、鬼の「捕まえた」は`catches`に書かれる
/// だけで、役割のDEMONへの書き換えはここで行う(`acceptCaught`)。失敗したら
/// 少し待って再試行する(捕まったのに逃走者のまま残るのを防ぐ)。
///
/// 戻り値の`shownCatch`は「あなたは鬼になった」の全画面に出す捕獲。
/// 受け入れを試みた捕獲のうち最新のもので、本人が閉じるか、取り消しで
/// `catches`から消えるとnullになる。
({RoomCatch? shownCatch, VoidCallback dismiss}) useCaughtByDemon(
  WidgetRef ref, {
  required String roomId,
  required String? myUid,
}) {
  final catches = ref.watch(catchesStreamProvider(roomId)).value ?? const [];
  final room = ref.watch(roomStreamProvider(roomId)).value;
  final myRole = room?.users.where((u) => u.id == myUid).firstOrNull?.role;

  final toAccept = catchToAcceptAsCaught(
    catches: catches,
    myUid: myUid,
    myRole: myRole,
    startedAt: room?.startedAt,
  );

  // 受け入れを試みた捕獲のid。全画面を出す対象を決めるのに使う。
  // 画面が消えたら一緒に消えてよい一時状態なのでhooksで持つ。
  final acceptedIds = useRef(<String>{});
  final dismissedIds = useState(const <String>{});
  final retryTick = useState(0);
  if (toAccept != null) acceptedIds.value.add(toAccept.id);

  useEffect(() {
    if (toAccept == null) return null;
    var disposed = false;
    Future<void> accept() async {
      try {
        await ref.read(roomRepositoryProvider).acceptCaught(roomId);
      } on Object catch (e) {
        debugPrint('[Catch] 鬼への切り替えに失敗: $e');
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!disposed) retryTick.value++;
      }
    }

    unawaited(accept());
    return () {
      disposed = true;
    };
  }, [toAccept?.id, retryTick.value]);

  final mine = catchesOfCurrentGame(
    catches,
    startedAt: room?.startedAt,
  ).where((c) => c.fugitiveUserId == myUid);
  RoomCatch? shown;
  for (final c in mine) {
    if (acceptedIds.value.contains(c.id) &&
        !dismissedIds.value.contains(c.id)) {
      shown = c;
    }
  }
  final shownId = shown?.id;

  return (
    shownCatch: shown,
    dismiss: () {
      if (shownId == null) return;
      dismissedIds.value = {...dismissedIds.value, shownId};
    },
  );
}

/// 取り消しの期限を過ぎた捕獲を全員に「AがBを捕まえた」と知らせるフック(issue #140)。
///
/// 期限内に知らせると、取り消されたときに撤回することになるため、
/// [catchesToAnnounce]で**期限を過ぎたものだけ**を拾う。期限は時間で
/// 過ぎるので、`catches`の変化ではなく1秒ごとのタイマーで判定する。
///
/// 画面に入った時点で既に期限を過ぎている捕獲は知らせない(入り直すたびに
/// 古い通知が出ないようにするため)。
///
/// 戻り値の`announced`は地図の上に出すカードの対象。数秒で自動的に消える。
({RoomCatch? announced, VoidCallback dismiss}) useCatchAnnouncements(
  WidgetRef ref, {
  required String roomId,
  required String? myUid,
  Duration visibleFor = const Duration(seconds: 6),
}) {
  // 購読を保つためにwatchする(タイマーの中ではreadで読むため)。
  ref.watch(catchesStreamProvider(roomId));
  final announcedIds = useRef<Set<String>?>(null);
  final announced = useState<RoomCatch?>(null);
  final hideTimer = useRef<Timer?>(null);

  useEffect(() {
    final timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final catchesAsync = ref.read(catchesStreamProvider(roomId));
      final room = ref.read(roomStreamProvider(roomId)).value;
      if (!catchesAsync.hasValue || room == null) return;
      final offset = ref.read(serverTimeOffsetProvider).value ?? 0;
      final nowMillis = serverNowMillis(offset);
      final current = catchesOfCurrentGame(
        catchesAsync.value!,
        startedAt: room.startedAt,
      );

      final seen = announcedIds.value;
      if (seen == null) {
        announcedIds.value = {
          for (final c in catchesToAnnounce(
            announcedIds: const {},
            catches: current,
            nowMillis: nowMillis,
          ))
            c.id,
        };
        return;
      }
      final toAnnounce = catchesToAnnounce(
        announcedIds: seen,
        catches: current,
        nowMillis: nowMillis,
      );
      if (toAnnounce.isEmpty) return;
      for (final c in toAnnounce) {
        seen.add(c.id);
        unawaited(
          showCatchNotification(catchAnnouncementText(room.users, c, myUid)),
        );
      }
      announced.value = toAnnounce.last;
      hideTimer.value?.cancel();
      hideTimer.value = Timer(visibleFor, () => announced.value = null);
    });
    return () {
      timer.cancel();
      hideTimer.value?.cancel();
    };
  }, [roomId]);

  return (
    announced: announced.value,
    dismiss: () {
      hideTimer.value?.cancel();
      announced.value = null;
    },
  );
}

/// 「AがBを捕まえた」の文言。自分は「あなた」にする。
String catchAnnouncementText(
  List<RoomUser> users,
  RoomCatch roomCatch,
  String? myUid,
) {
  final demon = catchDisplayName(users, roomCatch.demonUserId, myUid);
  final fugitive = catchDisplayName(users, roomCatch.fugitiveUserId, myUid);
  return '$demon が $fugitive を捕まえた';
}

/// 捕獲の通知に出す名前。自分なら「あなた」、見つからなければ「誰か」。
String catchDisplayName(List<RoomUser> users, String? uid, String? myUid) {
  if (uid == null) return '誰か';
  if (uid == myUid) return 'あなた';
  for (final user in users) {
    if (user.id == uid && user.displayName.isNotEmpty) return user.displayName;
  }
  return '誰か';
}

/// 自分(鬼)が報告した捕獲が取り消されたら、SnackBarで知らせるフック(issue #140)。
void useCatchUndoneNotifications(
  WidgetRef ref,
  BuildContext context, {
  required String roomId,
  required String? myUid,
}) {
  ref.listen(catchesStreamProvider(roomId), (prev, next) {
    final previous = prev?.value;
    final current = next.value;
    if (previous == null || current == null) return;
    final undone = undoneCatchesOf(
      previous: previous,
      current: current,
      myUid: myUid,
    );
    if (undone.isEmpty) return;
    final users = ref.read(roomStreamProvider(roomId)).value?.users ?? const [];
    final demonTheme = roleThemeOf(UserRole.demon);
    for (final c in undone) {
      final name = catchDisplayName(users, c.fugitiveUserId, myUid);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: demonTheme.color,
          content: Row(
            children: [
              const Icon(Icons.undo, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$nameが捕獲を取り消しました',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  });
}
