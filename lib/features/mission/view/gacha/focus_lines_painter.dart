import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ガチャの背景の集中線。中心から放射状に[count]本を1回の描画で描く。
///
/// 回転は描画し直さず、外側の`RotationTransition`で回す(1本ずつ
/// ウィジェットを並べて個別に動かすと、ウィジェットが増えて重くなるため)。
class FocusLinesPainter extends CustomPainter {
  /// [color]は線の色。太い線と細い線を交互に描き、細い線は薄くする。
  const FocusLinesPainter({required this.color, this.count = 18});

  /// 線の色(太い線)。細い線はこれより薄くする。
  final Color color;

  /// 線の本数。
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final length = size.longestSide;
    final wide = Paint()..color = color;
    final thin = Paint()..color = color.withValues(alpha: color.a * 0.6);
    for (var i = 0; i < count; i++) {
      final angle = 2 * math.pi * i / count;
      final isWide = i.isEven;
      // 根元が細く先が太い、細長い三角形にする(放射状の光に見える)。
      final halfWidth = (isWide ? 8.0 : 4.0) * length / 420;
      final dir = Offset(math.sin(angle), -math.cos(angle));
      final normal = Offset(-dir.dy, dir.dx);
      final tip = center + dir * length;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          (tip + normal * halfWidth).dx,
          (tip + normal * halfWidth).dy,
        )
        ..lineTo(
          (tip - normal * halfWidth).dx,
          (tip - normal * halfWidth).dy,
        )
        ..close();
      canvas.drawPath(path, isWide ? wide : thin);
    }
  }

  @override
  bool shouldRepaint(FocusLinesPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.count != count;
}
