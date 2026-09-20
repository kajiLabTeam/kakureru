import 'package:flutter/material.dart';
import 'package:kakureru/core/theme/app_theme.dart';
import 'package:kakureru/core/utils/duration_format.dart';

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

/// 可視性ディレイ中、「なぜ相手が見えないか」を明示するカード
/// (UI改修モック2a-04)。何も表示しないと不具合と区別が付かないため、
/// `hiddenOpponentReason`(role_visibility.dart)で計算した理由を出す。
class HiddenOpponentCard extends StatelessWidget {
  /// [reason]は表示する理由文。
  const HiddenOpponentCard({super.key, required this.reason});

  /// 「まだ見えない」理由の案内文。
  final String reason;

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
          const Opacity(
            opacity: 0.35,
            child: Text('👹', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: 8),
          const Text(
            '鬼の位置はまだ見えません',
            style: TextStyle(fontSize: 13, color: appMuted),
          ),
          const SizedBox(height: 4),
          Text(
            reason,
            style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
          ),
        ],
      ),
    );
  }
}
