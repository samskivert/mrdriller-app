import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/grading.dart';
import '../model/model.dart';
import '../util/colors.dart';

// How much bigger the currently-playing block pops: less for unaccented strokes than accented
// ones, to keep their size difference clear even mid-pop.
const double _accentPopScale = 1.25;
const double _popScale = 1.15;

/// Renders a single stroke as a candy block: blue for the right hand, orange for the left. An
/// accented stroke is a full-size rounded block with icing dripping off its top, an unaccented one
/// a smaller round candy, and a down-stroke/up-stroke is pointed at the bottom/top like a drill
/// bit. Accented and unaccented strokes differ in silhouette, not just size, so that the
/// difference stays clear while the currently-[highlight]ed block pops up in size, ringed in white
/// with a glow behind it. Renders nothing (just reserves space) when [stroke] is null, matching a
/// "no stroke for this hand on this beat" slot. A [grade] (of the player's hit, from a drum pad) is
/// marked over the block: a gold ring if perfect, green if good, pink with an arrow off the side it
/// was off to if early or late, a red cross over the block faded if missed, a red dot if hit
/// with the wrong hand, and a gold triangle if hit with the wrong accent (pointing up if it
/// should have been louder, down if softer).
class StrokeView extends StatelessWidget {
  final Stroke? stroke;
  final bool highlight;
  final double size;
  final Grade? grade;

  const StrokeView({
    super.key,
    required this.stroke,
    this.highlight = false,
    this.size = 28,
    this.grade,
  });

  @override
  Widget build(BuildContext context) {
    final s = stroke;
    return Container(
      margin: const EdgeInsets.all(4),
      width: size,
      height: size,
      child: s == null
          ? null
          : Semantics(
              label: [
                s.hand == Hand.R ? 'Right' : 'Left',
                if (s.accent) 'accent',
                if (s.dir == StrokeDir.D) 'down stroke',
                if (s.dir == StrokeDir.U) 'up stroke',
              ].join(' '),
              child: AnimatedScale(
                scale: highlight ? (s.accent ? _accentPopScale : _popScale) : 1,
                duration: const Duration(milliseconds: 70),
                curve: Curves.easeOut,
                child: CustomPaint(
                  size: Size(size, size),
                  painter: _BlockPainter(stroke: s, highlight: highlight),
                  foregroundPainter: grade == null ? null : _GradePainter(grade!),
                ),
              ),
            ),
    );
  }
}

class _GradePainter extends CustomPainter {
  final Grade grade;

  _GradePainter(this.grade);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = size.center(Offset.zero);
    final judgement = grade.judgement;
    if (judgement == Judgement.miss) {
      // Fade the block, and cross it out.
      canvas.drawCircle(center, s * 0.52, Paint()..color = AppColors.navy.withValues(alpha: 0.6));
      final cross = Paint()
        ..color = AppColors.candyRed.base
        ..strokeWidth = s * 0.12
        ..strokeCap = StrokeCap.round;
      final d = s * 0.26;
      canvas.drawLine(center.translate(-d, -d), center.translate(d, d), cross);
      canvas.drawLine(center.translate(d, -d), center.translate(-d, d), cross);
    } else {
      final color = switch (judgement) {
        Judgement.perfect => AppColors.gold,
        Judgement.good => AppColors.candyGreen.base,
        _ => AppColors.candyPink.base,
      };
      canvas.drawCircle(
        center,
        s * 0.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.09
          ..color = color,
      );
      if (judgement == Judgement.early || judgement == Judgement.late) {
        // An arrowhead off the side it was off to.
        final side = judgement == Judgement.early ? -1.0 : 1.0;
        final tip = center.translate(side * s * 0.82, 0);
        final back = side * s * 0.16;
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(tip.dx - back, tip.dy - s * 0.14)
            ..lineTo(tip.dx - back, tip.dy + s * 0.14)
            ..close(),
          Paint()..color = color,
        );
      }
    }
    if (grade.wrongHand) {
      final dot = center.translate(s * 0.42, -s * 0.42);
      canvas.drawCircle(dot, s * 0.14, Paint()..color = AppColors.candyRed.outline);
      canvas.drawCircle(dot, s * 0.1, Paint()..color = AppColors.candyRed.base);
    }
    if (grade.wrongAccent) {
      // Pointing the way it should have gone: up for an accent hit too softly, down otherwise.
      final up = grade.stroke.accent;
      final c = center.translate(-s * 0.42, -s * 0.42);
      final h = s * 0.13 * (up ? 1 : -1);
      final triangle = Path()
        ..moveTo(c.dx, c.dy - h)
        ..lineTo(c.dx + s * 0.15, c.dy + h)
        ..lineTo(c.dx - s * 0.15, c.dy + h)
        ..close();
      canvas.drawPath(
        triangle,
        Paint()
          ..color = AppColors.goldOutline
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.06
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(triangle, Paint()..color = AppColors.gold);
    }
  }

  @override
  bool shouldRepaint(_GradePainter old) => old.grade != grade;
}

