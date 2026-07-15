import 'package:flutter/material.dart';

import '../model/model.dart';
import 'components.dart';
import 'measure_view.dart';

class _OverviewSectionView extends StatelessWidget {
  final Section section;

  const _OverviewSectionView({required this.section});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        // IntrinsicWidth shrinks this card to the width its content actually needs, instead of
        // the header Row and per-line Wrap each greedily claiming all space offered by the
        // ancestor Wrap (which would stretch every card to the full row width).
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                label: section.label,
                repeatDisplay: section.repeat > 1 ? 'x${section.repeat}' : null,
              ),
              const SizedBox(height: 8),
              for (final line in section.lines)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  // The 4px gaps between measures are inserted as explicit SizedBox children
                  // rather than Wrap's `spacing` property: RenderWrap.computeMaxIntrinsicWidth
                  // sums each child's width but omits `spacing`, so with `spacing` alone the
                  // ancestor IntrinsicWidth above computes a width a few pixels narrower than a
                  // single row actually needs — just enough to make the Wrap wrap early even
                  // when there's plenty of room, while still occupying the wider (wrong) width.
                  // Making the gaps real children keeps them in that sum, so the two agree.
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < line.measures.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        MeasureView(measure: line.measures[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowView extends StatelessWidget {
  final DrillRow row;

  const _RowView({required this.row});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [for (final section in row) _OverviewSectionView(section: section)],
    );
  }
}

/// A static (non-playing) preview of an entire drill's rows/sections/lines/measures, shown before
/// practice starts.
class DrillOverviewView extends StatelessWidget {
  final Drill drill;

  const DrillOverviewView({super.key, required this.drill});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [for (final row in drill.rows) Padding(padding: const EdgeInsets.only(bottom: 16), child: _RowView(row: row))],
      ),
    );
  }
}
