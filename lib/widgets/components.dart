import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../model/model.dart';
import '../util/colors.dart';
import 'arcade.dart';

/// An empty rounded "socket" shown in place of a whole empty beat slot in a measure. Drawn in a
/// translucent gray-blue so it reads on both the navy playfield and a light background.
class EmptyBeatPlaceholder extends StatelessWidget {
  final double strokeSize;

  const EmptyBeatPlaceholder({super.key, this.strokeSize = 28});

  @override
  Widget build(BuildContext context) {
    final size = strokeSize * 0.56;
    return SizedBox(
      width: strokeSize + 8,
      height: strokeSize + 8,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.3),
            border: Border.all(color: const Color(0x597F8BA8), width: 2),
          ),
        ),
      ),
    );
  }
}

/// A card whose background flips to a highlighted (yellow) style when active, used for the
/// currently-playing section and the countdown/status cards.
class HighlightedCard extends StatelessWidget {
  final Widget child;
  final bool isHighlighted;
  final double? minHeight;

  const HighlightedCard({
    super.key,
    required this.child,
    required this.isHighlighted,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
      padding: const EdgeInsets.all(12),
      // Only needed to center content within a minHeight. Without one, leave it off: a Container
      // with an alignment expands to fill any bounded height it's given (e.g. a SectionView
      // capped at the viewport's height), instead of shrink-wrapping its content.
      alignment: minHeight != null ? Alignment.center : null,
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.highlightBg : AppColors.normalBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.normalBorder, width: 2),
      ),
      child: child,
    );
  }
}

/// Centers its children in a vertical column that's only as wide as its content, matching the
/// web app's centered practice-view layout.
class CenteredContainer extends StatelessWidget {
  final List<Widget> children;
  final double? maxWidth;

  const CenteredContainer({super.key, required this.children, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
          ],
        ),
      ),
    );
  }
}

/// A labeled numeric stepper input (BPM, BPM increase, repeat count, etc). The displayed text is
/// only rewritten/clamped once the field loses focus (or on submit) -- not on every keystroke --
/// so typing a new value doesn't get fought over while it's still passing through invalid/
/// out-of-range intermediate states (e.g. clearing "60" to type "45" reads as empty, then "4",
/// then "45"). The parent's value is still kept live as each keystroke parses to a valid number,
/// though, so a button pressed without first blurring the field (e.g. tapping "Save" right after
/// typing) still sees the just-typed value rather than a stale one.
class NumberInputField extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final double width;
  // Set to false when the caller renders the label itself (e.g. in its own aligned column of a
  // form layout) rather than inline next to the input box.
  final bool showLabel;

  const NumberInputField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.width = 60,
    this.showLabel = true,
  });

  @override
  State<NumberInputField> createState() => _NumberInputFieldState();
}

class _NumberInputFieldState extends State<NumberInputField> {
  late final _controller = TextEditingController(text: '${widget.value}');
  late final _focusNode = FocusNode()..addListener(_handleFocusChange);

  @override
  void didUpdateWidget(NumberInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only resync from the outside while the field isn't focused -- otherwise this would stomp
    // over whatever the user is currently in the middle of typing.
    if (!_focusNode.hasFocus && widget.value != oldWidget.value) {
      _controller.text = '${widget.value}';
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) _commit();
  }

  // Keeps the parent's value live as each keystroke parses to a valid number, without touching
  // the displayed text -- so a button tapped right after typing (with no intervening blur, e.g.
  // "Save" pressed straight away) still sees the just-typed value rather than a stale one.
  void _handleTextChanged(String text) {
    final n = int.tryParse(text)?.clamp(widget.min, widget.max);
    if (n != null && n != widget.value) widget.onChanged(n);
  }

  void _commit() {
    final n = int.tryParse(_controller.text)?.clamp(widget.min, widget.max) ?? widget.value;
    _controller.text = '$n';
    if (n != widget.value) widget.onChanged(n);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel)
          Text(
            '${widget.label}: ',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        SizedBox(
          width: widget.width,
          height: 40,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            keyboardType: TextInputType.number,
            onChanged: _handleTextChanged,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onSubmitted: (_) => _commit(),
          ),
        ),
      ],
    );
  }
}

