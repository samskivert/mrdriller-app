import 'package:flutter/material.dart';

import '../model/model.dart';
import '../util/size_config.dart';
import 'components.dart';
import 'measure_view.dart';

/// Renders a whole section: a bordered/highlighted card with a label + repeat indicator, and one
/// or more lines of measures wrapped and centered.
///
/// Sizing is computed on the fly from the real width/height Flutter measures via [LayoutBuilder]
/// — already net of every ancestor's padding/borders — rather than estimated from the window size
/// with a guessed overhead and snapped to one of a handful of presets. It's fit to this section's
/// own content alone, so a section with more room to work with (or that simply needs less space)
/// can render larger or smaller than its neighbors -- see [computeFittedSizeConfig].
class SectionView extends StatelessWidget {
  final Section section;
  final bool isHighlighted;
  final int? repeatDotsFilled;
  final Pos? highlight;

  const SectionView({
    super.key,
    required this.section,
    required this.isHighlighted,
    this.repeatDotsFilled,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return HighlightedCard(
      isHighlighted: isHighlighted,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final config = computeFittedSizeConfig(
            availableWidth: constraints.maxWidth,
            availableHeight: constraints.maxHeight,
            section: section,
          );
          return Padding(
            padding: EdgeInsets.all(config.cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  label: section.label,
                  repeatDotsTotal: section.repeat > 1 ? section.repeat : null,
                  repeatDotsFilled: repeatDotsFilled,
                  labelFontSize: config.labelFontSize,
                  repeatFontSize: config.repeatFontSize,
                ),
                SizedBox(height: config.cardPadding * 0.6),
                for (var ll = 0; ll < section.lines.length; ll++)
                  Padding(
                    padding: EdgeInsets.only(
                      top: ll == 0 ? 0 : config.measureGap,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: config.measureGap,
                      runSpacing: config.measureGap,
                      children: [
                        for (
                          var mm = 0;
                          mm < section.lines[ll].measures.length;
                          mm++
                        )
                          MeasureView(
                            measure: section.lines[ll].measures[mm],
                            strokeSize: config.strokeSize,
                            highlightBeat:
                                (isHighlighted &&
                                    highlight != null &&
                                    highlight!.line == ll &&
                                    highlight!.measure == mm)
                                ? highlight!.offset
                                : null,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
