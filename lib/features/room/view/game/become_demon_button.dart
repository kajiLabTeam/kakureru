import 'package:flutter/material.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';

/// 「鬼になる」の帯の高さ(モックの56px)。検知の有無で変わらない。
const double becomeDemonRowHeight = 56;

/// 押せる状態の「鬼になる」ボタンの地(鬼の濃い赤)。
const becomeDemonEnabledColor = Color(0xFFC0343A);

/// 押せない状態の「鬼になる」ボタンの地と文字。
const becomeDemonDisabledColor = Color(0xFFEDEAE2);
const becomeDemonDisabledInk = gameFaint;

/// 「鬼になる」の帯(左に押せる条件の説明、右にボタン)。
///
/// ボタン自体は常に表示し、[isDetected](BLEで至近距離を検知したか)が
/// falseの間はdisabledにする(issue #43。詳しい経緯はGamePage.build内の
/// 呼び出し箇所のコメントを参照)。dialog表示・reportCaught送信などの
/// 実処理はGamePage側の[onPressed]に任せ、このWidget自体はGamePageが
/// 抱える他のprovider(位置情報・Wi-Fi・気圧など)に依存しない見た目だけの
/// 部品にしている(widgetテストをそれらのproviderのfake抜きで書けるように
/// するため)。
///
/// 帯の高さは[becomeDemonRowHeight]で固定し、説明文も検知の有無で
/// 変えない。押せる/押せないの切り替えでレイアウトが動くと、以前の
/// チラつき問題(issue #43)が再発するため。
class BecomeDemonButton extends StatelessWidget {
  /// すべての引数はGamePageが計算して渡す(このウィジェットはproviderを
  /// 一切読まない)。
  const BecomeDemonButton({
    super.key,
    required this.isDetected,
    required this.isSubmitting,
    required this.onPressed,
  });

  /// BLEで対象役割の相手を至近距離(3m程度)に検知しているか。
  final bool isDetected;

  /// reportCaughtの送信中かどうか。送信中は検知の有無にかかわらずdisabled。
  final bool isSubmitting;

  /// 押されたときの処理(確認ダイアログ表示〜reportCaught送信)。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = isDetected && !isSubmitting;
    final Widget leading;
    if (isSubmitting) {
      leading = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else if (enabled) {
      leading = const Icon(Icons.priority_high, size: 16);
    } else {
      leading = const Icon(Icons.lock_outline, size: 16);
    }

    return Container(
      height: becomeDemonRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: gameBorder)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '鬼が3m以内に近づくと\n「鬼になる」が押せます',
              style: TextStyle(fontSize: 11, color: gameMuted, height: 1.4),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: leading,
            label: const Text('鬼になる'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 44),
              fixedSize: const Size.fromHeight(44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: const StadiumBorder(),
              backgroundColor: becomeDemonEnabledColor,
              foregroundColor: Colors.white,
              // 送信中はスピナーを白で見せたいので、押せない理由による
              // 無効(灰)と送信中の無効(赤のまま)を分ける。
              disabledBackgroundColor: isSubmitting
                  ? becomeDemonEnabledColor
                  : becomeDemonDisabledColor,
              disabledForegroundColor: isSubmitting
                  ? Colors.white
                  : becomeDemonDisabledInk,
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
