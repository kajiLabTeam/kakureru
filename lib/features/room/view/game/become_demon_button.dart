import 'package:flutter/material.dart';
import 'package:kakureru/core/theme/app_theme.dart';

/// 「鬼になる」ボタン(アイコン+ラベル+押せない理由)。
///
/// ボタン自体は常に表示し、[isDetected](BLEで至近距離を検知したか)が
/// falseの間はdisabledにする(issue #43。詳しい経緯はGamePage.build内の
/// 呼び出し箇所のコメントを参照)。dialog表示・reportCaught送信などの
/// 実処理はGamePage側の[onPressed]に任せ、このWidget自体はGamePageが
/// 抱える他のprovider(位置情報・Wi-Fi・気圧など)に依存しない見た目だけの
/// 部品にしている(widgetテストをそれらのproviderのfake抜きで書けるように
/// するため)。
///
/// 以前はGamePageと同じライブラリに居て、テストから触るために
/// `@visibleForTesting` を付けていた。ファイル分割でGamePageから見ても
/// 別ライブラリになり、「テストからしか使わない」という意味が実態と
/// 合わなくなったため注釈は外した(providerに依存しない設計自体は
/// 上記のとおり維持している)。
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
    return Theme(
      data: ThemeData(useMaterial3: true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          // GamePage内では親Columnが非flexの子にmaxHeight:infinityを渡すため
          // 指定が無くてもshrink-wrapする(本番の見た目は変わらない)。ただし
          // Scaffoldのbodyへ直接置くなど有限のmaxHeightがルーズに渡る場面
          // (widgetテスト)では画面いっぱいまで伸びてしまい、「検知の有無で
          // 高さが変わらない」ことを高さで検証できなくなる(テストが空振り
          // する)。制約に依存せずshrink-wrapさせるために明示する。
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.priority_high),
              label: const Text('鬼になる'),
              onPressed: isSubmitting || !isDetected ? null : onPressed,
            ),
            // 押せない理由をボタンのすぐ下に出す。disabledとenabledの
            // 切り替えでレイアウトが動くと元のチラつき問題が再発するため、
            // Visibility(maintainSize:true)で高さは常に確保しておき、
            // 表示/非表示だけ切り替える。
            Visibility(
              visible: !isDetected,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '鬼が3m以内に近づくと押せます',
                  style: TextStyle(color: appMuted, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
