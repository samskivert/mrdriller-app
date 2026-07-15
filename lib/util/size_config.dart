import '../model/model.dart';

typedef SizeLevel = int; // 1..9

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

// Size 9: strokeSize=172, size 1: strokeSize=22
const Map<SizeLevel, SizeConfig> sizeConfigs = {
  1: SizeConfig(strokeSize: 22, measureGap: 3, cardPadding: 6, labelFontSize: 14, repeatFontSize: 14),
  2: SizeConfig(strokeSize: 28, measureGap: 4, cardPadding: 8, labelFontSize: 14, repeatFontSize: 14),
  3: SizeConfig(strokeSize: 48, measureGap: 5, cardPadding: 10, labelFontSize: 16, repeatFontSize: 16),
  4: SizeConfig(strokeSize: 68, measureGap: 6, cardPadding: 12, labelFontSize: 18, repeatFontSize: 18),
  5: SizeConfig(strokeSize: 90, measureGap: 8, cardPadding: 14, labelFontSize: 20, repeatFontSize: 20),
  6: SizeConfig(strokeSize: 110, measureGap: 10, cardPadding: 16, labelFontSize: 24, repeatFontSize: 24),
  7: SizeConfig(strokeSize: 130, measureGap: 12, cardPadding: 18, labelFontSize: 28, repeatFontSize: 28),
  8: SizeConfig(strokeSize: 150, measureGap: 13, cardPadding: 20, labelFontSize: 28, repeatFontSize: 35),
  9: SizeConfig(strokeSize: 172, measureGap: 14, cardPadding: 22, labelFontSize: 35, repeatFontSize: 35),
};

const double _strokeMargin = 8; // 4px margin on each side in StrokeView
const double _outerMargin = 48; // container padding, card borders, etc.

/// Compute the best size level for a single section to fit within the given window width.
SizeLevel _computeSectionLevel(Section section, double windowWidth, SizeLevel minLevel) {
  int widestBeats = 0; // number of beats in the widest line
  int widestMeasures = 0; // number of measures in the widest line
  for (final line in section.lines) {
    final lineBeats = line.measures.fold<int>(0, (sum, m) => sum + m.length);
    if (lineBeats > widestBeats) {
      widestBeats = lineBeats;
      widestMeasures = line.measures.length;
    }
  }

  for (int level = 9; level >= minLevel; level--) {
    final config = sizeConfigs[level]!;
    final beatWidth = config.strokeSize + _strokeMargin;
    final contentWidth = widestBeats * beatWidth + (widestMeasures - 1) * config.measureGap;
    final totalWidth = contentWidth + config.cardPadding * 2 + _outerMargin;
    if (totalWidth <= windowWidth) return level;
  }
  return minLevel;
}

/// Compute a uniform size level for an entire drill, using the smallest level needed by any
/// section.
SizeLevel computeDrillSizeLevel(Drill drill, double windowWidth) {
  final minLevel = ((windowWidth / 512).round() + 1).clamp(1, 9);
  SizeLevel level = 9;
  for (final row in drill.rows) {
    for (final section in row) {
      final sectionLevel = _computeSectionLevel(section, windowWidth, minLevel);
      if (sectionLevel < level) level = sectionLevel;
    }
  }
  return level;
}
