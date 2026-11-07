import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../util/colors.dart';

/// How early or late hits were ([errors], in milliseconds, negative if early), as a histogram from
/// early (left) to late (right): a bar for each 5ms, colored for its judgement, perfect (within
/// [perfectMs] of the beat) gold, good (within [goodMs]) green, and early or late pink, over
/// faint bands of those colors. The beat and the [mean] are marked.
class TimingChart extends StatelessWidget {
  final List<double> errors;
  final double perfectMs;
  final double goodMs;
  final double mean;
  final double height;

  const TimingChart({
    super.key,
    required this.errors,
    required this.perfectMs,
    required this.goodMs,
    required this.mean,
    this.height = 64,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _TimingChartPainter(errors, perfectMs, goodMs, mean),
        size: Size.infinite,
      ),
    );
  }
}

// The colors of the judgements' bands and marks, as on the strokes.
final _perfect = AppColors.gold;
final _good = AppColors.candyGreen.base;
final _off = AppColors.candyPink.base;

class _TimingChartPainter extends CustomPainter {
  static const bucketMs = 5.0;
  static const _labelHeight = 12.0;

  final List<double> errors;
  final double perfectMs;
  final double goodMs;
  final double mean;

  _TimingChartPainter(this.errors, this.perfectMs, this.goodMs, this.mean);

  // How far either side of the beat it shows: twice the good window, or out to the farthest hit
  // (in whole buckets), up to the farthest a hit can be from its stroke.
  double get _range {
    final farthest = errors.fold(0.0, (m, e) => math.max(m, e.abs()));
    return math.min(120, math.max(goodMs * 2, (farthest / bucketMs).ceil() * bucketMs));
  }

  Color _colorAt(double ms) => ms.abs() <= perfectMs
      ? _perfect
      : ms.abs() <= goodMs
      ? _good
      : _off;

  @override
  void paint(Canvas canvas, Size size) {
    final range = _range;
    final chart = Rect.fromLTRB(0, 0, size.width, size.height - _labelHeight);
    double x(double ms) => chart.left + chart.width * (ms + range) / (range * 2);

    // The judgements' bands, faintly.
    for (final (from, to, color) in [
      (-range, -goodMs, _off),
      (-goodMs, -perfectMs, _good),
      (-perfectMs, perfectMs, _perfect),
      (perfectMs, goodMs, _good),
      (goodMs, range, _off),
    ]) {
      canvas.drawRect(
        Rect.fromLTRB(x(from), chart.top, x(to), chart.bottom),
        Paint()..color = color.withValues(alpha: 0.16),
      );
    }

    _paintBars(canvas, chart, x);

    // The beat, the baseline, and the average.
    final ink = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(x(0), chart.top), Offset(x(0), chart.bottom), ink);
    canvas.drawLine(Offset(chart.left, chart.bottom), Offset(chart.right, chart.bottom), ink);
    if (errors.isNotEmpty) {
      final m = x(mean.clamp(-range, range));
      canvas.drawLine(
        Offset(m, chart.top),
        Offset(m, chart.bottom),
        Paint()
          ..color = AppColors.bannerBlue
          ..strokeWidth = 2.5,
      );
      canvas.drawPath(
        Path()
          ..moveTo(m - 5, chart.top)
          ..lineTo(m + 5, chart.top)
          ..lineTo(m, chart.top + 6)
          ..close(),
        Paint()..color = AppColors.bannerBlue,
      );
    }

    // Labels below: early, the good window's edges, late.
    _label(canvas, 'EARLY', Offset(chart.left, chart.bottom + 1), 0);
    _label(canvas, 'LATE', Offset(chart.right, chart.bottom + 1), 1);
    for (final ms in [-goodMs, goodMs]) {
      _label(canvas, '${ms.round().abs()}', Offset(x(ms), chart.bottom + 1), 0.5);
    }
  }

  // How many hits fell in each bucket, from the earliest bucket.
  List<int> _buckets(double range) {
    final count = (range * 2 / bucketMs).round();
    final buckets = List.filled(count, 0);
    for (final e in errors) {
      final i = ((e + range) / bucketMs).floor().clamp(0, count - 1);
      buckets[i]++;
    }
    return buckets;
  }

  void _paintBars(Canvas canvas, Rect chart, double Function(double) x) {
    final range = _range;
    final buckets = _buckets(range);
    final tallest = buckets.fold(1, math.max);
    for (final (i, n) in buckets.indexed) {
      if (n == 0) continue;
      final from = -range + i * bucketMs;
      final rect = Rect.fromLTRB(
        x(from) + 0.75,
        chart.bottom - (chart.height - 8) * n / tallest,
        x(from + bucketMs) - 0.75,
        chart.bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        Paint()..color = _colorAt(from + bucketMs / 2),
      );
    }
  }

  void _label(Canvas canvas, String text, Offset at, double align) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 9,
          height: 1.1,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: AppColors.inkMuted,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at.translate(-painter.width * align, 0));
  }

  @override
  bool shouldRepaint(_TimingChartPainter old) =>
      old.errors != errors ||
      old.perfectMs != perfectMs ||
      old.goodMs != goodMs ||
      old.mean != mean;
}
