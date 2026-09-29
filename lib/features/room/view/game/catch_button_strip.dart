import 'package:flutter/material.dart';

/// 「捕まえた」の帯の高さ(モックの66px)。押せる/押せないで変わらない。
const double catchButtonStripHeight = 66;

/// 鬼の画面の暗い赤(白文字を載せる面の色)。
const catchSurfaceColor = Color(0xFFC0343A);

const _stripBackground = Color(0xFFFCEDEC);
const _stripBorder = Color(0xFFF0C9C7);
const _stripSubInk = Color(0xFF8A5350);

/// 鬼の画面のタブ直下に出す「捕まえた」の帯(issue #140)。
///
/// ボタンは常に出し、BLEで3m以内に逃走者がいないときはdisabledにする
/// (出し入れするとレイアウトがガタつくため。旧「鬼になる」と同じ方針)。
/// 相手の選択・送信などの実処理はGamePage側の[onPressed]に任せ、この
/// ウィジェットはproviderを読まない見た目だけの部品にしている。
class CatchButtonStrip extends StatelessWidget {
  /// すべての引数はGamePageが計算して渡す。
  const CatchButtonStrip({
    super.key,
    required this.nearestName,
    required this.inRangeCount,
    required this.isSubmitting,
    required this.onPressed,
    this.waitingForRelease = false,
  });

  /// 3m以内にいる逃走者のうち一番近い人の名前。いなければnull。
  final String? nearestName;

  /// 3m以内にいる逃走者の人数。
  final int inRangeCount;

  /// 捕獲の送信中か。送信中は押せない。
  final bool isSubmitting;

  /// 押されたときの処理(相手の選択シート〜送信)。
  final VoidCallback onPressed;

  /// 鬼の放出前か。放出前は帯を出したまま押せなくする。
  final bool waitingForRelease;

  @override
  Widget build(BuildContext context) {
    final enabled = !waitingForRelease && inRangeCount > 0 && !isSubmitting;
    final headline = switch (nearestName) {
      _ when waitingForRelease => '鬼が放たれたら捕まえられます',
      null => '3m以内に逃走者はいません',
      final name when inRangeCount > 1 =>
        '$name ほか${inRangeCount - 1}人が3m以内にいます',
      final name => '$name が3m以内にいます',
    };

    return Container(
      // 文字を大きくしている端末ではみ出さないよう、高さは最低値で指定する
      // (文言はどれも1行なので、通常の文字サイズなら状態で高さは変わらない)。
      constraints: const BoxConstraints(minHeight: catchButtonStripHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: const BoxDecoration(
        color: _stripBackground,
        border: Border(bottom: BorderSide(color: _stripBorder)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sensors, color: catchSurfaceColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: catchSurfaceColor,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '3m以内に近づいたときだけ押せます',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: _stripSubInk),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: enabled ? onPressed : null,
              style: FilledButton.styleFrom(
                backgroundColor: catchSurfaceColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: catchSurfaceColor.withValues(
                  alpha: 0.35,
                ),
                disabledForegroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                // アプリのテーマ(app_theme.dart)はボタンを横幅いっぱいに
                // する(minimumSize: Size.fromHeight)。Rowの中では幅が無限に
                // なりレイアウトが例外で止まるため、ここでは幅の下限を外す。
                minimumSize: const Size(0, 48),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '捕まえた',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
