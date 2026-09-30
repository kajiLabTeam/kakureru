import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:kakureru/features/room/new_photo_badge.dart';
import 'package:kakureru/features/room/sighting_rules.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';
import 'package:kakureru/features/room/view/game/sighting_sheet.dart';
import 'package:kakureru/features/room/view_model/room_view_model.dart';

/// [useSightingBadge]が返す、ボタンに渡すもの一式。
typedef SightingBadge = ({
  /// バッジに出す未読の数。
  int unreadCount,

  /// 目撃写真のシートを開く(閉じたら完了する)。ボタンの`onPressed`から
  /// 呼ぶ。
  Future<void> Function() openSheet,
});

/// 目撃写真のボタンの未読の数と、シートを開く操作をまとめたフック。
///
/// 「見た数」は写真タブの新着の点(`seenPhotoCount`、game_page.dart)と同じ
/// 考え方で持つ。画面に入った時点で既にある写真は見たことにし(入るたびに
/// バッジが付くと未読の意味が無くなるため)、シートを開いている間に届いた
/// ものも見たことにする。
///
/// 見た数はゲーム画面が消えたら一緒に消えてよい一時状態なのでhooksで持つ
/// (AGENTS.md規約)。地図のページ(PageViewの1枚目)は写真タブへ移ると
/// 破棄されるため、ボタンではなくGamePage本体でこのフックを呼ぶこと。
///
/// [startedAt]は`meta/startedAt`。前のゲームの写真を数えないよう、これが
/// 分かるまでは数え始めない。
SightingBadge useSightingBadge(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required int? startedAt,
  required String? myUid,
}) {
  final sightingsAsync = ref.watch(sightingsStreamProvider(roomId));
  final sightings = sightingsOfCurrentGame(
    sightingsAsync.value ?? const [],
    startedAt: startedAt,
  );
  final seenCount = useRef<int?>(null);
  final isSheetOpen = useState(false);
  // 読めなかった(エラー)ときも0枚として数え始める(isSettledForPhotoBadge)。
  if (startedAt != null && isSettledForPhotoBadge(sightingsAsync)) {
    seenCount.value ??= sightings.length;
    if (isSheetOpen.value) seenCount.value = sightings.length;
  }

  Future<void> openSheet() async {
    isSheetOpen.value = true;
    try {
      await showSightingSheet(context, roomId: roomId);
    } finally {
      if (context.mounted) isSheetOpen.value = false;
    }
  }

  return (
    unreadCount: isSheetOpen.value
        ? 0
        : unreadSightingCount(
            sightings: sightings,
            seenCount: seenCount.value,
            myUid: myUid,
          ),
    openSheet: openSheet,
  );
}

/// バッジに出す数の上限。これを超えたら「99+」にする。
const _maxBadgeCount = 99;

/// 地図の右下に置く、目撃写真のシートを開く丸いボタン(56px)。
///
/// 未読があれば右上に数のバッジを出す(ミッション企画のモック1・6)。
/// 自分の色(#2F5FC4)の面に白いアイコンを載せる。
class SightingPhotoButton extends StatelessWidget {
  /// [unreadCount]が0ならバッジを出さない。
  const SightingPhotoButton({
    required this.unreadCount,
    required this.onPressed,
    super.key,
  });

  /// 未読の数。
  final int unreadCount;

  /// タップでシートを開く。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = unreadCount > 0 ? '目撃写真を開く(未読$unreadCount件)' : '目撃写真を開く';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Material(
              color: selfColor,
              shape: const CircleBorder(),
              elevation: 4,
              shadowColor: const Color(0x591B1B19),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: IgnorePointer(
                child: Container(
                  key: const ValueKey('sightingUnreadBadge'),
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: gameNewBadge,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: gameBackground, width: 2),
                  ),
                  child: Text(
                    unreadCount > _maxBadgeCount
                        ? '$_maxBadgeCount+'
                        : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
