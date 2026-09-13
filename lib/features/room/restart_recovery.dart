import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/core/providers/firebase_providers.dart';
import 'package:kakureru/core/utils/rtdb_write.dart';
import 'package:kakureru/features/room/model/room.dart';
import 'package:kakureru/features/room/model/room_user.dart';
import 'package:kakureru/features/room/view/room_waiting_page.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// 「同じメンバーでもう一回」による巻き戻し(`meta/status` が `PLAYING` から
/// `WAITING` へ変化)を検知し、自分の役割が鬼だった場合は自分でFUGITIVEへ
/// リセットしてから待機画面(`RoomWaitingPage`)へ遷移するフック(issue #44)。
///
/// GameResultPageだけでなくGamePageからも呼ぶ。ホストが結果画面で
/// 「同じメンバーでもう一回」を押した瞬間、他の参加者はまだ`isGameOver`を
/// 検知できておらず`GamePage`に留まっている場合がある(アプリのバック
/// グラウンド化・ネットワーク遅延等)。その状態のまま巻き戻りが起きると、
/// `GamePage`側は`status==waiting`を扱う手段を持たないため画面が固まって
/// しまう。両方の画面から同じ検知ロジックを使うことで、結果画面を経由
/// できなかった端末も待機画面に戻す。
///
/// `users/{uid}` はRTDBのルール上本人しか書き込めないため、ホストが他の
/// 参加者のroleをまとめて戻すことはできない(鬼の決定が`meta/pendingDemonUid`
/// 経由の自己申告方式になっているのと同じ制約。docs/rtdb-schema.md参照)。
/// そのため、各端末が自分でこのフックを通じて役割をリセットする。
void useRestartRecovery(
  WidgetRef ref,
  BuildContext context, {
  required String roomId,
}) {
  final hasHandled = useRef(false);
  ref.listen(roomStreamProvider(roomId), (previous, next) {
    if (hasHandled.value) return;
    final wasPlaying = previous?.value?.status == RoomStatus.playing;
    final room = next.value;
    if (!wasPlaying || room == null || room.status != RoomStatus.waiting) {
      return;
    }
    hasHandled.value = true;

    final myUid = ref.read(myUidProvider);
    final myself = myUid == null ? null : _findUser(room.users, myUid);
    if (myself?.role == UserRole.demon) {
      unawaited(
        writeOrLogFailure(
          () => ref.read(roomRepositoryProvider).resetOwnRoleForRestart(roomId),
          tag: 'useRestartRecovery',
          field: '自分の役割のリセット',
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RoomWaitingPage(roomId: roomId)),
      );
    });
  });
}

RoomUser? _findUser(List<RoomUser> users, String uid) {
  for (final user in users) {
    if (user.id == uid) return user;
  }
  return null;
}
