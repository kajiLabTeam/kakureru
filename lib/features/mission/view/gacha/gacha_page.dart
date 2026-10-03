import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kakureru/features/mission/model/reward_type.dart';
import 'package:kakureru/features/mission/view/gacha/focus_lines_painter.dart';
import 'package:kakureru/features/mission/view/gacha/gacha_phase.dart';
import 'package:kakureru/features/mission/view/mission_card.dart';
import 'package:kakureru/features/mission/view/reward_page.dart';

/// 演出の地(暗い茶)。**この画面の中だけ**で使う(ゲーム中の画面には
/// 持ち込まない)。
const gachaBackground = Color(0xFF120E0A);

/// 演出の金。この画面の中だけで使う。
const gachaGold = Color(0xFFF0C04A);

/// 激熱の赤一色。
const gachaHeatRed = Color(0xFFB0272C);

/// 演出の太い書体(assets/fonts/DelaGothicOne-Regular.ttf)。
const gachaFontFamily = 'DelaGothicOne';

const _machineGold = Color(0xFFC98A1E);
const _muted = Color(0xFFB9AE95);
const _lampOff = Color(0xFF2A2219);
const _blue = Color(0xFF2F5FC4);
const _green = Color(0xFF4A9C5D);
const _red = Color(0xFFE5484D);
const _purple = Color(0xFF8E5AC0);

/// 特典を引いた直後の確定演出(モック3)。パッケージは使わず、
/// `AnimationController`と`Transform`/`CustomPaint`だけで作る。
///
/// 毎回見るので、**画面のどこをタップしても最後(特典カード)まで飛ばせる**
/// (カプセルの段だけはタップが「開ける」)。段の進み方は`gacha_phase.dart`。
///
/// `GamePage`の上に重ねて開くだけで、ゲーム画面は破棄しない(位置情報の
/// 送信は止まらない)。効果は引いた瞬間にもう出ている(持っておくごほうびは
/// 使ったときに出る)。
class GachaPage extends HookWidget {
  /// [reward]は引いた特典(抽選はもう済んでいる)。
  const GachaPage({super.key, required this.reward});

  /// 引いた特典。
  final RewardType reward;

