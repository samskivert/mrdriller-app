import 'package:flutter/material.dart';

import '../model/ear_check.dart';
import '../util/colors.dart';

/// Recent [beats] heard by an [EarCheck], newest first, as rows across a navy strip: each row
/// centered on its click, from half a click before it (left, early) to half a click after (right,
/// late), with the click's tone in blue and the player's hit in orange, so that where the hits
/// land, ahead of or behind the clicks, shows as a column of orange to one side of the blue. (A
/// row whose click had to be predicted, not found, has its tone faded.)
class EarRaster extends StatelessWidget {
  final List<EarBeat> beats;
  final double rowHeight;

  /// How many rows it has room for (so its height doesn't change as rows come in).
  final int rows;

  const EarRaster({super.key, required this.beats, this.rowHeight = 12, this.rows = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: rowHeight * rows + _EarRasterPainter.labelHeight + 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyTop, AppColors.navyBottom],
        ),
        border: Border.all(color: AppColors.panelBorder, width: 2),
      ),
      child: CustomPaint(painter: _EarRasterPainter(beats, rowHeight)),
    );
  }
}

const _toneColor = Color(0xFF5DB7F5);
final _hitColor = AppColors.candyOrange.base;

class _EarRasterPainter extends CustomPainter {
  static const labelHeight = 14.0;
  static const _margin = 10.0;

  final List<EarBeat> beats;
  final double rowHeight;

  _EarRasterPainter(this.beats, this.rowHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final left = _margin, right = size.width - _margin;
    final width = right - left;
    final top = labelHeight + 2;
    _label(canvas, 'EARLY', Offset(left, 2), 0);
    _label(canvas, 'CLICK', Offset(left + width / 2, 2), 0.5);
    _label(canvas, 'LATE', Offset(right, 2), 1);

    for (final (row, beat) in beats.indexed) {
      final y0 = top + row * rowHeight;
      final bottom = y0 + rowHeight - 1.5;
      final height = rowHeight - 2.5;
      void shape(List<double> values, Color color) {
        final path = Path()..moveTo(left, bottom);
        for (final (i, v) in values.indexed) {
          path.lineTo(left + width * (i + 0.5) / values.length, bottom - height * v);
        }
        path
          ..lineTo(right, bottom)
          ..close();
        canvas.drawPath(path, Paint()..color = color);
      }

      shape(beat.tone, _toneColor.withValues(alpha: beat.clickMatched ? 0.7 : 0.3));
      shape(beat.hit, _hitColor.withValues(alpha: 0.9));
      // Where the hit was found to start.
      if (beat.hitMs case final ms?) {
        final x = left + width / 2 + width / 2 * (ms / beat.halfMs).clamp(-1, 1);
        canvas.drawLine(
          Offset(x, y0 + 0.5),
          Offset(x, bottom),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 1.5,
        );
      }
    }
    // The click's moment.
    canvas.drawLine(
      Offset(left + width / 2, top),
      Offset(left + width / 2, size.height - 4),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
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
          color: AppColors.panelBorder,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at.translate(-painter.width * align, 0));
  }

  @override
  bool shouldRepaint(_EarRasterPainter old) =>
      old.beats.length != beats.length ||
      (beats.isNotEmpty && old.beats.first.index != beats.first.index) ||
      old.rowHeight != rowHeight;
}
