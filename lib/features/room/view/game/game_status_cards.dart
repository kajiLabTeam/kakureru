import 'package:flutter/material.dart';
import 'package:kakureru/core/utils/duration_format.dart';
import 'package:kakureru/features/room/opponent_roster_status.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';

/// 放出前バナーの高さ(モックの62px)。
const double preReleaseBannerHeight = 62;

/// 鬼放出前、逃走者に「いまのうちに離れる」ことを促すバナー
/// (ゲーム画面モック03)。
class PreReleaseBanner extends StatelessWidget {
  /// [countdownSec]は鬼放出までの残り秒数。まだ確定していなければnull。
  const PreReleaseBanner({super.key, required this.countdownSec});

  /// 鬼放出までの残り秒数。nullの間は「計算中...」と出す。
  final int? countdownSec;

  @override
  Widget build(BuildContext context) {
    final sec = countdownSec;
    final label = sec == null ? '計算中...' : formatCountdown(sec);
    return Container(
      width: double.infinity,
      height: preReleaseBannerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: gameNoticeBackground,
        border: Border(bottom: BorderSide(color: gameNoticeBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_empty, size: 22, color: gameNoticeAccent),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '鬼の放出まで $label',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: gameNoticeInk,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'いまのうちに、鬼から離れておきましょう',
                  style: TextStyle(fontSize: 11, color: gameNoticeSubInk),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// [GameStatusIcon]に対応するアイコン。
IconData gameStatusIconData(GameStatusIcon icon) {
  switch (icon) {
    case GameStatusIcon.allCaught:
      return Icons.emoji_events_outlined;
    case GameStatusIcon.waiting:
      return Icons.hourglass_empty;
    case GameStatusIcon.hidden:
      return Icons.visibility_off_outlined;
    case GameStatusIcon.notDetected:
      return Icons.wifi_find;
  }
}

/// 相手の手がかりが出せないときに、その理由といつ出るかを明示するカード
/// (ゲーム画面モック03)。何も表示しないと不具合と区別が付かない。
///
/// 中身は[emptyOpponentMessage]で組み立てた[GameStatusMessage]を渡す。
class HiddenOpponentCard extends StatelessWidget {
  /// [message]に見出し・補足・アイコン・残り時間をまとめて渡す。
  const HiddenOpponentCard({super.key, required this.message});

  /// 表示する内容。
  final GameStatusMessage message;

  @override
  Widget build(BuildContext context) {
    final detail = message.detail;
    final pill = message.pill;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: gameBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: gameTrack,
              shape: BoxShape.circle,
            ),
            child: Icon(
              gameStatusIconData(message.icon),
              size: 22,
              color: gameMuted,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            message.headline,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: gameInk,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 9),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.7,
                color: gameMuted,
              ),
            ),
          ],
          if (pill != null) ...[
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: gameNoticeBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                pill,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: gameNoticeInk,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
