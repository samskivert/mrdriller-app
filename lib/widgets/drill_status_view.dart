import 'package:flutter/material.dart';

import '../model/model.dart';
import '../services/metronome.dart';
import '../util/colors.dart';

/// A snapshot of a running drill's live bpm/repeat progress, for display in [DrillStatusView].
class DrillRunStatus {
  final int bpm;
  final int bpmIncrease;
  final int drillRepeat;
  final int drillRepeatCount;

  const DrillRunStatus({
    required this.bpm,
    required this.bpmIncrease,
    required this.drillRepeat,
    required this.drillRepeatCount,
  });
}

/// Shows a running drill's bpm/repeat progress plus a Pause/Resume button driven directly by
/// [metronome] -- reacts to [metronome]'s own notifications, so it always reflects whether the
/// metronome is actually paused without the caller needing to track that separately. [compact]
/// shrinks the text/button for use inline in a header (e.g. on a short landscape phone) instead of
/// its own full-size row.
class DrillStatusView extends StatelessWidget {
  final DrillRunStatus status;
  final Metronome metronome;
  final bool compact;

  const DrillStatusView({
    super.key,
    required this.status,
    required this.metronome,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: metronome,
      builder: (context, _) {
        final paused = metronome.isPaused;
        final textStyle = TextStyle(
          fontSize: compact ? 16 : 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textGray,
        );
        final button = ElevatedButton(
          onPressed: paused ? metronome.resume : metronome.pause,
          style: ElevatedButton.styleFrom(
            backgroundColor: paused ? AppColors.btnGreen : AppColors.btnGray,
            foregroundColor: Colors.white,
            padding: compact ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4) : null,
            minimumSize: compact ? Size.zero : null,
            tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
          ),
          child: Text(paused ? 'Resume' : 'Pause'),
        );
        final bpmText = Text(formatBpmSummary(status.bpm, status.bpmIncrease), style: textStyle);
        final repeatText = status.drillRepeat > 1
            ? Text('${status.drillRepeatCount + 1} / ${status.drillRepeat}', style: textStyle)
            : null;

        if (compact) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              bpmText,
              if (repeatText != null) ...[const SizedBox(width: 12), repeatText],
              const SizedBox(width: 12),
              button,
            ],
          );
        }
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [bpmText, ?repeatText, button],
        );
      },
    );
  }
}
