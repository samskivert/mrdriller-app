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
            border: Border.all(color: Colors.black.withValues(alpha: 0.10), width: 2),
          ),
        ),
      ),
    );
  }
}

/// A card whose border/background flips to a highlighted (yellow, blue outline) style when
/// active, used for the currently-playing section and the countdown/status cards.
class HighlightedCard extends StatelessWidget {
  final Widget child;
  final bool isHighlighted;
  final double? minHeight;

  const HighlightedCard({super.key, required this.child, required this.isHighlighted, this.minHeight});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
      padding: const EdgeInsets.all(12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.highlightBg : AppColors.normalBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isHighlighted ? AppColors.highlightBorder : AppColors.normalBorder,
            width: isHighlighted ? 3 : 2),
        boxShadow: isHighlighted
            ? [BoxShadow(color: AppColors.highlightShadow, spreadRadius: 3, blurRadius: 0)]
            : null,
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
          children: [for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 16), child: c)],
        ),
      ),
    );
  }
}

/// A labeled numeric stepper input (BPM, BPM increase, repeat count, etc).
class NumberInputField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final double width;

  const NumberInputField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.width = 60,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: '$value');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        SizedBox(
          width: width,
          height: 32,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onSubmitted: (text) => onChanged(int.tryParse(text)?.clamp(min, max) ?? min),
            onChanged: (text) {
              final n = int.tryParse(text);
              if (n != null) onChanged(n.clamp(min, max));
            },
          ),
        ),
      ],
    );
  }
}

/// Section label on the left, repeat-dot display on the right.
class SectionHeader extends StatelessWidget {
  final String? label;
  final String? repeatDisplay;
  final double labelFontSize;
  final double repeatFontSize;

  const SectionHeader({
    super.key,
    this.label,
    this.repeatDisplay,
    this.labelFontSize = 14,
    this.repeatFontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    if ((label == null || label!.isEmpty) && (repeatDisplay == null || repeatDisplay!.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (label != null && label!.isNotEmpty)
          Text(label!, style: TextStyle(fontSize: labelFontSize, fontWeight: FontWeight.bold)),
        if (repeatDisplay != null && repeatDisplay!.isNotEmpty)
          Text(
            repeatDisplay!,
            style: TextStyle(fontSize: repeatFontSize, fontWeight: FontWeight.bold, color: AppColors.textGray),
          ),
      ],
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
        : (measureIndex >= introText.length ? introText.last : introText[measureIndex]);
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
