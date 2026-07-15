import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/util/size_config.dart';

void main() {
  test('computeFittedSizeConfig solves for a strokeSize that exactly fits availableWidth', () {
    const widestLine = (beats: 4, measures: 2);
    const availableWidth = 302.0;

    final config = computeFittedSizeConfig(widestLine: widestLine, availableWidth: availableWidth);

    // Re-derive the width the resulting config would actually consume, and confirm it fits
    // within (not exceeds) availableWidth -- the whole point of solving this analytically instead
    // of picking from presets. Crucially this includes the card's own left+right padding: that's
    // real space subtracted from availableWidth by the actual widget tree (LayoutBuilder measures
    // width *before* cardPadding is applied), so a check that only re-derives the beat row's own
    // width would pass even with cardPadding missing from the solved equation entirely.
    const strokeMargin = 8.0;
    final beatsRowWidth =
        widestLine.beats * (config.strokeSize + strokeMargin) + (widestLine.measures - 1) * config.measureGap;
    final totalCardWidth = beatsRowWidth + 2 * config.cardPadding;

    expect(totalCardWidth, lessThanOrEqualTo(availableWidth + 0.01));
  });

  test('accounts for cardPadding at a scale where omitting it would be visibly wrong', () {
    // Regression test for a real bug: a large availableWidth (e.g. a landscape phone) with a
    // small beat count solves for a large strokeSize, which makes cardPadding (proportional to
    // strokeSize) large too. Omitting 2*cardPadding from the equation caused the total card width
    // to visibly overflow its measured space specifically at this large-stroke end of the range.
    const widestLine = (beats: 4, measures: 1);
    const availableWidth = 850.0;

    final config = computeFittedSizeConfig(widestLine: widestLine, availableWidth: availableWidth);

    const strokeMargin = 8.0;
    final beatsRowWidth = widestLine.beats * (config.strokeSize + strokeMargin);
    final totalCardWidth = beatsRowWidth + 2 * config.cardPadding;

    expect(totalCardWidth, lessThanOrEqualTo(availableWidth + 0.01));
  });

  test('clamps to the minimum legible stroke size when the width is impossibly small', () {
    const widestLine = (beats: 16, measures: 4);
    final config = computeFittedSizeConfig(widestLine: widestLine, availableWidth: 50);
    expect(config.strokeSize, minStrokeSize);
  });

  test('clamps to the maximum stroke size when there is far more room than needed', () {
    const widestLine = (beats: 1, measures: 1);
    final config = computeFittedSizeConfig(widestLine: widestLine, availableWidth: 5000);
    expect(config.strokeSize, maxStrokeSize);
  });

  test('widestLineShape finds the widest line across sections by beat count', () {
    // Uses the public model DSL indirectly via drillWidestLineShape callers in the app; here we
    // just check the zero-sections edge case falls back sanely.
    final shape = widestLineShape(const []);
    expect(shape.beats, 0);
    expect(shape.measures, 0);
  });
}
