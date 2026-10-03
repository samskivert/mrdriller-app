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

  /// The time left in the drill, as e.g. "1:42".
  String get remainingLabel {
    final remaining = (totalSeconds - elapsedSeconds).clamp(0, double.infinity).ceil();
    return '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}';
  }
}

/// Shows a running drill's progress as the game's HUD readouts: BPM in digit tiles, which repeat
/// of the drill this is, and the AIR gauge draining as the drill's time runs out. [vertical]
/// stacks them in one card as rows (for a sidebar) instead of side by side as separate cards (for
/// a HUD across the top of the screen).
class DrillStatusView extends StatelessWidget {
  final DrillRunStatus status;
  final bool vertical;

  const DrillStatusView({super.key, required this.status, this.vertical = false});

  @override
  Widget build(BuildContext context) {
    final bpm = '${status.bpm}';
    final bpmTiles = DigitTiles(value: bpm, pips: (3 - bpm.length).clamp(0, 3));
    final loop = '${status.drillRepeatCount + 1}/${status.drillRepeat}';
    final increase = status.bpmIncrease > 0 && status.drillRepeat > 1
        ? '+${status.bpmIncrease} each loop'
        : null;

    if (vertical) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 3))],
        ),
        child: Column(
          children: [
            _row('BPM', AppColors.bannerOrange, DigitTiles(value: bpm, height: 30)),
            if (increase != null) Align(alignment: Alignment.centerRight, child: _sub(increase)),
            const SizedBox(height: 8),
            _row('Loop', AppColors.bannerRed, DigitTiles(value: loop, height: 30)),
            const SizedBox(height: 8),
            _row(
              'Air',
              AppColors.bannerMagenta,
              AirGauge(fraction: 1 - status.progress, label: status.remainingLabel, size: 56),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: HudCard(
            label: 'BPM',
            bannerColor: AppColors.bannerOrange,
            height: 104,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                bpmTiles,
                if (increase != null) ...[const SizedBox(height: 8), _sub(increase)],
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: HudCard(
            label: 'Loop',
            bannerColor: AppColors.bannerRed,
            height: 104,
            child: DigitTiles(value: loop),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: HudCard(
            label: 'Air',
            bannerColor: AppColors.bannerMagenta,
            height: 104,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AirGauge(fraction: 1 - status.progress, label: status.remainingLabel),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, Color color, Widget value) => Row(
    children: [
      SizedBox(
        width: 64,
        child: HudBanner(
          label: label,
          color: color,
          borderRadius: BorderRadius.circular(9),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        ),
      ),
      const Spacer(),
      value,
    ],
  );

  Widget _sub(String text) => Text(
    text,
    style: const TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 11,
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
