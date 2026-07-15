import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/model.dart';
import 'components.dart';
import 'stroke_view.dart';

class _BeatView extends StatelessWidget {
  final Beat beat;
  final bool forceLabel;
  final bool highlight;
  final double strokeSize;

  const _BeatView({
    required this.beat,
    required this.forceLabel,
    required this.highlight,
    required this.strokeSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (forceLabel)
          Padding(
            padding: EdgeInsets.only(bottom: (strokeSize * 0.14).roundToDouble()),
            child: SizedBox(
              height: (strokeSize * 0.7).roundToDouble(),
              child: Center(
                child: Text(
                  beat.label ?? '',
                  style: TextStyle(fontSize: math.max(10, (strokeSize * 0.45).roundToDouble())),
                ),
              ),
            ),
          ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final stroke in beat.strokes)
              StrokeView(stroke: stroke, highlight: highlight, size: strokeSize),
          ],
        ),
      ],
    );
  }
}

/// Renders a single measure: a horizontal run of beats, each of which may hold one or more
/// stacked strokes (for multi-hand beats), a label above it, or be an empty placeholder.
class MeasureView extends StatelessWidget {
  final Measure measure;
  final int? highlightBeat;
  final double strokeSize;

  const MeasureView({super.key, required this.measure, this.highlightBeat, this.strokeSize = 28});

  @override
  Widget build(BuildContext context) {
    final hasAnyLabels = measure.any((b) => b?.label != null);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < measure.length; i++)
          measure[i] == null
              ? EmptyBeatPlaceholder(strokeSize: strokeSize)
              : _BeatView(
                  beat: measure[i]!,
                  forceLabel: hasAnyLabels,
                  highlight: i == highlightBeat,
                  strokeSize: strokeSize,
                ),
      ],
    );
    // A measure's beats are never meant to wrap onto a new line (unlike the measures within a
    // line, which can). SectionView computes strokeSize to fit this row exactly, but the result
    // is clamped to a legible min/max size — so on a pathologically narrow screen with a
    // many-beat measure, the exact fit could still be smaller than that floor. A scroll view
    // turns that edge case into a horizontal scroll instead of a hard layout overflow.
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: row);
  }
}