// The bpm/bpm-increase/repeat-count fields a drill is configured with, shared by the drill
// overview screen and the daily-practice entry screen (each lays them out differently, but the
// labels/ranges/widths -- easy to let drift out of sync if hand-copied -- stay defined once).
// The ranges each can be set within.
const bpmLimits = (min: 30, max: maxBpm);
const bpmIncreaseLimits = (min: 0, max: 50);
const drillRepeatLimits = (min: 1, max: 10);

const bpmFieldLabel = 'BPM';
const bpmIncreaseFieldLabel = 'Increase';
const drillRepeatFieldLabel = 'Repeat';

NumberInputField bpmField({
  required int value,
  required ValueChanged<int> onChanged,
  bool showLabel = true,
}) => NumberInputField(
  label: bpmFieldLabel,
  showLabel: showLabel,
  value: value,
  onChanged: onChanged,
  min: bpmLimits.min,
  max: bpmLimits.max,
  width: 60,
);

NumberInputField bpmIncreaseField({
  required int value,
  required ValueChanged<int> onChanged,
  bool showLabel = true,
}) => NumberInputField(
  label: bpmIncreaseFieldLabel,
  showLabel: showLabel,
  value: value,
  onChanged: onChanged,
  min: bpmIncreaseLimits.min,
  max: bpmIncreaseLimits.max,
  width: 50,
);

NumberInputField drillRepeatField({
  required int value,
  required ValueChanged<int> onChanged,
  bool showLabel = true,
}) => NumberInputField(
  label: drillRepeatFieldLabel,
  showLabel: showLabel,
  value: value,
  onChanged: onChanged,
  min: drillRepeatLimits.min,
  max: drillRepeatLimits.max,
  width: 50,
);

/// A [TableRow] pairing a left-aligned label with a field, for a form where every label lines up
/// in its own column regardless of how long the other labels in the table are.
TableRow fieldRow(String label, Widget field) {
  return TableRow(
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 12, bottom: 12),
        child: Text('$label:', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ),
      Padding(padding: const EdgeInsets.only(bottom: 12), child: field),
    ],
  );
}

/// A row of fixed-size circles indicating repeat progress: [filled] of [total] are solid, the
/// rest are just outlined. Both states use the exact same box size (diameter + border width) so
/// a dot filling in never changes the row's height/width — unlike using "●"/"○" text glyphs,
/// whose font metrics differ enough to shift the surrounding layout by a few pixels each time.
/// If [currentColor] is given, the last filled dot (the repeat in progress) is drawn in it.
class RepeatDots extends StatelessWidget {
  final int total;
  final int filled;
  final double size;
  final Color color;
  final Color? currentColor;

  const RepeatDots({
    super.key,
    required this.total,
    required this.filled,
    this.size = 10,
    this.color = AppColors.textGray,
    this.currentColor,
  });

