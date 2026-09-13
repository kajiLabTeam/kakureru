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

/// 「同じメンバーでもう一回」による巻き戻し(`meta/status` が `WAITING` に
/// 戻っている状態)を検知し、自分の役割が鬼だった場合は自分でFUGITIVEへ
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
  final roomAsync = ref.watch(roomStreamProvider(roomId));

  // 「PLAYING→WAITINGへの変化」という遷移ベース(ref.listen + previous参照)
  // ではなく、「今WAITINGである」という状態ベース(useEffect)で判定する。
  // ref.listenはfireImmediatelyを付けない限り登録後の「変化」にしか反応
  // しないため、最初に観測したスナップショットが既にWAITINGだと二度と
  // 発火せず、結果画面から動けなくなる(roleもDEMONのまま残る)。
  // 具体的には、endsAt到達でGameResultPageへpushReplacementした直後に
  // ホストが「同じメンバーでもう一回」を押すと、新しくマウントされた
  // GameResultPageが最初に受け取るroomは既にWAITINGになっている。
  // 一時的な切断によるroomStreamProvider(autoDispose)の再購読や、
  // バックグラウンドからの復帰でも同じ穴が開く。
  // 同じ罠はRoomWaitingPage側でも一度踏んでおり(room_waiting_page.dart
  // のuseEffectのコメント参照)、そちらの書き方に揃えている。
  //
  // GamePage/GameResultPageはいずれも「開始済みのゲーム」からしか到達
  // しないため、そこでWAITINGを観測するのは巻き戻し以外にあり得ず、
  // 状態ベースにしても誤検知しない(再入はhasHandledで防ぐ)。
  useEffect(() {
    if (hasHandled.value) return null;
    final room = roomAsync.value;
    if (room == null || room.status != RoomStatus.waiting) return null;
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

    // useEffectはビルド直後に同期実行されるため、ここで即座にNavigatorを
    // 操作すると「ビルド中にNavigator操作をした」というエラーになる。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RoomWaitingPage(roomId: roomId)),
      );
    });
    return null;
  }, [roomAsync.value]);
}

RoomUser? _findUser(List<RoomUser> users, String uid) {
  for (final user in users) {
    if (user.id == uid) return user;
  }
  return null;
}
