import 'package:flutter/material.dart';
import 'package:kakureru/features/mission/model/mission_notice.dart';
import 'package:kakureru/features/mission/view/mission_palette.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';

/// アプリを開いているときに出す、ミッションのお知らせ(逃走者だけ)。
/// タップで地図のミッションのカードへ移る(呼び出し側が[onTap]で移す)。
///
/// 通知の許可が無くても出す(OSの通知とは別物のため)。
class MissionNoticeBanner extends StatelessWidget {
  /// [notice]の文言を出す。
  const MissionNoticeBanner({
    super.key,
    required this.notice,
    required this.onTap,
  });

  /// 出すお知らせ。
  final MissionNotice notice;

  /// タップしたとき。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: const Color(0x401B1B19),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: missionDeep,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flag, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    notice.message,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: gameInk,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: gameMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [MissionNoticeBanner]をしばらく出した後に畳む、小さい丸アイコン
/// (issue #155)。タップで[MissionNoticeBanner]へ戻す。
///
/// 地図を隠す面積を減らすための代替表示であって、お知らせ自体は消さない
/// (Riverpod側の状態はそのまま。畳む/開くはGamePageのhooksだけで切り替える)。
class MissionNoticeIcon extends StatelessWidget {
  /// タップで[onTap]。
  const MissionNoticeIcon({super.key, required this.onTap});

  /// タップしたとき(再展開する)。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: missionDeep,
        shape: const CircleBorder(),
        elevation: 6,
        shadowColor: const Color(0x401B1B19),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Icon(Icons.flag, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
