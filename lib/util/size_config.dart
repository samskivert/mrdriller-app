import 'dart:math' as math;

import '../model/model.dart';

/// The stroke/gap/padding/font sizes for rendering a section's beat visualization, sized to
/// exactly fit some measured available width rather than picked from a fixed set of presets.
class SizeConfig {
  final double strokeSize;
  final double measureGap;
  final double cardPadding;
  final double headerHeight;
  final double labelFontSize;
  final double repeatFontSize;

  const SizeConfig({
    required this.strokeSize,
    required this.measureGap,
    required this.cardPadding,
    required this.headerHeight,
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

const double minStrokeSize = 16;
const double maxStrokeSize = 200;
const double _maxFontSize = 40;

// The smallest stroke size a line is drawn at before it's wrapped onto more rows instead -- a
// comfortable size, matching the fixed default MeasureView.strokeSize the static drill-overview
// always renders at. See computeFittedSizeConfig.
const double minUnwrappedStrokeSize = 28;

// A labeled beat adds a text row above its strokes (see _BeatView): a strokeSize*0.7 box plus
// strokeSize*0.14 of padding beneath it.
const double _labelRowHeightRatio = 0.84;
// Height of the section header (its label banner), and the label's font size within it. The
// header scales exactly with strokeSize (no clamping) so that it stays a linear term in the height
// equation below. See SectionView.
const double headerRatio = 0.7;
const double headerFontRatio = 0.5;

/// The shape (in beats and measures) of the widest line within a section — the only thing that
/// determines how large strokes can be drawn for that section, independent of any particular
/// screen width or of how other sections in the same drill are sized. Beats are what actually
/// take up horizontal room; measures matter only for the gaps between them.
typedef LineShape = ({int beats, int measures});

LineShape widestLineShape(Section section) {
  var widestBeats = 0;
  var widestMeasures = 0;
  for (final line in section.lines) {
    final lineBeats = line.measures.fold<int>(0, (sum, m) => sum + m.length);
    if (lineBeats > widestBeats) {
      widestBeats = lineBeats;
      widestMeasures = line.measures.length;
    }
  }
  return (beats: widestBeats, measures: widestMeasures);
}

/// The vertical shape of one section that determines how tall it renders at a given strokeSize:
/// how many lines stack, whether any beat anywhere in the section shows a label above it (which
/// adds a label row), and the deepest simultaneous stroke stack (e.g. two hands landing on the
/// same beat, stacked vertically). [hasLabelRow] and [maxStrokes] apply to every line uniformly
/// (using the tallest found anywhere in the section) rather than tracking it per line -- that
/// slightly overestimates shorter lines' height, but never underestimates the section's actual
/// rendered height, which is what matters for avoiding overflow.
typedef SectionVerticalShape = ({int lines, bool hasHeader, bool hasLabelRow, int maxStrokes});

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

/// The shape of one way of wrapping a section's lines: every line broken into rows of (at most)
/// [measuresPerRow] consecutive measures -- [Wrap] only ever breaks between measures, never within
/// one. [widestRow] is the widest such row anywhere in the section (what the width equation must
/// fit), and [rows] is the total number of rows across every line (what the height equation must
/// fit, in place of the unwrapped line count).
typedef WrapShape = ({int measuresPerRow, LineShape widestRow, int rows});

WrapShape wrapShape(Section section, int measuresPerRow) {
  var widestBeats = 0;
  var widestMeasures = 0;
  var rows = 0;
  for (final line in section.lines) {
    final measures = line.measures;
    // An empty line still takes up a (zero-content) row's worth of gap in the layout.
    rows += math.max(1, (measures.length / measuresPerRow).ceil());
    for (var start = 0; start < measures.length; start += measuresPerRow) {
      final row = measures.skip(start).take(measuresPerRow);
      final beats = row.fold<int>(0, (sum, m) => sum + m.length);
      if (beats > widestBeats) {
        widestBeats = beats;
        widestMeasures = row.length;
      }
    }
  }
  return (
    measuresPerRow: measuresPerRow,
    widestRow: (beats: widestBeats, measures: widestMeasures),
    rows: rows,
  );
}

/// Solves for the largest stroke size at which [section] fits within [availableWidth] and (when
/// [availableHeight] is finite) [availableHeight], also choosing how many measures to put on each
/// row when a line is too dense to be drawn legibly on one. Sized entirely from [section]'s own
/// content: two sections in the same drill can end up different sizes if one has more room to work
/// with or simply needs less space, rather than every section being squeezed to fit whichever
/// section in the drill happens to be the widest. Both dimensions are the real sizes Flutter
/// measured via LayoutBuilder at the actual render point (i.e. already net of every ancestor's
/// padding/borders), not an estimate from the window size minus a guessed overhead.
///
/// For a given wrapping (see [WrapShape]), width and height each give a single linear equation in
/// strokeSize, solved directly, and the smaller of the two wins.
///
/// Width: [availableWidth] is measured *before* this section's own cardPadding is applied, so the
/// equation must subtract that padding too (it isn't free space the beat row gets to use):
///   availableWidth = beats*(strokeSize + margin) + (measures-1)*(strokeSize*gapRatio)
///                    + 2*(strokeSize*paddingRatio)
/// where beats/measures come from the widest row (see [WrapShape.widestRow]).
///
/// Height: analogous, built from [section]'s own [SectionVerticalShape] (whether any line needs a
/// label row, and the deepest simultaneous stroke stack) and the wrapping's total row count (rows
/// are separated by the same gap whether they're separate lines or one line wrapped):
///   availableHeight = (hasHeader ? strokeSize*headerRatio : 0)
///                    + strokeSize*paddingRatio*0.6                      (gap below header)
///                    + rows*((hasLabelRow ? strokeSize*labelRowRatio : 0)
///                            + maxStrokes*(strokeSize + margin))
///                    + (rows-1)*(strokeSize*gapRatio)
///                    + 2*(strokeSize*paddingRatio)                     (top/bottom cardPadding)
///
/// Choosing the wrapping: lines stay as unwrapped as possible -- the fewest rows that still allow a
/// comfortable [minUnwrappedStrokeSize] -- since wrapping a line that could be read fine on one
/// row just to draw it bigger would be a worse layout, not a better one. Only when no wrapping
/// manages that (e.g. the Sixteens drill's 64-beat lines) does it pick whichever wrapping gives the
/// largest strokes outright.
///
/// The solved wrapping is guaranteed to fit, not merely estimated to: [Wrap] packs each row
/// greedily (as many measures as fit), and greedy packing never needs more rows than any other
/// packing that fits -- including the fixed groups of measuresPerRow measures solved for here.
SizeConfig computeFittedSizeConfig({
  required double availableWidth,
  required Section section,
  double availableHeight = double.infinity,
}) {
  final maxMeasures = section.lines.fold<int>(0, (most, l) => math.max(most, l.measures.length));
  if (widestLineShape(section).beats == 0) {
    const fallback = 90.0;
    return const SizeConfig(
      strokeSize: fallback,
      measureGap: fallback * _measureGapRatio,
      cardPadding: fallback * _cardPaddingRatio,
      headerHeight: fallback * headerRatio,
      labelFontSize: 20,
      repeatFontSize: 20,
    );
  }

  final vertical = sectionVerticalShape(section);
  double? best;
  // From the fewest rows (every line unwrapped) to the most (one measure per row).
  for (var measuresPerRow = maxMeasures; measuresPerRow >= 1; measuresPerRow--) {
    final size = _fittedStrokeSize(
      wrapShape(section, measuresPerRow),
      vertical,
      availableWidth,
      availableHeight,
    );
    if (size >= minUnwrappedStrokeSize) {
      best = size;
      break;
    }
    if (best == null || size > best) best = size;
  }

  final strokeSize = best!.clamp(minStrokeSize, maxStrokeSize);
  final headerHeight = strokeSize * headerRatio;
  final fontSize = math.min(headerHeight * headerFontRatio, _maxFontSize);

  return SizeConfig(
    strokeSize: strokeSize,
    measureGap: strokeSize * _measureGapRatio,
    cardPadding: strokeSize * _cardPaddingRatio,
    headerHeight: headerHeight,
    labelFontSize: fontSize,
    repeatFontSize: fontSize,
  );
}

/// The unclamped stroke size that fits one particular wrapping of a section into the available
/// space -- see [computeFittedSizeConfig] for the equations.
double _fittedStrokeSize(
  WrapShape wrap,
  SectionVerticalShape vertical,
  double availableWidth,
  double availableHeight,
) {
  // A few pixels of safety margin: a panel's border is painted straddling its own edge
  // (part of the stroke can fall just outside the box the child was actually given), and
  // sub-pixel layout rounding can shave off a hair more. Better to solve for a strokeSize that's
  // a touch smaller than exactly-fitting than to land exactly on the edge and clip (or, for a
  // wrapped line, to have Wrap break a row one measure earlier than solved for).
  const safetyMargin = 6.0;

  final beats = wrap.widestRow.beats;
  final measures = wrap.widestRow.measures;
  // Includes 2*_cardPaddingRatio: the card's own left+right padding is also a function of
  // strokeSize, and it comes out of availableWidth before the beat row sees any of it.
  final widthDenominator = beats + (measures - 1) * _measureGapRatio + 2 * _cardPaddingRatio;
  final widthStrokeSize =
      (availableWidth - safetyMargin - beats * _strokeMargin) / widthDenominator;

  if (!availableHeight.isFinite) return widthStrokeSize;

  final rows = wrap.rows;
  final heightDenominator =
      (vertical.hasHeader ? headerRatio : 0.0) +
      _cardPaddingRatio * 0.6 +
      rows * (vertical.hasLabelRow ? _labelRowHeightRatio : 0.0) +
      rows * vertical.maxStrokes +
      (rows - 1) * _measureGapRatio +
      2 * _cardPaddingRatio;
  final heightConstant = rows * vertical.maxStrokes * _strokeMargin;
  final heightStrokeSize = (availableHeight - safetyMargin - heightConstant) / heightDenominator;

  return math.min(widthStrokeSize, heightStrokeSize);
}
