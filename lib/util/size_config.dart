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
LineShape drillWidestLineShape(Drill drill) => widestLineShape(drill.rows.expand((row) => row));

/// Solves for the exact stroke size that makes the widest line fit within [availableWidth] —
/// the real width Flutter measured via LayoutBuilder at the actual render point (i.e. already
/// net of every ancestor's padding/borders), not an estimate of the window width minus a guessed
/// overhead. [availableWidth] is measured *before* this section's own cardPadding is applied, so
/// the equation must subtract that padding too (it isn't free space the beat row gets to use):
///   availableWidth = beats*(strokeSize + margin) + (measures-1)*(strokeSize*gapRatio)
///                    + 2*(strokeSize*paddingRatio)
/// this is a single linear equation in strokeSize, solved directly — no presets, no fudge factor,
/// and (up to the min/max legibility clamp) no possibility of the beat row overflowing its card.
SizeConfig computeFittedSizeConfig({required LineShape widestLine, required double availableWidth}) {
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
  final denominator = beats + (measures - 1) * _measureGapRatio + 2 * _cardPaddingRatio;
  final rawStrokeSize = (availableWidth - safetyMargin - beats * _strokeMargin) / denominator;
  final strokeSize = rawStrokeSize.clamp(minStrokeSize, maxStrokeSize);
  final fontSize = (strokeSize * _fontRatio).clamp(_minFontSize, _maxFontSize);

  return SizeConfig(
    strokeSize: strokeSize,
    measureGap: strokeSize * _measureGapRatio,
    cardPadding: strokeSize * _cardPaddingRatio,
    labelFontSize: fontSize,
    repeatFontSize: fontSize,
  );
}
