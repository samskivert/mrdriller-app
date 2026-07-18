import 'dart:math' as math;

import '../model/model.dart';

/// The stroke/gap/padding/font sizes for rendering a section's beat visualization, sized to
/// exactly fit some measured available width rather than picked from a fixed set of presets.
class SizeConfig {
  final double strokeSize;
  final double measureGap;
  final double cardPadding;
  final double labelFontSize;
  final double repeatFontSize;

  const SizeConfig({
    required this.strokeSize,
    required this.measureGap,
    required this.cardPadding,
    required this.labelFontSize,
    required this.repeatFontSize,
  });
}

const double _strokeMargin = 8; // 4px margin on each side in StrokeView

// measureGap and cardPadding scale with strokeSize (rather than being independent inputs) so the
// whole card's proportions stay visually consistent as it grows/shrinks, while still leaving
// strokeSize as the single unknown in the width equation below.
const double _measureGapRatio = 0.09;
const double _cardPaddingRatio = 0.13;
const double _fontRatio = 0.22;

const double minStrokeSize = 16;
const double maxStrokeSize = 200;
const double _minFontSize = 12;
const double _maxFontSize = 40;

// Used when a line is too dense to ever fit in one row/column even at minStrokeSize (wrapping
// is unavoidable either way, so there's no reason to also make it tiny) -- matches the fixed
// default MeasureView.strokeSize the static drill-overview always renders at.
const double wrapFallbackStrokeSize = 28;

// A labeled beat adds a text row above its strokes (see _BeatView): a strokeSize*0.7 box plus
// strokeSize*0.14 of padding beneath it.
const double _labelRowHeightRatio = 0.84;
// Approximate line-height factor for the section header's bold text (label / repeat dots).
const double _headerLineHeightRatio = 1.3;

/// The shape (in beats and measures) of the widest line across a set of sections — the only
/// thing that determines how large strokes can be drawn, independent of any particular screen
/// width. Beats are what actually take up horizontal room; measures matter only for the gaps
/// between them.
typedef LineShape = ({int beats, int measures});

LineShape widestLineShape(Iterable<Section> sections) {
  var widestBeats = 0;
  var widestMeasures = 0;
  for (final section in sections) {
    for (final line in section.lines) {
      final lineBeats = line.measures.fold<int>(0, (sum, m) => sum + m.length);
      if (lineBeats > widestBeats) {
        widestBeats = lineBeats;
        widestMeasures = line.measures.length;
      }
    }
  }
  return (beats: widestBeats, measures: widestMeasures);
}

/// The widest line across an entire drill, used so every section in the drill renders at the
/// same, consistent size rather than each section sizing independently to its own content.
LineShape drillWidestLineShape(Drill drill) =>
    widestLineShape(drill.rows.expand((row) => row));

/// The vertical shape of one section that determines how tall it renders at a given strokeSize:
/// how many lines stack, whether any beat anywhere in the section shows a label above it (which
/// adds a label row), and the deepest simultaneous stroke stack (e.g. two hands landing on the
/// same beat, stacked vertically). [hasLabelRow] and [maxStrokes] apply to every line uniformly
/// (using the tallest found anywhere in the section) rather than tracking it per line -- that
/// slightly overestimates shorter lines' height, but never underestimates the section's actual
/// rendered height, which is what matters for avoiding overflow.
typedef SectionVerticalShape = ({
  int lines,
  bool hasHeader,
  bool hasLabelRow,
  int maxStrokes,
});

SectionVerticalShape sectionVerticalShape(Section section) {
  final hasHeader = (section.label?.isNotEmpty ?? false) || section.repeat > 1;
  var hasLabelRow = false;
  var maxStrokes = 1;
  for (final line in section.lines) {
    for (final measure in line.measures) {
      for (final beat in measure) {
        if (beat == null) continue;
        if (beat.label != null) hasLabelRow = true;
        if (beat.strokes.length > maxStrokes) maxStrokes = beat.strokes.length;
      }
    }
  }
  return (
    lines: section.lines.length,
    hasHeader: hasHeader,
    hasLabelRow: hasLabelRow,
    maxStrokes: maxStrokes,
  );
}

