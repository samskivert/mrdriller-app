import 'package:flutter_test/flutter_test.dart';
import 'package:mrdriller/model/model.dart';
import 'package:mrdriller/util/size_config.dart';

// A single-line, unlabeled, single-stroke-per-beat section: has no bearing on the width equation
// (that's driven by widestLine), and its vertical shape is as small as possible, so it never binds
// the height equation in tests that are only exercising the width side.
Section _plainSection(int beats, int measures) => oneLineSection('', 1, [
  for (var m = 0; m < measures; m++)
    measure([for (var b = 0; b < beats; b++) r]),
]);

void main() {
  test(
    'computeFittedSizeConfig solves for a strokeSize that exactly fits availableWidth',
    () {
      const widestLine = (beats: 4, measures: 2);
      const availableWidth = 302.0;

      final config = computeFittedSizeConfig(
        widestLine: widestLine,
        availableWidth: availableWidth,
        section: _plainSection(widestLine.beats, widestLine.measures),
      );

      // Re-derive the width the resulting config would actually consume, and confirm it fits
      // within (not exceeds) availableWidth -- the whole point of solving this analytically instead
      // of picking from presets. Crucially this includes the card's own left+right padding: that's
      // real space subtracted from availableWidth by the actual widget tree (LayoutBuilder measures
      // width *before* cardPadding is applied), so a check that only re-derives the beat row's own
      // width would pass even with cardPadding missing from the solved equation entirely.
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
      const widestLine = (beats: 4, measures: 1);
      const availableWidth = 850.0;

      final config = computeFittedSizeConfig(
        widestLine: widestLine,
        availableWidth: availableWidth,
        section: _plainSection(widestLine.beats, widestLine.measures),
      );

      const strokeMargin = 8.0;
      final beatsRowWidth =
          widestLine.beats * (config.strokeSize + strokeMargin);
      final totalCardWidth = beatsRowWidth + 2 * config.cardPadding;

      expect(totalCardWidth, lessThanOrEqualTo(availableWidth + 0.01));
    },
  );

  test(
    'clamps to the minimum legible stroke size when the width is impossibly small',
    () {
      const widestLine = (beats: 16, measures: 4);
      final config = computeFittedSizeConfig(
        widestLine: widestLine,
        availableWidth: 50,
        section: _plainSection(widestLine.beats, widestLine.measures),
      );
      expect(config.strokeSize, minStrokeSize);
    },
  );

  test(
    'clamps to the maximum stroke size when there is far more room than needed',
    () {
      const widestLine = (beats: 1, measures: 1);
      final config = computeFittedSizeConfig(
        widestLine: widestLine,
        availableWidth: 5000,
        section: _plainSection(widestLine.beats, widestLine.measures),
      );
      expect(config.strokeSize, maxStrokeSize);
    },
  );

  test('widestLineShape finds the widest line across sections by beat count', () {
    // Uses the public model DSL indirectly via drillWidestLineShape callers in the app; here we
    // just check the zero-sections edge case falls back sanely.
    final shape = widestLineShape(const []);
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
    const widestLine = (beats: 2, measures: 1);
    // Plenty of width, but a section with 4 lines and a header, squeezed into a short height --
    // a landscape phone scenario, where width alone would pick a strokeSize far too tall to fit.
    final section = oneLineSection('Section', 3, [
      measure([r, r]),
    ]);
    final tallSection = Section(
      label: section.label,
      repeat: section.repeat,
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
      widestLine: widestLine,
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
    'clamps to the minimum legible stroke size when the height is impossibly small',
    () {
      const widestLine = (beats: 2, measures: 1);
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
        widestLine: widestLine,
        availableWidth: 2000,
        availableHeight: 50,
        section: tallSection,
      );

      expect(config.strokeSize, minStrokeSize);
    },
  );

  test(
    'an infinite availableHeight (e.g. inside a scroll view) never constrains sizing',
    () {
      const widestLine = (beats: 1, measures: 1);
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
        widestLine: widestLine,
        availableWidth: 5000,
        section: tallSection,
      );

      expect(config.strokeSize, maxStrokeSize);
    },
  );
}
