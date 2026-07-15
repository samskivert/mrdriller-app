import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/model.dart';
import '../util/colors.dart';

/// Renders a single stroke: a filled/outlined dot for a plain hit (with an extra outer ring for
/// an accent), or an arch-shaped glyph pointing down/up for a down-stroke/up-stroke. Renders
/// nothing (just reserves space) when [stroke] is null, matching a "no stroke for this hand on
/// this beat" slot.
class StrokeView extends StatelessWidget {
  final Stroke? stroke;
  final bool highlight;
  final double size;

  const StrokeView({super.key, required this.stroke, this.highlight = false, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final s = stroke;
    return Container(
      margin: const EdgeInsets.all(4),
      width: size,
      height: size,
      alignment: Alignment.center,
      child: s == null
          ? null
          : Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: Size(size, size),
                  painter: _StrokePainter(stroke: s, highlight: highlight),
                ),
                Text(
                  s.hand == Hand.R ? 'R' : 'L',
                  style: TextStyle(
                    color: highlight ? Colors.white : AppColors.handColor(s.hand),
                    fontWeight: FontWeight.w600,
                    fontSize: math.max(10, size * 0.4),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final Stroke stroke;
  final bool highlight;

  _StrokePainter({required this.stroke, required this.highlight});

  @override
  void paint(Canvas canvas, Size size) {
    final color = AppColors.handColor(stroke.hand);
    final w = size.width;
    final half = w / 2;

    if (stroke.dir == StrokeDir.D || stroke.dir == StrokeDir.U) {
      final path = Path();
      if (stroke.dir == StrokeDir.D) {
        path.moveTo(0, half);
        path.arcToPoint(Offset(w, half), radius: Radius.circular(half), clockwise: true);
        path.lineTo(half, w);
        path.close();
      } else {
        path.moveTo(0, half);
        path.lineTo(half, 0);
        path.lineTo(w, half);
        path.arcToPoint(Offset(0, half), radius: Radius.circular(half), clockwise: true);
        path.close();
      }
      final strokeWidth = stroke.accent ? 4.0 : 2.0;
      if (highlight) {
        canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
      return;
    }

    final center = Offset(half, half);
    final outerRadius = half - 1;
    final innerRadius = outerRadius - w / 8 - 1;
    final fillPaint = Paint()..color = color..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (highlight) canvas.drawCircle(center, innerRadius, fillPaint);
    canvas.drawCircle(center, innerRadius, strokePaint);

    if (stroke.accent) {
      if (highlight) canvas.drawCircle(center, outerRadius, fillPaint);
      canvas.drawCircle(center, outerRadius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) =>
      oldDelegate.stroke != stroke || oldDelegate.highlight != highlight;
}