class _BlockPainter extends CustomPainter {
  final Stroke stroke;
  final bool highlight;

  _BlockPainter({required this.stroke, required this.highlight});

  // The block's outline, within a box of side [s] centered on [center].
  Path _shape(Offset center, double s) {
    final dir = stroke.dir;
    if (dir == null && !stroke.accent) {
      return Path()..addOval(Rect.fromCenter(center: center, width: s, height: s));
    }
    if (dir == null) {
      return Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: s, height: s),
          Radius.circular(s * 0.29),
        ),
      );
    }
    // A drill-bit point at the bottom (down-stroke) or top (up-stroke), slightly narrower than
    // a square block so the point reads clearly.
    final w = s * 0.88;
    final left = center.dx - w / 2;
    final top = center.dy - s / 2;
    final points = dir == StrokeDir.D
        ? const [
            (0.14, 0.0),
            (0.86, 0.0),
            (1.0, 0.12),
            (1.0, 0.58),
            (0.5, 1.0),
            (0.0, 0.58),
            (0.0, 0.12),
          ]
        : const [
            (0.5, 0.0),
            (1.0, 0.42),
            (1.0, 0.88),
            (0.86, 1.0),
            (0.14, 1.0),
            (0.0, 0.88),
            (0.0, 0.42),
          ];
    return Path()
      ..addPolygon([for (final (x, y) in points) Offset(left + x * w, top + y * s)], true);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final colors = AppColors.handCandy(stroke.hand);
    // Leave room for the drop shadow below the full-size block.
    final s = size.width * (stroke.accent ? 0.92 : 0.76);
    final center = size.center(Offset(0, -size.width * 0.03));
    final shape = _shape(center, s);
    final bounds = shape.getBounds();
    final depth = s * 0.09;

    if (highlight) {
      // A wide soft halo behind the block, then a white ring around its own silhouette.
      final slot = size.width;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: slot * 1.25, height: slot * 1.25),
          Radius.circular(slot * 0.4),
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, slot * 0.2),
      );
      canvas.drawPath(
        _shape(center.translate(0, depth / 2), s + depth * 2),
        Paint()..color = Colors.white,
      );
    }

    // Solid drop shadow, then the candy body.
    canvas.drawPath(shape.shift(Offset(0, depth)), Paint()..color = colors.outline);
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.hi, colors.base, colors.lo],
          stops: const [0, 0.48, 1],
        ).createShader(bounds),
    );
    // Darker lip along the bottom, lighter one along the top.
    canvas.drawRect(
      Rect.fromLTRB(bounds.left, bounds.bottom - depth, bounds.right, bounds.bottom),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
    canvas.drawRect(
      Rect.fromLTRB(bounds.left, bounds.top, bounds.right, bounds.top + s * 0.06),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    if (stroke.accent) {
      // Icing: a band across the top with round drips hanging off it.
      final icing = Paint()..color = colors.icing;
      canvas.drawRect(
        Rect.fromLTRB(bounds.left, bounds.top, bounds.right, bounds.top + s * 0.18),
        icing,
      );
      for (final (x, y, r) in const [(0.2, 0.2, 0.12), (0.5, 0.235, 0.09), (0.8, 0.2, 0.12)]) {
        canvas.drawCircle(Offset(bounds.left + bounds.width * x, bounds.top + s * y), s * r, icing);
      }
    }
    if (stroke.dir == null) {
      // A little gloss highlight in the bottom-right corner.
      canvas.save();
      canvas.translate(bounds.right - s * 0.2, bounds.bottom - s * 0.22);
      canvas.rotate(-math.pi / 5);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 0.16, height: s * 0.09),
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
      canvas.restore();
    }
    canvas.restore();

    // The hand letter: white, outlined in the block's outline color.
    final letterCenter = switch (stroke.dir) {
      StrokeDir.D => Offset(center.dx, bounds.top + s * 0.4),
      StrokeDir.U => Offset(center.dx, bounds.top + s * 0.62),
      null => center.translate(0, stroke.accent ? s * 0.08 : 0),
    };
    final fontSize = s * (stroke.accent ? 0.5 : 0.52);
    final letter = stroke.hand == Hand.R ? 'R' : 'L';
    TextPainter mk(Paint foreground) => TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w900,
          foreground: foreground,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final outline = mk(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, fontSize * 0.22)
        ..strokeJoin = StrokeJoin.round
        ..color = colors.outline,
    );
    final fill = mk(Paint()..color = Colors.white);
    final origin = letterCenter - Offset(fill.width / 2, fill.height / 2);
    outline.paint(canvas, origin);
    fill.paint(canvas, origin);
    outline.dispose();
    fill.dispose();
  }

  @override
  bool shouldRepaint(covariant _BlockPainter oldDelegate) =>
      oldDelegate.stroke != stroke || oldDelegate.highlight != highlight;
}
