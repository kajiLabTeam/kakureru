import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kakureru/features/room/area_alert.dart';

/// エリア外警告に使う赤。docs/ui-mockup-2a.html の 2a-07 と同じ #E5484D。
///
/// 配色ルール(赤=鬼/青=自分/緑=逃走者)上の赤は本来「鬼」だが、2a-07は
/// 警告帯・地図の赤かぶせ・矢印をすべてこの赤で描いている。危険を示す色を
/// ここだけ別に増やすより、モックに合わせる方を優先する。
const outsideAreaAlertColor = Color(0xFFE5484D);

/// 地図に重ねる赤の濃さ。モックの rgba(229,72,77,.16) と同じ。
const _mapOverlayAlpha = 0.16;

/// 画面上部に出すエリア外の警告帯(UI改修モック2a-07)。
///
/// 文言は2行。1行目で状態を、2行目で「戻るまで続く」ことを伝える
/// (振動が止まらないのを不具合と誤解させないため。issue #61の検討メモ:
/// エリア外はルール違反なのでペナルティとして意図的に継続する)。
class OutsideAreaBanner extends StatelessWidget {
  /// 表示内容は固定なので引数を取らない。出す/出さないの判断は
  /// 呼び出し側(GamePage)が持つ。
  const OutsideAreaBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: outsideAreaAlertColor,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: const Row(
        children: [
          Text('🚨', style: TextStyle(fontSize: 19)),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'プレイエリアの外です',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                SizedBox(height: 2),
                Text(
                  '戻るまで振動と通知が続きます',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 地図全体に赤の半透明を重ね、エリアの方向を指す矢印を出すオーバーレイ
/// (UI改修モック2a-07)。
///
/// 地図そのもの(エリアの破線境界・外側の暗転)は`GameLocationMap`が描くので、
/// ここではその上に重ねる警告表示だけを持つ。矢印は画面中央に出す: モックは
/// 自分のピンの横に添えているが、ピンのスクリーン座標は地図のカメラ次第で
/// 変わり、このウィジェットからは分からないため。
///
/// 地図のパン・ズームを邪魔しないよう[IgnorePointer]でタップを素通りさせる。
class OutsideAreaMapOverlay extends StatelessWidget {
  /// [bearingDegrees]はエリアへ戻る方位(北=0・東=90の時計回り)。
  /// `describeReturnToArea`の戻り値をそのまま渡す。
  const OutsideAreaMapOverlay({super.key, required this.bearingDegrees});

  /// エリアへ戻る方位(度)。矢印の回転角に使う。
  final double bearingDegrees;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: outsideAreaAlertColor.withValues(alpha: _mapOverlayAlpha),
        alignment: Alignment.center,
        // 地図は常に北が上(回転させていない)ので、方位角をそのまま
        // 時計回りの回転角として使える。上向きの矢印が北を指す。
        child: Transform.rotate(
          angle: bearingDegrees * math.pi / 180,
          child: const Icon(
            Icons.arrow_upward,
            size: 72,
            color: outsideAreaAlertColor,
            // 赤い地図タイルの上でも輪郭が沈まないよう、白いにじみを敷く
            // (地図ピンの白フチと同じ狙い)。
            shadows: [Shadow(color: Colors.white, blurRadius: 10)],
          ),
        ),
      ),
    );
  }
}

/// 地図の下部に重ねる「エリアまで約◯m ・ ◯へ戻ってください」のカード
/// (UI改修モック2a-07)。
///
/// 位置(地図のどこに重ねるか)は呼び出し側が決める。カード自体は幅いっぱいに
/// 広がるただの帯なので、[Positioned]でも[Align]でも置ける。
class ReturnToAreaCard extends StatelessWidget {
  /// [meters]と[bearingDegrees]は`describeReturnToArea`の戻り値をそのまま渡す。
  const ReturnToAreaCard({
    super.key,
    required this.meters,
    required this.bearingDegrees,
  });

  /// エリアの境界までの距離(m)。
  final double meters;

  /// エリアへ戻る方位(度)。8方位の日本語に直して出す。
  final double bearingDegrees;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        'エリアまで約 ${formatReturnDistance(meters)} ・ '
        '${compassLabel(bearingDegrees)}へ戻ってください',
        style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
      ),
    );
  }
}
