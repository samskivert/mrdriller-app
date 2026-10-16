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

// The ranges a drill's bpm/bpm-increase/repeat-count can be configured within, defined once so
// that the screens configuring them can't drift out of sync.
const bpmLimits = (min: 30, max: maxBpm);
const bpmIncreaseLimits = (min: 0, max: 50);
const drillRepeatLimits = (min: 1, max: 10);

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
    this.color = AppColors.inkMuted,
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

/// The count-in, overlaid on the playfield: what's behind it stays visible through a translucent
/// navy scrim, so you can see what's coming while it counts you in. Shows [heading] (e.g. GET
/// READY) on a cream pill, the [CountIn] at [index], and [details] (e.g. the bpm) below.
class CountInOverlay extends StatelessWidget {
  final int index;
  final String heading;
  final String details;

  const CountInOverlay({
    super.key,
    required this.index,
    required this.heading,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xC7090E20),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Text(
                    heading,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 20,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 3.4,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                CountIn(index: index, size: 104),
                const SizedBox(height: 22),
                Text(
                  details,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: AppColors.cream,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
