// The fanciest badge on the practice calendars, for a day with twenty minutes or more of practice
// (see PracticeDayCell): a taiko drum head whose mitsudomoe is a slowly turning rainbow, with
// sparkles twinkling around it.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../util/colors.dart';
import 'taiko_drum_head.dart';

/// The rainbow drum, [size] square: the drum head in the middle, and the sparkles in the corners,
/// overlapping its edge. [seed] sets where in its cycle it starts, so that drums side by side don't
/// turn and twinkle in step. It holds still if animations are turned off.
class RainbowDrum extends StatefulWidget {
  final double size;
  final int seed;

  const RainbowDrum({super.key, required this.size, this.seed = 0});

  @override
  State<RainbowDrum> createState() => _RainbowDrumState();
}

class _RainbowDrumState extends State<RainbowDrum> with SingleTickerProviderStateMixin {
  // One cycle is one turn of the mitsudomoe, in which each sparkle twinkles a whole number of
  // times, so it loops seamlessly.
  late final _cycle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
    value: (widget.seed % 997) / 997,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _cycle.stop();
    } else if (!_cycle.isAnimating) {
      _cycle.repeat();
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(size: Size.square(widget.size), painter: _RainbowDrumPainter(_cycle)),
  );
}

class _RainbowDrumPainter extends CustomPainter {
  final Animation<double> cycle;

  _RainbowDrumPainter(this.cycle) : super(repaint: cycle);

  // Where each sparkle is (as fractions of the size), how many times it twinkles per cycle, when
  // in the cycle it starts, and whether it's gold (or white).
  static const _sparkles = [
    (x: 0.16, y: 0.18, twinkles: 3, phase: 0.0, gold: false),
    (x: 0.85, y: 0.22, twinkles: 5, phase: 0.4, gold: true),
    (x: 0.82, y: 0.85, twinkles: 4, phase: 0.75, gold: false),
    (x: 0.15, y: 0.82, twinkles: 2, phase: 0.25, gold: true),
  ];

  static final _rainbow = SweepGradient(
    colors: [...AppColors.rainbow, AppColors.rainbow.first],
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));

  @override
  void paint(Canvas canvas, Size size) {
    final t = cycle.value;
    final center = size.center(Offset.zero);
    final radius = size.width * 0.41;
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * 2 * math.pi);
    paintMitsudomoe(canvas, Offset.zero, radius, Paint()..shader = _rainbow);
    canvas.restore();

    for (final s in _sparkles) {
      // Each twinkle grows and shrinks back over the first half of its time, then it's gone for
      // the second half.
      final f = (t * s.twinkles + s.phase) % 1;
      if (f >= 0.5) continue;
      final r = size.width * 0.13 * math.sin(math.pi * f * 2);
      final at = Offset(size.width * s.x, size.height * s.y);
      canvas.drawPath(_sparkle(at, r), Paint()..color = s.gold ? AppColors.gold : Colors.white);
    }
  }

  // A four-pointed sparkle of radius [r] around [at], its sides curving in to the middle.
  static Path _sparkle(Offset at, double r) => Path()
    ..moveTo(at.dx, at.dy - r)
    ..quadraticBezierTo(at.dx, at.dy, at.dx + r, at.dy)
    ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r)
    ..quadraticBezierTo(at.dx, at.dy, at.dx - r, at.dy)
    ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r)
    ..close();

  @override
  bool shouldRepaint(covariant _RainbowDrumPainter oldDelegate) => oldDelegate.cycle != cycle;
}
