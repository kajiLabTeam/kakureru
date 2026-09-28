import 'package:flutter/material.dart';
import 'package:kakureru/features/room/view/game/area_rules_dialog.dart';
import 'package:kakureru/features/room/view/game/game_palette.dart';
import 'package:kakureru/features/room/view/game/game_view_helpers.dart';

/// 「手がかりの見方」を全画面で開く(ゲーム画面モック04)。
///
/// 初回はGamePageが自動で1回だけ開き、以後はヘッダーと手がかりカードの
/// 「?」からいつでも開ける。閉じる(「わかった」「スキップ」「戻る」)まで
/// 待つ`Future`を返す。
Future<void> showClueGuide(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const ClueGuidePage(),
    ),
  );
}

/// 手がかりカードの読み方を3枚のカードで説明する画面。
///
/// 見た目だけの静的な画面で、状態は持たない。最後に「使ってよい場所」の
/// 一覧へのリンクを置く(ヘッダーのボタンをこの画面の「?」に置き換えた
/// ため、場所の一覧へはここから辿る)。
class ClueGuidePage extends StatelessWidget {
  /// 手がかりの見方の画面を作る。
  const ClueGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(context).pop();
    return Scaffold(
      backgroundColor: gameBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '手がかりの見方',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: gameInk,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: close,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: gameMuted,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text('スキップ'),
                  ),
                ],
              ),
              const _Progress(),
              Expanded(
                child: ListView(
                  children: const [
                    _GuideCard(
                      title: '1. バーが右にのびるほど近い',
                      visual: _SampleMeter(),
                      body:
                          'まわりのWi-Fiの届き方が、相手とどれくらい似ているかを'
                          '表しています。似ているほど、近くにいる可能性が高く'
                          'なります。',
                    ),
                    SizedBox(height: 12),
                    _GuideCard(
                      title: '2. 歩きながら「近づいた」を見る',
                      visual: _SampleTrendTags(),
                      body:
                          'いま進んでいる向きが合っているかが分かります。'
                          '「離れた」が続いたら、反対方向へ行ってみてください。',
                    ),
                    SizedBox(height: 12),
                    _GuideCard(
                      title: '3. 高さは「階」で出ます',
                      visual: _SampleFloor(),
                      body:
                          '気圧から推定しています。ぴったりの階数ではないので、'
                          '目安として使ってください。',
                    ),
                    SizedBox(height: 16),
                    Text(
                      'どれも推定なので「〜かも」と出ます。\n'
                      'あとから、ヘッダーの ? でいつでも読み直せます。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.6,
                        color: gameMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => showAreaRulesDialog(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: gameInkSoft,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
                child: const Text('使ってよい場所を見る'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: close,
                  style: FilledButton.styleFrom(
                    backgroundColor: gameInk,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('わかった'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 上部の3分割の進み具合。画面は1枚なので、モックどおり1つ目だけ塗る。
class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i == 0 ? const Color(0xFF3A7F4A) : gameEmptyDot,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.title,
    required this.visual,
    required this.body,
  });

  final String title;
  final Widget visual;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: gameBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: gameInk,
            ),
          ),
          const SizedBox(height: 10),
          visual,
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              height: 1.7,
              color: gameInkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleMeter extends StatelessWidget {
  const _SampleMeter();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 12,
        color: gameTrack,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.79,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFE5484D),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}

class _SampleTrendTags extends StatelessWidget {
  const _SampleTrendTags();

  @override
  Widget build(BuildContext context) {
    Widget tag(IconData icon, String label, Color bg, Color fg) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        tag(
          Icons.arrow_upward,
          '近づいた',
          const Color(0xFFFCEDEC),
          const Color(0xFFC0343A),
        ),
        const SizedBox(width: 8),
        tag(Icons.arrow_downward, '離れた', gameTrack, gameMuted),
      ],
    );
  }
}

class _SampleFloor extends StatelessWidget {
  const _SampleFloor();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: gameSoftBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF0FB),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_upward, size: 18, color: selfColor),
          ),
          const SizedBox(width: 10),
          const Text(
            '1階ぶんくらい 上かも',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: gameInk,
            ),
          ),
        ],
      ),
    );
  }
}