  /// ゲーム画面の上に重ねて開く。最後に「特典の中身を見る」を押すと
  /// 特典の画面([RewardPage])に移る。
  ///
  /// 返すFutureは**特典の画面まで閉じてから**完了する。呼び出し側は
  /// これを待つ間、ゲーム終了の自動遷移を止めている(`GamePage`の
  /// `rewardOpen`)ため、演出だけ閉じた時点で完了させてはいけない。
  static Future<void> show(BuildContext context, RewardType reward) async {
    // 演出を閉じたあとはcontext(GamePage)に戻らずに続けられるよう、
    // 先にNavigatorを取っておく。
    final navigator = Navigator.of(context);
    final openReward = await navigator.push<bool>(
      PageRouteBuilder<bool>(
        pageBuilder: (_, _, _) => GachaPage(reward: reward),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
    if (openReward != true || !navigator.mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => RewardPage(reward: reward)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMiss = reward.isMiss;
    final finalPhase = isMiss ? GachaPhase.missed : GachaPhase.confirmed;
    final phase = useState(GachaPhase.turning);

    // ハンドル〜激熱までの時間(この2段だけは時間で進む)。
    final intro = useAnimationController(
      duration: gachaTurningDuration + gachaHeatDuration,
    );
    // 集中線の回転。激熱とカプセルの間だけ速くする。
    final lines = useAnimationController(duration: const Duration(seconds: 9));
    // 筐体の細かい揺れ(ハンドル)と、画面ごとの揺れ(激熱)。
    final shake = useAnimationController(
      duration: const Duration(milliseconds: 160),
    );
    // カプセルが落ちて2回弾む。
    final drop = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );
    // カプセルのまわりの光・「開けろ」の点滅・ボタンの脈動(1つで共有する)。
    final pulse = useAnimationController(
      duration: const Duration(milliseconds: 1100),
    );
    // 確定: 白く弾ける → ハンコ → 特典カード。
    final confirm = useAnimationController(duration: gachaConfirmDuration);
    // 虹の輪の回転と紙吹雪の落下(確定の段だけ)。
    final rainbow = useAnimationController(
      duration: const Duration(milliseconds: 3400),
    );
    final confetti = useAnimationController(
      duration: const Duration(milliseconds: 1700),
    );

    void enterPhase(GachaPhase next, {bool animateConfirm = true}) {
      if (phase.value == next) return;
      phase.value = next;
      switch (next) {
        case GachaPhase.turning:
          break;
        case GachaPhase.heat:
          shake.duration = const Duration(milliseconds: 140);
          unawaited(shake.repeat());
          lines.duration = const Duration(milliseconds: 2600);
          unawaited(lines.repeat());
        case GachaPhase.capsule:
          shake.stop();
          unawaited(drop.forward(from: 0));
          unawaited(pulse.repeat(reverse: true));
        case GachaPhase.confirmed:
          intro.stop();
          shake.stop();
          drop.value = 1;
          pulse.stop();
          lines.duration = const Duration(seconds: 9);
          unawaited(lines.repeat());
          unawaited(rainbow.repeat());
          unawaited(confetti.repeat());
          confirm.duration = gachaConfirmDuration;
          if (animateConfirm) {
            unawaited(confirm.forward(from: 0));
          } else {
            confirm.value = 1;
          }
        case GachaPhase.missed:
          intro.stop();
          shake.stop();
          drop.value = 1;
          pulse.stop();
          confirm.duration = gachaMissedDuration;
          if (animateConfirm) {
            unawaited(confirm.forward(from: 0));
          } else {
            confirm.value = 1;
          }
      }
    }

    // 始まったらすぐハンドルを回す(特典はもう引いてあるので待たせない)。
    useEffect(() {
      intro.duration = isMiss
          ? gachaTurningDuration
          : gachaTurningDuration + gachaHeatDuration;
      void onIntro() {
        if (phase.value == finalPhase) return;
        final elapsed = intro.duration! * intro.value;
        final next = gachaPhaseAt(elapsed, isMiss: isMiss);
        if (next.index > phase.value.index) enterPhase(next);
      }

      intro.addListener(onIntro);
      unawaited(intro.forward());
      unawaited(lines.repeat());
      unawaited(shake.repeat());
      return () => intro.removeListener(onIntro);
    }, const []);

    void onTap() {
      if (phase.value == finalPhase && confirm.isCompleted) return;
      switch (gachaTapAction(phase.value)) {
        case GachaTapAction.open:
          enterPhase(finalPhase);
        case GachaTapAction.skipToEnd:
          if (phase.value == finalPhase) {
            confirm.value = 1;
          } else {
            enterPhase(finalPhase, animateConfirm: false);
          }
      }
    }

    return PopScope(
      // 演出の途中で戻ると、どの特典だったか分からないまま閉じてしまう。
      // 戻る操作は「最後まで飛ばす」にする。
      canPop: phase.value == finalPhase && confirm.isCompleted,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // canPopはbuildの時点の値なので、出そろった直後はまだfalseのことがある。
        if (phase.value == finalPhase && confirm.isCompleted) {
          Navigator.of(context).pop();
          return;
        }
        onTap();
      },
      child: Scaffold(
        backgroundColor: gachaBackground,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Stack(
            children: [
              const Positioned.fill(child: _Glow()),
              Positioned.fill(
                child: RotationTransition(
                  turns: lines,
                  child: const CustomPaint(
                    painter: FocusLinesPainter(color: Color(0x29F0C04A)),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _Header(intro: intro, phase: phase.value),
                    Expanded(
                      child: Center(
                        child: _Machine(
                          intro: intro,
                          shake: shake,
                          drop: drop,
                          pulse: pulse,
                          phase: phase.value,
                        ),
                      ),
                    ),
                    // 確定の段では、上に重ねたカードの側にボタンを出す。
                    // 下の案内が透けて見えないよう、ここは空けておく。
                    Visibility.maintain(
                      visible: phase.value != finalPhase,
                      child: _Bottom(
                        phase: phase.value,
                        pulse: pulse,
                        onOpen: onTap,
                      ),
                    ),
                  ],
                ),
              ),
              if (phase.value == GachaPhase.heat)
                Positioned.fill(
                  child: _HeatOverlay(intro: intro, shake: shake),
                ),
              if (phase.value == GachaPhase.confirmed)
                Positioned.fill(
                  child: _ConfirmedOverlay(
                    reward: reward,
                    confirm: confirm,
                    rainbow: rainbow,
                    confetti: confetti,
                  ),
                ),
              if (phase.value == GachaPhase.missed)
                Positioned.fill(
                  child: _MissedOverlay(reward: reward, confirm: confirm),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 0.8,
          colors: [Color(0x66C98A1E), Color(0x00120E0A)],
          stops: [0, 0.68],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.intro, required this.phase});

  final AnimationController intro;
  final GachaPhase phase;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MISSION CLEAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: gachaGold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'かくれるガチャ',
                  style: TextStyle(
                    fontFamily: gachaFontFamily,
                    fontSize: 25,
                    height: 1.1,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x99F0C04A), blurRadius: 14)],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'きたい度',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedBuilder(
                animation: intro,
                builder: (context, _) {
                  final lit = phase == GachaPhase.turning
                      ? gachaLitLamps(intro.duration! * intro.value)
                      : 3;
                  return Row(
                    children: [
                      const _Lamp(color: _blue, size: 15, lit: true),
                      const SizedBox(width: 6),
                      _Lamp(color: _green, size: 15, lit: lit >= 2),
                      const SizedBox(width: 6),
                      _Lamp(color: _red, size: 19, lit: lit >= 3, glow: true),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// きたい度のランプ。点いた瞬間に一度大きく弾む。
class _Lamp extends StatelessWidget {
  const _Lamp({
    required this.color,
    required this.size,
    required this.lit,
    this.glow = false,
  });

  final Color color;
  final double size;
  final bool lit;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: lit ? 0.2 : 1, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: const Cubic(0.2, 0.9, 0.3, 1.4),
      key: ValueKey(lit),
      builder: (context, scale, child) =>
          Transform.scale(scale: lit ? scale : 1, child: child),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: lit ? color : _lampOff,
          shape: BoxShape.circle,
          boxShadow: lit && glow
              ? const [BoxShadow(color: Color(0xF2E5484D), blurRadius: 16)]
              : null,
        ),
      ),
    );
  }
}

/// 筐体の揺れ(モックの k-shake)。[t]は0〜1。
Offset _machineShake(double t) {
  const points = [
    Offset.zero,
    Offset(2, -2),
    Offset(-2, 2),
    Offset(2, 2),
    Offset(-2, -1),
    Offset.zero,
  ];
  return _keyframes(points, t);
}

/// 画面ごとの揺れ(モックの k-bigshake)。[t]は0〜1。
Offset _heatShake(double t) {
  const points = [
    Offset.zero,
    Offset(-5, 4),
    Offset(5, -4),
    Offset(-4, -4),
    Offset(4, 4),
    Offset(-3, 2),
    Offset(3, -2),
    Offset.zero,
  ];
  return _keyframes(points, t);
}

Offset _keyframes(List<Offset> points, double t) {
  final scaled = t.clamp(0.0, 1.0) * (points.length - 1);
  final i = scaled.floor().clamp(0, points.length - 2);
  return Offset.lerp(points[i], points[i + 1], scaled - i)!;
}

/// カプセルが落ちて2回弾む高さ(モックの k-drop)。[t]は0〜1。
double _dropOffset(double t) {
  const keys = [
    (0.0, -190.0),
    (0.58, 7.0),
    (0.74, -16.0),
    (0.88, 4.0),
    (1.0, 0.0),
  ];
  for (var i = 0; i < keys.length - 1; i++) {
    final (t0, y0) = keys[i];
    final (t1, y1) = keys[i + 1];
    if (t <= t1) {
      final local = ((t - t0) / (t1 - t0)).clamp(0.0, 1.0);
      return y0 + (y1 - y0) * Curves.easeOut.transform(local);
    }
  }
  return 0;
}

class _Machine extends StatelessWidget {
  const _Machine({
    required this.intro,
    required this.shake,
    required this.drop,
    required this.pulse,
    required this.phase,
  });

  final AnimationController intro;
  final AnimationController shake;
  final AnimationController drop;
  final AnimationController pulse;
  final GachaPhase phase;

  static const List<(double, double, Color)> _capsuleColors = [
    (18.0, 92.0, _red),
    (60.0, 58.0, _green),
    (104.0, 42.0, _blue),
    (146.0, 68.0, _machineGold),
    (48.0, 128.0, _blue),
    (96.0, 116.0, _red),
    (140.0, 130.0, _green),
    (176.0, 108.0, _machineGold),
  ];

  @override
  Widget build(BuildContext context) {
    final turning = phase == GachaPhase.turning;
    return AnimatedBuilder(
      animation: shake,
      builder: (context, child) => Transform.translate(
        offset: turning ? _machineShake(shake.value) : Offset.zero,
        child: child,
      ),
      child: SizedBox(
        width: 216,
        height: 388,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 丸いドーム。中にカプセルが並ぶ。
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: 216,
                height: 196,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EFE6),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(108),
                    bottom: Radius.circular(14),
                  ),
                  border: Border.all(color: _machineGold, width: 4),
                  boxShadow: const [
                    BoxShadow(color: Color(0x59F0C04A), blurRadius: 26),
                  ],
                ),
                child: Stack(
                  children: [
                    for (final (left, top, color) in _capsuleColors)
                      Positioned(
                        left: left - 4,
                        top: top - 4,
                        child: _Capsule(color: color, size: 36),
                      ),
                  ],
                ),
              ),
            ),
            // 胴体。
            Positioned(
              left: 0,
              top: 192,
              child: Container(
                width: 216,
                height: 150,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1813),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                    bottom: Radius.circular(20),
                  ),
                  border: Border.all(color: _machineGold, width: 4),
                ),
              ),
            ),
            Positioned(
              left: 22,
              top: 202,
              child: Container(
                width: 172,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _machineGold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'かくれるガチャ',
                  style: TextStyle(
                    fontFamily: gachaFontFamily,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: Color(0xFF241A0B),
                  ),
                ),
              ),
            ),
            // ハンドル。ハンドルを回す段の間に3回転する。
            Positioned(
              left: 24,
              top: 246,
              child: Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _lampOff,
                  shape: BoxShape.circle,
                  border: Border.all(color: gachaGold, width: 4),
                ),
                child: AnimatedBuilder(
                  animation: intro,
                  builder: (context, child) {
                    final turned =
                        (intro.duration! * intro.value).inMilliseconds /
                        gachaTurningDuration.inMilliseconds;
                    return Transform.rotate(
                      angle:
                          2 * math.pi * gachaKnobTurns * turned.clamp(0.0, 1.0),
                      child: child,
                    );
                  },
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 7,
                          height: 32,
                          decoration: BoxDecoration(
                            color: gachaGold,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: _red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 取り出し口。
            Positioned(
              left: 110,
              top: 242,
              child: Container(
                width: 84,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0A07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _machineGold, width: 3),
                ),
              ),
            ),
            Positioned(
              left: 4,
              top: 336,
              child: Container(
                width: 208,
                height: 28,
                decoration: BoxDecoration(
                  color: _machineGold,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Positioned(
              left: 22,
              top: 364,
              child: Container(
                width: 172,
                height: 14,
                decoration: const BoxDecoration(
                  color: Color(0xFF8A6A16),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(10),
                  ),
                ),
              ),
            ),
            // 金のカプセル(カプセルの段から)。
            if (phase == GachaPhase.capsule || phase == GachaPhase.confirmed)
              Positioned(
                left: 124,
                top: 250,
                child: AnimatedBuilder(
                  animation: Listenable.merge([drop, pulse]),
                  builder: (context, _) {
                    final t = drop.value;
                    final aura = pulse.value;
                    return Transform.translate(
                      offset: Offset(0, _dropOffset(t)),
                      child: Opacity(
                        opacity: (t / 0.32).clamp(0.0, 1.0),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: -22,
                                top: -22,
                                child: Transform.scale(
                                  scale: 1 + 0.25 * aura,
                                  child: Opacity(
                                    opacity: 0.3 + 0.5 * aura,
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            Color(0xD9F0C04A),
                                            Color(0x00F0C04A),
                                          ],
                                          stops: [0, 0.7],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                width: 56,
                                height: 56,
                                clipBehavior: Clip.hardEdge,
                                decoration: const BoxDecoration(
                                  color: gachaGold,
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(
                                    BorderSide(
                                      color: Color(0xFFFFE9B8),
                                      width: 2,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xE6F0C04A),
                                      blurRadius: 18,
                                    ),
                                  ],
                                ),
                                child: const Align(
                                  alignment: Alignment.bottomCenter,
                                  child: SizedBox(
                                    width: 52,
                                    height: 26,
                                    child: ColoredBox(
                                      color: Color(0xFFFFF6E2),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 上半分が色、下半分が白のカプセル。
class _Capsule extends StatelessWidget {
  const _Capsule({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: size,
          height: size / 2,
          child: const ColoredBox(color: Colors.white),
        ),
      ),
    );
  }
}

class _Bottom extends StatelessWidget {
  const _Bottom({
    required this.phase,
    required this.pulse,
    required this.onOpen,
  });

  final GachaPhase phase;
  final Animation<double> pulse;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isCapsule = phase == GachaPhase.capsule;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: isCapsule
                ? FadeTransition(
                    opacity: Tween<double>(begin: 0.45, end: 1).animate(pulse),
                    child: const Text(
                      '開けろ',
                      style: TextStyle(
                        fontFamily: gachaFontFamily,
                        fontSize: 20,
                        color: gachaGold,
                      ),
                    ),
                  )
                : const Text(
                    'タップで飛ばせる',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _muted,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          if (isCapsule)
            ScaleTransition(
              scale: Tween<double>(begin: 1, end: 1.06).animate(pulse),
              child: _GachaButton(
                label: 'カプセルを開ける',
                onPressed: onOpen,
                highlighted: true,
              ),
            )
          else
            const _GachaButton(label: 'まわしてる…'),
        ],
      ),
    );
  }
}

class _GachaButton extends StatelessWidget {
  const _GachaButton({
    required this.label,
    this.onPressed,
    this.highlighted = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: highlighted ? gachaGold : const Color(0xFF221B14),
          foregroundColor: highlighted
              ? const Color(0xFF241A0B)
              : const Color(0xFFCFC6B4),
          disabledBackgroundColor: const Color(0xFF221B14),
          disabledForegroundColor: const Color(0xFF8E8371),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: highlighted
                  ? const Color(0xFFFFE9B8)
                  : const Color(0xFF3A2F22),
              width: 2,
            ),
          ),
          textStyle: const TextStyle(fontFamily: gachaFontFamily, fontSize: 19),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _HeatOverlay extends StatelessWidget {
  const _HeatOverlay({required this.intro, required this.shake});

  final AnimationController intro;
  final AnimationController shake;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([intro, shake]),
      builder: (context, child) {
        final heatElapsed =
            (intro.duration! * intro.value) - gachaTurningDuration;
        final t = heatElapsed.inMilliseconds / 500;
        // 大きく飛び込んでから、ほんの少しずつ大きくなる(k-heattext)。
        final scale = t < 1
            ? 2.8 - 1.8 * Curves.easeOutBack.transform(t.clamp(0.0, 1.0))
            : 1 + 0.05 * ((heatElapsed.inMilliseconds - 500) / 900);
        return ColoredBox(
          color: gachaHeatRed.withValues(
            alpha: (heatElapsed.inMilliseconds / 200).clamp(0.0, 1.0),
          ),
          child: Transform.translate(
            offset: _heatShake(shake.value),
            child: Center(
              child: Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(scale: scale, child: child),
              ),
            ),
          ),
        );
      },
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '激熱',
            style: TextStyle(
              fontFamily: gachaFontFamily,
              fontSize: 66,
              height: 1,
              letterSpacing: 2.6,
              color: Colors.white,
              shadows: [
                Shadow(color: Color(0xF2FFE696), blurRadius: 22),
                Shadow(color: Color(0xFF7C1418), offset: Offset(0, 7)),
              ],
            ),
          ),
          SizedBox(height: 14),
          Text(
            '当たりの気配',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.7,
              color: Color(0xFFFFE3A8),
            ),
          ),
        ],
      ),
    );
  }
}