/// Solves for the exact stroke size that makes the widest line fit within [availableWidth], and
/// (when [availableHeight] is finite) that also makes [section] itself fit within that height —
/// the smaller of the two wins. Both are the real sizes Flutter measured via LayoutBuilder at the
/// actual render point (i.e. already net of every ancestor's padding/borders), not an estimate
/// from the window size minus a guessed overhead.
///
/// Width: [availableWidth] is measured *before* this section's own cardPadding is applied, so the
/// equation must subtract that padding too (it isn't free space the beat row gets to use):
///   availableWidth = beats*(strokeSize + margin) + (measures-1)*(strokeSize*gapRatio)
///                    + 2*(strokeSize*paddingRatio)
///
/// Height: analogous, built from [section]'s own [SectionVerticalShape] (line count, whether any
/// line needs a label row, and the deepest simultaneous stroke stack) rather than [widestLine] --
/// a section's height depends on its own content, not the drill-wide widest line:
///   availableHeight = (hasHeader ? strokeSize*fontRatio*headerLineHeightRatio : 0)
///                    + strokeSize*paddingRatio*0.6                      (gap below header)
///                    + lines*((hasLabelRow ? strokeSize*labelRowRatio : 0)
///                             + maxStrokes*(strokeSize + margin))
///                    + (lines-1)*(strokeSize*gapRatio)
///                    + 2*(strokeSize*paddingRatio)                     (top/bottom cardPadding)
///
/// Each is a single linear equation in strokeSize, solved directly — no presets, no fudge factor,
/// and (up to the min/max legibility clamp) no possibility of the section overflowing its card.
SizeConfig computeFittedSizeConfig({
  required LineShape widestLine,
  required double availableWidth,
  required Section section,
  double availableHeight = double.infinity,
}) {
  final beats = widestLine.beats;
  final measures = widestLine.measures;
  if (beats == 0) {
    const fallback = 90.0;
    return const SizeConfig(
      strokeSize: fallback,
      measureGap: fallback * _measureGapRatio,
      cardPadding: fallback * _cardPaddingRatio,
      labelFontSize: 20,
      repeatFontSize: 20,
    );
  }

  // A few pixels of safety margin: HighlightedCard's border is painted straddling its own edge
  // (part of the stroke can fall just outside the box the child was actually given), and
  // sub-pixel layout rounding can shave off a hair more. Better to solve for a strokeSize that's
  // a touch smaller than exactly-fitting than to land exactly on the edge and clip.
  const safetyMargin = 6.0;
  // Includes 2*_cardPaddingRatio: the card's own left+right padding is also a function of
  // strokeSize, and it comes out of availableWidth before the beat row sees any of it.
  final widthDenominator =
      beats + (measures - 1) * _measureGapRatio + 2 * _cardPaddingRatio;
  final widthStrokeSize =
      (availableWidth - safetyMargin - beats * _strokeMargin) /
      widthDenominator;

  var heightStrokeSize = double.infinity;
  if (availableHeight.isFinite) {
    final shape = sectionVerticalShape(section);
    if (shape.lines > 0) {
      final heightDenominator =
          (shape.hasHeader ? _fontRatio * _headerLineHeightRatio : 0.0) +
          _cardPaddingRatio * 0.6 +
          shape.lines * (shape.hasLabelRow ? _labelRowHeightRatio : 0.0) +
          shape.lines * shape.maxStrokes +
          (shape.lines - 1) * _measureGapRatio +
          2 * _cardPaddingRatio;
      final heightConstant = shape.lines * shape.maxStrokes * _strokeMargin;
      heightStrokeSize =
          (availableHeight - safetyMargin - heightConstant) / heightDenominator;
    }
  }

  final rawStrokeSize = math.min(widthStrokeSize, heightStrokeSize);
  // Below minStrokeSize means even the smallest legible stroke can't make this line fit in one
  // row/column (a pathologically dense line -- e.g. 64 beats in one line) -- clamping up to
  // minStrokeSize wouldn't actually prevent wrapping there, it would just make the wrapped
  // result tiny *and* wrapped. Once wrapping is unavoidable anyway, a comfortable, legible size
  // (matching the static drill-overview's fixed default) beats the smallest possible one.
  final strokeSize = rawStrokeSize < minStrokeSize
      ? wrapFallbackStrokeSize
      : rawStrokeSize.clamp(minStrokeSize, maxStrokeSize);
  final fontSize = (strokeSize * _fontRatio).clamp(_minFontSize, _maxFontSize);

  return SizeConfig(
    strokeSize: strokeSize,
    measureGap: strokeSize * _measureGapRatio,
    cardPadding: strokeSize * _cardPaddingRatio,
    labelFontSize: fontSize,
    repeatFontSize: fontSize,
  );
}
