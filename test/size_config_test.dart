import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/model/model.dart';
import 'package:mrdriller/util/size_config.dart';

// A single-line, unlabeled, single-stroke-per-beat section with the given beats/measures shape.
// Its vertical shape is as small as possible, so it never binds the height equation in tests that
// are only exercising the width side.
Section _plainSection(int beats, int measures) => oneLineSection('', 1, [
  for (var m = 0; m < measures; m++)
    measure([for (var b = 0; b < beats; b++) r]),
]);

void main() {
  test(
    'computeFittedSizeConfig solves for a strokeSize that exactly fits availableWidth',
    () {
      final section = _plainSection(4, 2);
      const availableWidth = 302.0;

      final config = computeFittedSizeConfig(
        availableWidth: availableWidth,
        section: section,
      );

      // Re-derive the width the resulting config would actually consume, and confirm it fits
      // within (not exceeds) availableWidth -- the whole point of solving this analytically instead
      // of picking from presets. Crucially this includes the card's own left+right padding: that's
      // real space subtracted from availableWidth by the actual widget tree (LayoutBuilder measures
      // width *before* cardPadding is applied), so a check that only re-derives the beat row's own
      // width would pass even with cardPadding missing from the solved equation entirely.
      final widestLine = widestLineShape(section);
      const strokeMargin = 8.0;
      final beatsRowWidth =
          widestLine.beats * (config.strokeSize + strokeMargin) +
          (widestLine.measures - 1) * config.measureGap;
      final totalCardWidth = beatsRowWidth + 2 * config.cardPadding;

      expect(totalCardWidth, lessThanOrEqualTo(availableWidth + 0.01));
    },
  );

  test(
    'accounts for cardPadding at a scale where omitting it would be visibly wrong',
    () {
      // Regression test for a real bug: a large availableWidth (e.g. a landscape phone) with a
      // small beat count solves for a large strokeSize, which makes cardPadding (proportional to
      // strokeSize) large too. Omitting 2*cardPadding from the equation caused the total card width
      // to visibly overflow its measured space specifically at this large-stroke end of the range.
      final section = _plainSection(4, 1);
      const availableWidth = 850.0;

      final config = computeFittedSizeConfig(
        availableWidth: availableWidth,
        section: section,
      );

      final widestLine = widestLineShape(section);
      const strokeMargin = 8.0;
      final beatsRowWidth =
          widestLine.beats * (config.strokeSize + strokeMargin);
      final totalCardWidth = beatsRowWidth + 2 * config.cardPadding;

      expect(totalCardWidth, lessThanOrEqualTo(availableWidth + 0.01));
    },
  );

  test('falls back to a comfortable size instead of an unreadably tiny one when the width is '
      'impossibly small', () {
    // Wrapping is unavoidable here even at minStrokeSize (the row still wouldn't fit), so
    // rather than clamp up to the smallest legible size and have it wrap anyway, this should
    // fall back to a comfortable, legible size and just accept the wrap -- matching what the
    // static drill-overview does unconditionally.
    final config = computeFittedSizeConfig(
      availableWidth: 50,
      section: _plainSection(16, 4),
    );
    expect(config.strokeSize, wrapFallbackStrokeSize);
  });

  test(
    'clamps to the maximum stroke size when there is far more room than needed',
    () {
      final config = computeFittedSizeConfig(
        availableWidth: 5000,
        section: _plainSection(1, 1),
      );
      expect(config.strokeSize, maxStrokeSize);
    },
  );

  test(
    'widestLineShape finds the widest line within a section by beat count',
    () {
      final section = Section(
        repeat: 1,
        lines: [
          Line(
            measures: [
              measure([r, r]),
            ],
          ),
          Line(
            measures: [
              measure([r, r, r, r]),
              measure([r, r]),
            ],
          ),
          Line(
            measures: [
              measure([r, r, r]),
            ],
          ),
        ],
      );

      final shape = widestLineShape(section);

      // The second line has the most total beats (4 + 2 = 6), even though neither individual
      // measure in it is the widest on its own.
      expect(shape.beats, 6);
      expect(shape.measures, 2);
    },
  );

  test('widestLineShape falls back sanely for a section with no lines', () {
    final shape = widestLineShape(const Section(repeat: 1, lines: []));
    expect(shape.beats, 0);
    expect(shape.measures, 0);
  });

  test(
    'sectionVerticalShape scans line count, label presence, and max simultaneous strokes',
    () {
      final section = Section(
        label: 'Both hands',
        repeat: 2,
        lines: [
          Line(
            measures: [
              measure([r, r, r, r]),
            ],
          ),
          Line(
            measures: [
              [
                beat([r, l]),
                labeledBeat('R', [r, l]),
                beat([r, l]),
                beat([r, l]),
              ],
            ],
          ),
        ],
      );

      final shape = sectionVerticalShape(section);

      expect(shape.lines, 2);
      expect(shape.hasHeader, isTrue);
      expect(shape.hasLabelRow, isTrue);
      expect(shape.maxStrokes, 2);
    },
  );

  test(
    'sectionVerticalShape reports no header when there is no label and no repeat',
    () {
      final shape = sectionVerticalShape(_plainSection(4, 1));
      expect(shape.hasHeader, isFalse);
      expect(shape.hasLabelRow, isFalse);
      expect(shape.maxStrokes, 1);
    },
  );

  test('computeFittedSizeConfig solves for a strokeSize that fits availableHeight when it is the '
      'binding constraint', () {
    // Plenty of width, but a section with 4 lines and a header, squeezed into a short height --
    // a landscape phone scenario, where width alone would pick a strokeSize far too tall to fit.
    final tallSection = Section(
      label: 'Section',
      repeat: 3,
      lines: [
        for (var i = 0; i < 4; i++)
          Line(
            measures: [
              measure([r, r]),
            ],
          ),
      ],
    );
    const availableHeight = 220.0;

    final config = computeFittedSizeConfig(
      availableWidth: 2000,
      availableHeight: availableHeight,
      section: tallSection,
    );

    final shape = sectionVerticalShape(tallSection);
    const strokeMargin = 8.0;
    const headerLineHeightRatio = 1.3;
    const fontRatio = 0.22;
    final headerHeight = config.strokeSize * fontRatio * headerLineHeightRatio;
    final gapAfterHeader = config.cardPadding * 0.6;
    final perLineHeight = shape.maxStrokes * (config.strokeSize + strokeMargin);
    final totalLinesHeight =
        shape.lines * perLineHeight + (shape.lines - 1) * config.measureGap;
    final totalCardHeight =
        headerHeight +
        gapAfterHeader +
        totalLinesHeight +
        2 * config.cardPadding;

    expect(totalCardHeight, lessThanOrEqualTo(availableHeight + 0.01));
    // Confirm height, not width, was actually the binding constraint in this scenario.
    expect(config.strokeSize, lessThan(maxStrokeSize));
  });

  test(
    'falls back to a comfortable size instead of an unreadably tiny one when the height is '
    'impossibly small',
    () {
      final tallSection = Section(
        repeat: 1,
        lines: [
          for (var i = 0; i < 8; i++)
            Line(
              measures: [
                measure([r, r]),
              ],
            ),
        ],
      );

      final config = computeFittedSizeConfig(
        availableWidth: 2000,
        availableHeight: 50,
        section: tallSection,
      );

      expect(config.strokeSize, wrapFallbackStrokeSize);
    },
  );

  test('falls back to a comfortable size for a pathologically dense line (regression: Sixteens '
      'drill, 64 beats in one line)', () {
    // Mirrors the real "Sixteens" drill: a single line with 64 beats across 8 measures. Even
    // at a generous available width, the row can't fit at minStrokeSize -- it needs a
    // comfortable size and to just accept wrapping, like the static overview does, rather than
    // shrinking to the floor and *still* wrapping.
    final section = _plainSection(64, 8);
    final config = computeFittedSizeConfig(
      availableWidth: 1200,
      section: section,
    );

    expect(config.strokeSize, wrapFallbackStrokeSize);

    final widestLine = widestLineShape(section);
    const strokeMargin = 8.0;
    final beatsRowWidth =
        widestLine.beats * (config.strokeSize + strokeMargin) +
        (widestLine.measures - 1) * config.measureGap;
    final totalCardWidth = beatsRowWidth + 2 * config.cardPadding;
    // Confirms this really is the "wraps anyway" scenario the fallback is for, not something
    // that now accidentally fits.
    expect(totalCardWidth, greaterThan(1200));
  });

  test(
    'a section that needs less room than its neighbors can render at its own, larger size',
    () {
      // The whole point of sizing per-section instead of drill-wide: a short, simple section
      // (few beats) shouldn't be squeezed down just because some other section in the same drill
      // is much denser. Same generous availableWidth as the "far more room than needed" case,
      // but this asserts the point of comparison directly -- a sparse section's own fit isn't
      // held back by a dense one.
      final sparse = computeFittedSizeConfig(
        availableWidth: 400,
        section: _plainSection(2, 1),
      );
      final dense = computeFittedSizeConfig(
        availableWidth: 400,
        section: _plainSection(32, 4),
      );

      expect(sparse.strokeSize, greaterThan(dense.strokeSize));
    },
  );

  test(
    'an infinite availableHeight (e.g. inside a scroll view) never constrains sizing',
    () {
      final tallSection = Section(
        repeat: 1,
        lines: [
          for (var i = 0; i < 20; i++)
            Line(
              measures: [
                measure([r]),
              ],
            ),
        ],
      );

      final config = computeFittedSizeConfig(
        availableWidth: 5000,
        section: tallSection,
      );

      expect(config.strokeSize, maxStrokeSize);
    },
  );
}
