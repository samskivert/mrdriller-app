import 'package:flutter/material.dart';

import '../model/model.dart';
import '../util/colors.dart';
import '../util/size_config.dart';
import 'arcade.dart';
import 'components.dart';
import 'measure_view.dart';

/// Renders a whole section as a navy playfield panel: the section's label on a [bannerColor] tab
/// in the top-left corner, repeat progress dots in the top-right, and one or more lines of measures
/// wrapped and centered below. A [isDone] section is dimmed and stamped "CLEAR!".
///
/// Sizing is computed on the fly from the real width/height Flutter measures via [LayoutBuilder]
/// — already net of every ancestor's padding/borders — rather than estimated from the window size
/// with a guessed overhead and snapped to one of a handful of presets. It's fit to this section's
/// own content alone, so a section with more room to work with (or that simply needs less space)
/// can render larger or smaller than its neighbors -- see [computeFittedSizeConfig], whose height
/// equation this layout must match: header, 2.6 cardPaddings of vertical spacing, then the rows.
class SectionView extends StatelessWidget {
  final Section section;
  final bool isHighlighted;
  final bool isDone;
  final Color bannerColor;
  final int? repeatDotsFilled;
  final Pos? highlight;

  const SectionView({
    super.key,
    required this.section,
    required this.isHighlighted,
    this.isDone = false,
    this.bannerColor = AppColors.bannerOrange,
    this.repeatDotsFilled,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return PlayfieldPanel(
      active: isHighlighted,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final config = computeFittedSizeConfig(
            availableWidth: constraints.maxWidth,
            availableHeight: constraints.maxHeight,
            section: section,
          );
          final label = section.label;
          final hasLabel = label != null && label.isNotEmpty;
          final hasHeader = hasLabel || section.repeat > 1;
          final font = config.labelFontSize;
          final beats = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                          labelColor: AppColors.cream,
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
          );
          return Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasHeader)
                    SizedBox(
                      height: config.headerHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (hasLabel)
                            Flexible(
                              child: HudBanner(
                                label: label,
                                color: bannerColor,
                                fontSize: font,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(14),
                                  bottomRight: Radius.circular(config.headerHeight * 0.45),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: font * 0.95,
                                  vertical: (config.headerHeight - font) / 2,
                                ),
                              ),
                            ),
                          if (section.repeat > 1)
                            Padding(
                              padding: EdgeInsets.only(
                                left: config.cardPadding,
                                right: config.cardPadding,
                              ),
                              child: SizedBox(
                                height: config.headerHeight,
                                child: Center(
                                  child: RepeatDots(
                                    total: section.repeat,
                                    filled: isDone ? section.repeat : (repeatDotsFilled ?? 0),
                                    size: font * 0.8,
                                    color: AppColors.repeatDot,
                                    currentColor: isHighlighted ? AppColors.gold : null,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  SizedBox(height: config.cardPadding * 1.3),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: config.cardPadding),
                    child: isDone ? Opacity(opacity: 0.32, child: beats) : beats,
                  ),
                  SizedBox(height: config.cardPadding * 1.3),
                ],
              ),
              if (isDone)
                Positioned(
                  right: config.cardPadding * 1.5,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.14,
                      child: OutlinedText(
                        'CLEAR!',
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: (font * 1.6).clamp(16, 48),
                          height: 1,
                        ),
                        color: AppColors.gold,
                        outline: AppColors.goldOutline,
                        outlineWidth: 2,
                        shadow: AppColors.goldOutline,
                        shadowOffset: 3,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
