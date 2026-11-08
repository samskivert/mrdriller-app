import 'package:flutter/material.dart';

import '../util/colors.dart';

/// How one click of a play-along calibration went.
enum CalibrationCellKind {
  /// Not checked yet (or not played yet).
  pending,

  /// A click of the count-in (listened to, not played), heard by the microphone.
  clickHeard,

  /// A click of the count-in that the microphone didn't hear.
  clickNotHeard,

  /// A click played along to, whose hit was heard.
  hitHeard,

  /// A click played along to, whose hit came in from the pad but wasn't heard (too faint, or
  /// masked), so is shown where it's expected to have been.
  hitNotHeard,

  /// A click played along to without a hit.
  missed,
}

class CalibrationCell {
  final CalibrationCellKind kind;

  /// How far from its click the hit was, in milliseconds (negative if early), for a hit.
  final double? offsetMs;

  const CalibrationCell(this.kind, [this.offsetMs]);

  static const pending = CalibrationCell(CalibrationCellKind.pending);
}

/// Every click of a play-along calibration, as a grid of [perRow] a row (the first [countIn] being
/// the count-in, to listen to), each checked off as it's heard: with a mark of how far from the
/// click its hit was, from [scaleMs] early (the cell's left edge) to [scaleMs] late (its right),
/// and the click being played now ([current]) outlined.
class CalibrationGrid extends StatelessWidget {
  final List<CalibrationCell> cells;
  final int countIn;
  final int perRow;

  /// How many clicks a beat has, which are grouped together.
  final int clicksPerBeat;

  /// The click sounding now, or null if none is.
  final int? current;
  final double scaleMs;

  const CalibrationGrid({
    super.key,
    required this.cells,
    required this.countIn,
    this.perRow = 8,
    this.clicksPerBeat = 2,
    this.current,
    this.scaleMs = 80,
  });

  static const _cellHeight = 22.0;
  static const _rowGap = 6.0;
  static const _padding = 10.0;

  @override
  Widget build(BuildContext context) {
    final rows = (cells.length / perRow).ceil();
    return Container(
      height: rows * (_cellHeight + _rowGap) - _rowGap + _padding * 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyTop, AppColors.navyBottom],
        ),
        border: Border.all(color: AppColors.panelBorder, width: 2),
      ),
      child: CustomPaint(painter: _GridPainter(this)),
    );
  }
}

const _clickColor = Color(0xFF5DB7F5);
final _hitColor = AppColors.candyOrange.base;

class _GridPainter extends CustomPainter {
  final CalibrationGrid grid;

  _GridPainter(this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    const pad = CalibrationGrid._padding;
    const cellGap = 3.0, beatGap = 8.0;
    final beatsPerRow = grid.perRow / grid.clicksPerBeat;
    final cellWidth =
        (size.width -
            pad * 2 -
            (beatsPerRow - 1) * beatGap -
            (grid.perRow - beatsPerRow) * cellGap) /
        grid.perRow;
    for (final (i, cell) in grid.cells.indexed) {
      final row = i ~/ grid.perRow, column = i % grid.perRow;
      final beat = column ~/ grid.clicksPerBeat;
      final left = pad + column * cellWidth + beat * beatGap + (column - beat) * cellGap;
      final top = pad + row * (CalibrationGrid._cellHeight + CalibrationGrid._rowGap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, cellWidth, CalibrationGrid._cellHeight),
        const Radius.circular(5),
      );
      final listen = i < grid.countIn;
      final fill = switch (cell.kind) {
        CalibrationCellKind.pending => Colors.white.withValues(alpha: listen ? 0.10 : 0.06),
        CalibrationCellKind.clickHeard => _clickColor,
        CalibrationCellKind.clickNotHeard => Colors.white.withValues(alpha: 0.25),
        CalibrationCellKind.hitHeard => _hitColor,
        CalibrationCellKind.hitNotHeard => _hitColor.withValues(alpha: 0.35),
        CalibrationCellKind.missed => Colors.white.withValues(alpha: 0.18),
      };
      canvas.drawRRect(rect, Paint()..color = fill);
      final center = rect.center;
      switch (cell.kind) {
        case CalibrationCellKind.clickHeard:
          _check(canvas, center);
        case CalibrationCellKind.clickNotHeard || CalibrationCellKind.missed:
          _cross(canvas, center);
        case CalibrationCellKind.hitHeard || CalibrationCellKind.hitNotHeard:
          // The click's moment, and the hit's.
          canvas.drawLine(
            Offset(center.dx, top + 3),
            Offset(center.dx, top + CalibrationGrid._cellHeight - 3),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.4)
              ..strokeWidth = 1,
          );
          final offset = ((cell.offsetMs ?? 0) / grid.scaleMs).clamp(-1.0, 1.0);
          final x = center.dx + offset * (cellWidth / 2 - 2);
          canvas.drawLine(
            Offset(x, top + 2),
            Offset(x, top + CalibrationGrid._cellHeight - 2),
            Paint()
              ..color = Colors.white
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round,
          );
        case CalibrationCellKind.pending:
          break;
      }
      if (i == grid.current) {
        canvas.drawRRect(
          rect.inflate(1.5),
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _check(Canvas canvas, Offset c) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 5, c.dy)
        ..lineTo(c.dx - 1.5, c.dy + 4)
        ..lineTo(c.dx + 5, c.dy - 4),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _cross(Canvas canvas, Offset c) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(-4, -4), c.translate(4, 4), paint);
    canvas.drawLine(c.translate(-4, 4), c.translate(4, -4), paint);
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}
