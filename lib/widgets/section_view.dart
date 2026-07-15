import 'package:flutter/material.dart';

import '../model/model.dart';
import '../util/size_config.dart';
import 'components.dart';
import 'measure_view.dart';

/// Renders a whole section: a bordered/highlighted card with a label + repeat indicator, and one
/// or more lines of measures wrapped and centered.
class SectionView extends StatelessWidget {
  final Section section;
  final bool isHighlighted;
  final String? repeatDisplay;
  final Pos? highlight;
  final SizeLevel sizeLevel;

  const SectionView({
    super.key,
    required this.section,
    required this.isHighlighted,
    this.repeatDisplay,
    this.highlight,
    this.sizeLevel = 5,
  });

  @override
  Widget build(BuildContext context) {
    final config = sizeConfigs[sizeLevel]!;
    return HighlightedCard(
      isHighlighted: isHighlighted,
      child: Padding(
        padding: EdgeInsets.all(config.cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              label: section.label,
              repeatDisplay: repeatDisplay,
              labelFontSize: config.labelFontSize,
              repeatFontSize: config.repeatFontSize,
            ),
            SizedBox(height: config.cardPadding * 0.6),
            for (var ll = 0; ll < section.lines.length; ll++)
              Padding(
                padding: EdgeInsets.only(top: ll == 0 ? 0 : config.measureGap),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: config.measureGap,
                  runSpacing: config.measureGap,
                  children: [
                    for (var mm = 0; mm < section.lines[ll].measures.length; mm++)
                      MeasureView(
                        measure: section.lines[ll].measures[mm],
                        strokeSize: config.strokeSize,
                        highlightBeat: (isHighlighted && highlight != null && highlight!.line == ll && highlight!.measure == mm)
                            ? highlight!.offset
                            : null,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