/// 確定の段。確定の段の[confirm](0〜1)の中で、白い光・ハンコ・カードの
/// 出るタイミングをずらす(モックの animation-delay と同じ)。
double _interval(double t, double start, double end) =>
    ((t - start) / (end - start)).clamp(0.0, 1.0);

class _ConfirmedOverlay extends StatelessWidget {
  const _ConfirmedOverlay({
    required this.reward,
    required this.confirm,
    required this.rainbow,
    required this.confetti,
  });

  final RewardType reward;
  final AnimationController confirm;
  final AnimationController rainbow;
  final AnimationController confetti;

  static const _confettiColors = [
    _red,
    gachaGold,
    _green,
    _blue,
    gachaGold,
    _red,
    _purple,
    gachaGold,
    _green,
    _blue,
  ];

  /// 紙吹雪の横位置(画面幅に対する割合)と、落ち始めの遅れ(周期に対する割合)。
  static const List<(double, double)> _confettiLayout = [
    (0.08, 0.0),
    (0.19, 0.18),
    (0.30, 0.41),
    (0.41, 0.09),
    (0.52, 0.53),
    (0.63, 0.26),
    (0.74, 0.65),
    (0.86, 0.35),
    (0.14, 0.76),
    (0.58, 0.88),
  ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final durationLabel = reward.durationLabel;
    return ColoredBox(
      color: const Color(0xF00A0806),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 虹の輪(SweepGradient)を回す。
          RotationTransition(
            turns: rainbow,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [_red, gachaGold, _green, _blue, _purple, _red],
                ),
              ),
            ),
          ),
          Container(
            width: 268,
            height: 268,
            decoration: const BoxDecoration(
              color: Color(0xFF0A0806),
              shape: BoxShape.circle,
            ),
          ),
          // 白く弾ける光。
          AnimatedBuilder(
            animation: confirm,
            builder: (context, child) {
              final t = _interval(confirm.value, 0, 0.64);
              return Opacity(
                opacity: (1 - t) * 0.95,
                child: Transform.scale(scale: 0.15 + 3.05 * t, child: child),
              );
            },
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xF2FFFFFF), Color(0x00FFFFFF)],
                  stops: [0, 0.7],
                ),
              ),
            ),
          ),
          // 紙吹雪(10枚まで)。
          for (var i = 0; i < gachaConfettiCount; i++)
            AnimatedBuilder(
              animation: confetti,
              builder: (context, child) {
                final (x, delay) = _confettiLayout[i];
                final t = (confetti.value + 1 - delay) % 1;
                return Positioned(
                  left: size.width * x,
                  top: -60 + (size.height + 60) * t,
                  child: Opacity(
                    opacity: t < 0.12 ? t / 0.12 : 1 - t,
                    child: Transform.rotate(
                      angle: t * 560 * math.pi / 180,
                      child: child,
                    ),
                  ),
                );
              },
              child: Container(
                key: ValueKey('gacha-confetti-$i'),
                width: 8,
                height: 14,
                decoration: BoxDecoration(
                  color: _confettiColors[i],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 「確定」のハンコが斜めに飛び込む。
              AnimatedBuilder(
                animation: confirm,
                builder: (context, child) {
                  final t = _interval(confirm.value, 0.2, 0.76);
                  final double scale;
                  if (t < 0.52) {
                    scale = 3.2 - 2.3 * (t / 0.52);
                  } else if (t < 0.74) {
                    scale = 0.9 + 0.18 * ((t - 0.52) / 0.22);
                  } else {
                    scale = 1.08 - 0.08 * ((t - 0.74) / 0.26);
                  }
                  final angle = t < 0.52 ? -26 + 19 * (t / 0.52) : -7.0;
                  return Opacity(
                    opacity: (t / 0.52).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: angle * math.pi / 180,
                      child: Transform.scale(scale: scale, child: child),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC0343A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: gachaGold, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0xB3F0C04A), blurRadius: 26),
                    ],
                  ),
                  child: const Text(
                    '確定',
                    style: TextStyle(
                      fontFamily: gachaFontFamily,
                      fontSize: 40,
                      height: 1,
                      letterSpacing: 4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 特典カードが跳ねて出る。
              AnimatedBuilder(
                animation: confirm,
                builder: (context, child) {
                  final t = _interval(confirm.value, 0.45, 0.91);
                  final eased = Curves.easeOutBack.transform(t);
                  return Opacity(
                    opacity: (t / 0.64).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - eased)),
                      child: Transform.scale(
                        scale: 0.74 + 0.26 * eased,
                        child: child,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: math.min(330, size.width - 32),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1510),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gachaGold, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x66F0C04A), blurRadius: 40),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _DarkTag(
                            label: rewardTargetLabel(reward.target),
                            background: reward.target == RewardTarget.demon
                                ? const Color(0xFFC0343A)
                                : _blue,
                            foreground: Colors.white,
                          ),
                          if (durationLabel != null) ...[
                            const SizedBox(width: 7),
                            _DarkTag(
                              label: durationLabel,
                              background: gachaGold,
                              foreground: const Color(0xFF241A0B),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        reward.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: gachaFontFamily,
                          fontSize: 22,
                          height: 1.4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        reward.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.7,
                          color: Color(0xFFCFC6B4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: confirm,
                  curve: const Interval(0.8, 1),
                ),
                child: Text(
                  reward.isHeld ? '地図の「つかう」で好きなときに使える' : '効果はもう出ている',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: AnimatedBuilder(
                animation: confirm,
                builder: (context, _) => _GachaButton(
                  label: '特典の中身を見る',
                  onPressed: confirm.isCompleted
                      // 特典の画面はshowが続けて開く(ここで差し替えると
                      // showのFutureが特典の画面を開いたまま完了する)。
                      ? () => Navigator.of(context).pop(true)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ハズレの段。当たり([_ConfirmedOverlay])と違い、虹の輪・紙吹雪・
/// 「確定」のハンコは出さず、赤い「残念」のスタンプで短く終わる
/// (待たされた末のハズレを当たりと同じ豪華さで引き延ばさない)。
class _MissedOverlay extends StatelessWidget {
  const _MissedOverlay({required this.reward, required this.confirm});

  final RewardType reward;
  final AnimationController confirm;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ColoredBox(
      color: const Color(0xF00A0806),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 赤い「残念」のスタンプが斜めに飛び込む。
              AnimatedBuilder(
                animation: confirm,
                builder: (context, child) {
                  final t = _interval(confirm.value, 0, 0.5);
                  final scale = 2.4 - 1.4 * Curves.easeOutBack.transform(t);
                  return Opacity(
                    opacity: t,
                    child: Transform.rotate(
                      angle: -6 * math.pi / 180,
                      child: Transform.scale(scale: scale, child: child),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A2226),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _red, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x99B0272C), blurRadius: 22),
                    ],
                  ),
                  child: const Text(
                    '残念',
                    style: TextStyle(
                      fontFamily: gachaFontFamily,
                      fontSize: 40,
                      height: 1,
                      letterSpacing: 4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 特典カードは当たりと同じ見た目で出す(ハズレは何も起きない
              // ことを必ず伝える)。
              AnimatedBuilder(
                animation: confirm,
                builder: (context, child) {
                  final t = _interval(confirm.value, 0.25, 0.8);
                  final eased = Curves.easeOutBack.transform(t);
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - eased)),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: math.min(330, size.width - 32),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1510),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _red, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x4DB0272C), blurRadius: 32),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _DarkTag(
                            label: rewardTargetLabel(reward.target),
                            background: _red,
                            foreground: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        reward.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: gachaFontFamily,
                          fontSize: 22,
                          height: 1.4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        reward.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.7,
                          color: Color(0xFFCFC6B4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: AnimatedBuilder(
                animation: confirm,
                builder: (context, _) => _GachaButton(
                  label: '特典の中身を見る',
                  onPressed: confirm.isCompleted
                      ? () => Navigator.of(context).pop(true)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkTag extends StatelessWidget {
  const _DarkTag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
