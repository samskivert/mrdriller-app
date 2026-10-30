import 'package:flutter/material.dart';

import '../services/metronome.dart';
import '../util/colors.dart';
import 'arcade.dart';

/// A snapshot of a running drill's live progress, for display in [DrillStatusView].
class DrillRunStatus {
  final int bpm;
  final int bpmIncrease;
  final int drillRepeat;
  final int drillRepeatCount;
  final double elapsedSeconds;
  final double totalSeconds;

  const DrillRunStatus({
    required this.bpm,
    required this.bpmIncrease,
    required this.drillRepeat,
    required this.drillRepeatCount,
    required this.elapsedSeconds,
    required this.totalSeconds,
  });

  /// How far through the whole drill (every repeat, count-ins included) this is, from 0 to 1.
  double get progress => totalSeconds > 0 ? (elapsedSeconds / totalSeconds).clamp(0, 1) : 0;
}

/// Another readout to show alongside a running drill's BPM and loop, e.g. a playlist's DRILL n/N.
typedef ExtraReadout = ({String label, Color color, String value});

/// Shows a running drill's BPM and which repeat of the drill this is (and [extra], if any), as the
/// game's HUD readouts in digit tiles. (The playfield's depth ruler shows overall progress.)
/// [vertical] stacks them in big cards (for a sidebar, readable from a drum across the room)
/// instead of side by side (for a HUD across the top of the screen).
class DrillStatusView extends StatelessWidget {
  final DrillRunStatus status;
  final bool vertical;
  // What the drill's repeats are called, e.g. a pattern trainer's patterns.
  final String loopLabel;
  final ExtraReadout? extra;

  const DrillStatusView({
    super.key,
    required this.status,
    this.vertical = false,
    this.loopLabel = 'Loop',
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final bpm = '${status.bpm}';
    final loop = '${status.drillRepeatCount + 1}/${status.drillRepeat}';
    final increase = status.bpmIncrease > 0 && status.drillRepeat > 1
        ? '+${status.bpmIncrease} each loop'
        : null;
    // Two fit side by side in their wide style, but a third needs them all stacked.
    final style = vertical
        ? ReadoutStyle.big
        : (extra == null ? ReadoutStyle.wide : ReadoutStyle.stacked);
    final cards = [
      ReadoutCard(
        label: 'BPM',
        color: AppColors.bannerOrange,
        value: bpm,
        sub: increase,
        style: style,
      ),
      ReadoutCard(label: loopLabel, color: AppColors.bannerRed, value: loop, style: style),
      if (extra case final extra?)
        ReadoutCard(label: extra.label, color: extra.color, value: extra.value, style: style),
    ];

    switch (style) {
      case ReadoutStyle.big:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, card) in cards.indexed) ...[if (i > 0) const SizedBox(height: 10), card],
          ],
        );
      case ReadoutStyle.wide:
        // Each card at its natural width, the pair centered, and all shrunk to fit if too wide
        // (e.g. a long loop count on a small phone).
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [cards[0], const SizedBox(width: 10), cards[1]],
            ),
          ),
        );
      case ReadoutStyle.stacked:
        // Sharing the width equally, all as tall as the tallest.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, card) in cards.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: card),
              ],
            ],
          ),
        );
    }
  }
}

/// How a [ReadoutCard] is laid out: [wide] (its value right of its banner), [stacked] (its value
/// centered below its banner), both for the portrait HUD, or [big] (for a sidebar).
enum ReadoutStyle { wide, stacked, big }

/// A HUD readout: a white card with its [label] banner tab in the top-left corner, and [value] in
/// digit tiles (and [sub], if any, as a note), laid out according to [style]:
/// - [ReadoutStyle.wide]: [sub] under the banner, and [value] on the right, centered top to
///   bottom.
/// - [ReadoutStyle.stacked]: [value] centered below the banner, and [sub] under it.
/// - [ReadoutStyle.big]: [value] in big right-aligned tiles below the banner, and [sub] under it,
///   readable from across the room.
class ReadoutCard extends StatelessWidget {
  final String label;
  final Color color;
  final String value;
  final String? sub;
  final ReadoutStyle style;

  const ReadoutCard({
    super.key,
    required this.label,
    required this.color,
    required this.value,
    this.sub,
    this.style = ReadoutStyle.wide,
  });

  static final _decoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 3))],
  );

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: _decoration,
    child: switch (style) {
      ReadoutStyle.wide => _wide(),
      ReadoutStyle.stacked => _below(height: 32, align: Alignment.center, subSize: 11),
      ReadoutStyle.big => _below(height: 72, align: Alignment.centerRight, subSize: 20),
    },
  );

  Widget _wide() => IntrinsicHeight(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HudBanner(label: label, color: color),
            if (sub case final sub?)
              Padding(padding: const EdgeInsets.fromLTRB(10, 8, 0, 10), child: _sub(sub, 11)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Center(child: DigitTiles(value: value)),
        ),
      ],
    ),
  );

  // The value (and sub) below the banner, aligned by [align].
  Widget _below({required double height, required Alignment align, required double subSize}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: HudBanner(label: label, color: color),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: align,
                  child: DigitTiles(value: value, height: height),
                ),
                if (sub case final sub?) ...[
                  SizedBox(height: subSize * 0.3),
                  Align(alignment: align, child: _sub(sub, subSize)),
                ],
              ],
            ),
          ),
        ],
      );

  Widget _sub(String text, double fontSize) => Text(
    text,
    style: TextStyle(
      fontFamily: AppFonts.body,
      fontSize: fontSize,
      height: 1,
      fontWeight: FontWeight.w800,
      color: AppColors.inkMuted,
    ),
  );
}

/// The candy Pause/Resume button for a running drill, driven directly by [metronome] -- it reacts
/// to [metronome]'s own notifications, so it always reflects whether the metronome is actually
/// paused without the caller needing to track that separately. Icon-only by default (e.g. sharing
/// a row with the back button and title); [showLabel] adds PAUSE/RESUME text, for when it gets a
/// wide row of its own.
class PauseButton extends StatelessWidget {
  final Metronome metronome;
  final bool showLabel;

  const PauseButton({super.key, required this.metronome, this.showLabel = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: metronome,
      builder: (context, _) {
        final paused = metronome.isPaused;
        return CandyButton(
          label: showLabel ? (paused ? 'RESUME' : 'PAUSE') : null,
          tooltip: showLabel ? null : (paused ? 'Resume' : 'Pause'),
          icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          colors: paused ? AppColors.candyGreen : AppColors.candyPink,
          onPressed: paused ? metronome.resume : metronome.pause,
        );
      },
    );
  }
}
