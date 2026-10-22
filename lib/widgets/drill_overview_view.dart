import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../model/model.dart';
import '../util/colors.dart';
import '../util/size_config.dart';
import 'arcade.dart';
import 'measure_view.dart';

// Compact, so that more of the drill fits on screen at once; it's for looking over, not playing.
const double _strokeSize = 30;

/// The stroke size for [section] in [width]: the compact size, unless its widest measure (which
/// can't wrap, unlike a line's measures) needs smaller strokes to fit, down to [minStrokeSize].
double _strokeSizeFor(Section section, double width) {
  final beats = section.lines
      .expand((line) => line.measures)
      .fold(0, (most, measure) => math.max(most, measure.length));
  if (beats == 0 || !width.isFinite) return _strokeSize;
  // Less the panel's 2px border and the body's 10px padding on each side, and 4px of margin on each
  // side of every beat (see MeasureView), with a pixel to spare for rounding.
  final fit = (width - 2 * 2 - 2 * 10 - 1) / beats - 8;
  return fit.clamp(minStrokeSize, _strokeSize).floorToDouble();
}

class _OverviewSectionView extends StatelessWidget {
  final Section section;
  final Color bannerColor;
  final double strokeSize;

  const _OverviewSectionView({
    required this.section,
    required this.bannerColor,
    required this.strokeSize,
  });

  @override
  Widget build(BuildContext context) {
    final label = section.label;
    return PlayfieldPanel(
      expand: false,
      child: _HeaderOverBody(
        header: Row(
          // Not a Spacer between the two: that would only get half the free space, sharing it with
          // the banner's Flexible, which leaves whatever the banner doesn't use after the repeat
          // count instead of before it.
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (label != null && label.isNotEmpty)
              Flexible(
                child: HudBanner(
                  label: label,
                  color: bannerColor,
                  fontSize: 13,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomRight: Radius.circular(12),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
                ),
              )
            else
              // (Keeps the repeat count over on the right.)
              const SizedBox.shrink(),
            if (section.repeat > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Text(
                  '×${section.repeat}',
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold,
                  ),
                ),
              ),
          ],
        ),
        // Each Wrap gets loose width constraints from this centered Column, so it sizes itself to
        // its widest row (after wrapping, if it had to wrap) rather than to all the width on
        // offer -- and so the card shrinks to its content either way, not just when a line fits
        // unwrapped.
        body: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final line in section.lines)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final measure in line.measures)
                        MeasureView(
                          measure: measure,
                          strokeSize: strokeSize,
                          labelColor: AppColors.cream,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _HeaderOverBodySlot { header, body }

/// Lays out [body] at whatever width it naturally takes (up to the width available), then
/// stretches [header] across exactly that width above it -- e.g. a section's label and repeat count
/// pinned to the left and right edges of its measures, however those measures ended up wrapping.
/// (IntrinsicWidth can't do this: a Wrap's intrinsic width is its *unwrapped* width, so whenever it
/// wraps, the card would be sized wider than the wrapped rows actually are.) Grows wider than
/// [body] if that's what [header] needs to fit on one line, centering [body] beneath it.
class _HeaderOverBody extends SlottedMultiChildRenderObjectWidget<_HeaderOverBodySlot, RenderBox> {
  final Widget header;
  final Widget body;

  const _HeaderOverBody({required this.header, required this.body});

  @override
  Iterable<_HeaderOverBodySlot> get slots => _HeaderOverBodySlot.values;

  @override
  Widget? childForSlot(_HeaderOverBodySlot slot) => switch (slot) {
    _HeaderOverBodySlot.header => header,
    _HeaderOverBodySlot.body => body,
  };

  @override
  _RenderHeaderOverBody createRenderObject(BuildContext context) => _RenderHeaderOverBody();
}

class _RenderHeaderOverBody extends RenderBox
    with SlottedContainerRenderObjectMixin<_HeaderOverBodySlot, RenderBox> {
  RenderBox get _header => childForSlot(_HeaderOverBodySlot.header)!;
  RenderBox get _body => childForSlot(_HeaderOverBodySlot.body)!;

  // Sizes both children (laying them out for real if [layoutChild] does) and returns the overall
  // width, header height, and body size -- shared by the real and dry layout paths.
  ({double width, double headerHeight, Size body}) _layout(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layoutChild,
  ) {
    final body = layoutChild(_body, BoxConstraints(maxWidth: constraints.maxWidth));
    final headerWidth = _header.getMaxIntrinsicWidth(double.infinity);
    final width = constraints.constrainWidth(math.max(body.width, headerWidth));
    final header = layoutChild(_header, BoxConstraints.tightFor(width: width));
    return (width: width, headerHeight: header.height, body: body);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final l = _layout(constraints, (child, c) => child.getDryLayout(c));
    return constraints.constrain(Size(l.width, l.headerHeight + l.body.height));
  }

  @override
  void performLayout() {
    final l = _layout(constraints, (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    });
    (_header.parentData! as BoxParentData).offset = Offset.zero;
    (_body.parentData! as BoxParentData).offset = Offset(
      (l.width - l.body.width) / 2,
      l.headerHeight,
    );
    size = constraints.constrain(Size(l.width, l.headerHeight + l.body.height));
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(_header.getMinIntrinsicWidth(height), _body.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(_header.getMaxIntrinsicWidth(height), _body.getMaxIntrinsicWidth(height));

  @override
  double computeMinIntrinsicHeight(double width) =>
      _header.getMinIntrinsicHeight(width) + _body.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _header.getMaxIntrinsicHeight(width) + _body.getMaxIntrinsicHeight(width);

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(child, offset + (child.parentData! as BoxParentData).offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final offset = (child.parentData! as BoxParentData).offset;
      final hit = result.addWithPaintOffset(
        offset: offset,
        position: position,
        hitTest: (result, transformed) => child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}

class _RowView extends StatelessWidget {
  final DrillRow row;
  // The index of the row's first section within the whole drill, for picking banner colors.
  final int firstIndex;
  final double width;

  const _RowView({required this.row, required this.firstIndex, required this.width});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < row.length; i++)
          _OverviewSectionView(
            section: row[i],
            bannerColor: AppColors.banner(firstIndex + i),
            strokeSize: _strokeSizeFor(row[i], width),
          ),
      ],
    );
  }
}

/// A static (non-playing) preview of an entire drill's rows/sections/lines/measures, as playfield
/// panels, shown before practice starts.
class DrillOverviewView extends StatelessWidget {
  final Drill drill;

  const DrillOverviewView({super.key, required this.drill});

  @override
  Widget build(BuildContext context) {
    const maxWidth = 1200.0;
    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < drill.rows.length; r++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RowView(
                  row: drill.rows[r],
                  firstIndex: drill.rows.take(r).fold(0, (n, row) => n + row.length),
                  width: math.min(constraints.maxWidth, maxWidth),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
