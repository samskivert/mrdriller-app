import 'package:flutter/material.dart';

import '../util/colors.dart';

/// A small hollow circle shown in place of a whole empty beat slot in a measure.
class EmptyBeatPlaceholder extends StatelessWidget {
  final double strokeSize;

  const EmptyBeatPlaceholder({super.key, this.strokeSize = 28});

  @override
  Widget build(BuildContext context) {
    final size = strokeSize;
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Center(
        child: Container(
          width: size / 2,
          height: size / 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.10),
              width: 2,
            ),
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
      constraints: minHeight != null
          ? BoxConstraints(minHeight: minHeight!)
          : null,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
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
            for (final c in children)
              Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
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
    final n =
        int.tryParse(_controller.text)?.clamp(widget.min, widget.max) ??
        widget.value;
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onSubmitted: (_) => _commit(),
          ),
        ),
      ],
    );
  }
}

/// A row of fixed-size circles indicating repeat progress: [filled] of [total] are solid, the
/// rest are just outlined. Both states use the exact same box size (diameter + border width) so
/// a dot filling in never changes the row's height/width — unlike using "●"/"○" text glyphs,
/// whose font metrics differ enough to shift the surrounding layout by a few pixels each time.
class RepeatDots extends StatelessWidget {
  final int total;
  final int filled;
  final double size;
  final Color color;

  const RepeatDots({
    super.key,
    required this.total,
    required this.filled,
    this.size = 10,
    this.color = AppColors.textGray,
  });

  @override
  Widget build(BuildContext context) {
    final borderWidth = (size * 0.12).clamp(1.2, 3.0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : size * 0.3),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? color : Colors.transparent,
                border: Border.all(color: color, width: borderWidth),
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
            style: TextStyle(
              fontSize: labelFontSize,
              fontWeight: FontWeight.bold,
            ),
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

/// A responsive grid of [ActivityButton]s: two columns above 340px wide, one column below that.
class ActivityGrid extends StatelessWidget {
  final List<Widget> items;

  const ActivityGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final columns = constraints.maxWidth >= 340 ? 2 : 1;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items) SizedBox(width: itemWidth, child: item),
          ],
        );
      },
    );
  }
}

/// A big, tappable menu entry (a drill, a tool, an activity-list link).
class ActivityButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const ActivityButton({super.key, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: AppColors.btnBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      child: Text(title, textAlign: TextAlign.center),
    );
  }
}

const List<String> introText = ['Ichi - いち', 'Ni - に', 'So - そ〜', 'Re - れ！'];

/// The big countdown/status card shown before a drill starts and during the intro count-in.
class CountdownSection extends StatelessWidget {
  final int beat;
  final int beatsPerMeasure;
  final bool intro;
  final String? preText;

  const CountdownSection({
    super.key,
    required this.beat,
    required this.beatsPerMeasure,
    required this.intro,
    this.preText,
  });

  @override
  Widget build(BuildContext context) {
    final measureIndex = beat ~/ beatsPerMeasure;
    final text = !intro
        ? (preText ?? 'Get ready...')
        : (measureIndex >= introText.length
              ? introText.last
              : introText[measureIndex]);
    return HighlightedCard(
      isHighlighted: intro,
      minHeight: 100,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.bold,
            color: intro ? AppColors.btnBlue : AppColors.textGray,
          ),
        ),
      ),
    );
  }
}
