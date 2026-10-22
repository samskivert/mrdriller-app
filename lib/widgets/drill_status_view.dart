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

/// Shows a running drill's BPM and which repeat of the drill this is, as the game's HUD readouts
/// in digit tiles. (The playfield's depth ruler shows overall progress.) [vertical] stacks them in
/// big cards (for a sidebar, readable from a drum across the room) instead of side by side (for a
/// HUD across the top of the screen).
class DrillStatusView extends StatelessWidget {
  final DrillRunStatus status;
  final bool vertical;
  // What the drill's repeats are called, e.g. a pattern trainer's patterns.
  final String loopLabel;

  const DrillStatusView({
    super.key,
    required this.status,
    this.vertical = false,
    this.loopLabel = 'Loop',
  });

  @override
  Widget build(BuildContext context) {
    final bpm = '${status.bpm}';
    final loop = '${status.drillRepeatCount + 1}/${status.drillRepeat}';
    final increase = status.bpmIncrease > 0 && status.drillRepeat > 1
        ? '+${status.bpmIncrease} each loop'
        : null;

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bigCard('BPM', AppColors.bannerOrange, bpm, increase),
          const SizedBox(height: 10),
          _bigCard(loopLabel, AppColors.bannerRed, loop, null),
        ],
      );
    }

    // Each card at its natural width, the pair centered, and all shrunk to fit if too wide (e.g. a
    // long loop count on a small phone).
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _wideCard('BPM', AppColors.bannerOrange, bpm, increase),
            const SizedBox(width: 10),
            _wideCard(loopLabel, AppColors.bannerRed, loop, null),
          ],
        ),
      ),
    );
  }

  static final _cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 3))],
  );

  // A HUD readout: a white card with its banner tab in the top-left corner and [sub] (if any)
  // under it, and [value] in digit tiles on the right, centered top to bottom.
  Widget _wideCard(String label, Color color, String value, String? sub) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: _cardDecoration,
    child: IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HudBanner(label: label, color: color),
              if (sub != null)
                Padding(padding: const EdgeInsets.fromLTRB(10, 8, 0, 10), child: _sub(sub)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Center(child: DigitTiles(value: value)),
          ),
        ],
      ),
    ),
  );

  // A sidebar readout: a white card with its banner tab in the top-left corner and [value] in big right-aligned digit tiles below, readable from across the room.
  Widget _bigCard(String label, Color color, String value, String? sub) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: _cardDecoration,
    child: Column(
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
                alignment: Alignment.centerRight,
                child: DigitTiles(value: value, height: 72),
              ),
              if (sub != null) ...[
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: _sub(sub, fontSize: 20)),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sub(String text, {double fontSize = 11}) => Text(
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
