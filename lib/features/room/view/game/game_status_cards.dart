import 'package:flutter/material.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/core/utils/duration_format.dart';
import 'package:kakureru/features/room/opponent_roster_status.dart';

/// 鬼放出前、逃走者に「いまのうちに離れる」ことを促すバナー
/// (UI改修モック2a-04)。
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
      color: const Color(0xFFFFFAF0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('⏳', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '鬼の放出まで $label — いまのうちに離れる',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A6A1E)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 相手の一覧・詳細が出せないときに、その理由を明示するカード
/// (UI改修モック2a-04)。何も表示しないと不具合と区別が付かない。
///
/// 出す理由は2種類あり、どちらも[GameStatusMessage]として呼び出し側が
/// 組み立てる:
/// - 可視性ディレイでまだ見えない(`hiddenOpponentReason`)
/// - そもそも対象役割の相手がルームに居ない(`describeEmptyOpponentReason`)
class HiddenOpponentCard extends StatelessWidget {
  /// [message]に見出し・補足・アイコンをまとめて渡す。
  const HiddenOpponentCard({super.key, required this.message});

  /// 表示する内容(アイコン・見出し・補足)。
  final GameStatusMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // チップ一覧+詳細カードが出せる状態と高さの差が大きいと、可視性が
      // 解禁されるたびに地図の表示領域が急に縮んでガタつくため、同程度の
      // 高さ(200)を確保しておく(issue #29フォローアップ)。
      height: 200,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCCCCCC), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.35,
            child: Text(message.emoji, style: const TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: 8),
          Text(
            message.headline,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: appMuted),
          ),
          if (message.detail != null) ...[
            const SizedBox(height: 4),
            Text(
              message.detail!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
            ),
          ],
        ],
      ),
    );
  }
}