  @override
  Widget build(BuildContext context) {
    final borderWidth = (size * 0.2).clamp(1.2, 3.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : size * 0.45),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled
                    ? (i == filled - 1 ? currentColor ?? color : color)
                    : Colors.transparent,
                border: Border.all(
                  color: i == filled - 1 ? currentColor ?? color : color,
                  width: borderWidth,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Section label on the left, repeat indicator on the right — either a plain string (e.g. "x4",
/// used in the static drill overview) or a [RepeatDots] progress indicator (used while playing).
class SectionHeader extends StatelessWidget {
  final String? label;
  final String? repeatDisplay;
  final int? repeatDotsTotal;
  final int? repeatDotsFilled;
  final double labelFontSize;
  final double repeatFontSize;

  const SectionHeader({
    super.key,
    this.label,
    this.repeatDisplay,
    this.repeatDotsTotal,
    this.repeatDotsFilled,
    this.labelFontSize = 14,
    this.repeatFontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final hasRepeatDots = repeatDotsTotal != null && repeatDotsTotal! > 0;
    final hasRepeatText = repeatDisplay != null && repeatDisplay!.isNotEmpty;
    if ((label == null || label!.isEmpty) && !hasRepeatDots && !hasRepeatText) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (label != null && label!.isNotEmpty)
          Text(
            label!,
            style: TextStyle(fontSize: labelFontSize, fontWeight: FontWeight.bold),
          ),
        if (hasRepeatDots)
          RepeatDots(
            total: repeatDotsTotal!,
            filled: repeatDotsFilled ?? 0,
            size: repeatFontSize * 0.9,
          )
        else if (hasRepeatText)
          Text(
            repeatDisplay!,
            style: TextStyle(
              fontSize: repeatFontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.textGray,
            ),
          ),
      ],
    );
  }
}

// The count-in: one call per measure, as romaji (shown big) and Japanese (on the beat pips).
const List<(String, String)> introText = [('ICHI', 'いち'), ('NI', 'に'), ('SO', 'そ〜'), ('RE', 'れ！')];

/// The count-in display: the current call ([index] into [introText]) in big puffy text, over a
/// row of pips for all four calls. A negative [index] means the count-in hasn't started yet: all
/// the pips are unlit and the big text is hidden (though it still takes up its space, so nothing
/// jumps when the first call appears). [size] is the puffy text's font size.
class CountIn extends StatelessWidget {
  final int index;
  final double size;

  const CountIn({super.key, required this.index, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final current = index < 0 ? -1 : math.min(index, introText.length - 1);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: current < 0 ? 0 : 1,
          child: PuffyText('${introText[math.max(current, 0)].$1}!', size: size),
        ),
        SizedBox(height: size * 0.2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < introText.length; i++)
              Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                child: _CountPip(label: introText[i].$2, past: i < current, current: i == current),
              ),
          ],
        ),
      ],
    );
  }
}

/// A count-in card: the [CountIn] while [intro] is counting in, otherwise just "Get ready...".
class CountdownSection extends StatelessWidget {
  final int beat;
  final int beatsPerMeasure;
  final bool intro;

  const CountdownSection({
    super.key,
    required this.beat,
    required this.beatsPerMeasure,
    required this.intro,
  });

  @override
  Widget build(BuildContext context) {
    return PlayfieldPanel(
      active: intro,
      minHeight: 100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      // Always fits on one line/card: on a narrow phone everything shrinks to fit the card's
      // width rather than wrapping, while content that already fits stays full size.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: intro
            ? CountIn(index: beat ~/ beatsPerMeasure)
            : const Text(
                'Get ready...',
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 40,
                  color: AppColors.cream,
                ),
              ),
      ),
    );
  }
}

class _CountPip extends StatelessWidget {
  final String label;
  final bool past;
  final bool current;

  const _CountPip({required this.label, required this.past, required this.current});

  @override
  Widget build(BuildContext context) {
    final candy = current ? AppColors.candyPink : AppColors.candyOrange;
    final size = current ? 64.0 : 54.0;
    final filled = past || current;
    return Opacity(
      opacity: past ? 0.75 : 1,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: filled
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [candy.hi, candy.base, candy.lo],
                  stops: const [0, 0.5, 1],
                )
              : null,
          border: filled
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2.5),
          // Painted in order: the current pip's glow, then a white ring around both the pip and its
          // solid 3D lip below it (hence shifted down by half the lip), then the lip itself.
          boxShadow: [
            if (current) ...[
              BoxShadow(color: candy.base.withValues(alpha: 0.55), blurRadius: 26, spreadRadius: 8),
              const BoxShadow(color: Colors.white, spreadRadius: 4, offset: Offset(0, 1.5)),
            ],
            if (filled) BoxShadow(color: candy.outline, offset: const Offset(0, 3)),
          ],
        ),
        child: filled
            ? OutlinedText(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: current ? 20 : 16,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
                color: Colors.white,
                outline: candy.outline,
                outlineWidth: 2,
              )
            : Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 16,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
      ),
    );
  }
}
