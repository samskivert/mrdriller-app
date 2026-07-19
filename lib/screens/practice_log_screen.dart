import 'package:flutter/material.dart';

import '../model/model.dart';
import '../state/practice_log.dart';
import '../util/colors.dart';
import '../widgets/components.dart';
import '../widgets/screen_scaffold.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final month = _monthNames[local.month - 1];
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$month ${local.day}, ${local.year} · $hour12:$minute $period';
}

/// Lists every completed daily practice session (see daily_practice_screen.dart), most recent
/// first.
class PracticeLogScreen extends StatelessWidget {
  const PracticeLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Practice Log',
      showSettings: false,
      contentMaxWidth: 512,
      child: AnimatedBuilder(
        animation: practiceLog,
        builder: (context, _) {
          final entries = practiceLog.entries;
          if (entries.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'No completed practice sessions yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _LogEntryTile(entry: entries[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  final PracticeLogEntry entry;

  const _LogEntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return HighlightedCard(
      isHighlighted: false,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateTime(entry.completedAt),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.drillCount} drill${entry.drillCount == 1 ? '' : 's'} · '
                  '${formatDrillDuration(entry.totalSeconds.toDouble())}',
                  style: TextStyle(color: AppColors.textGray, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
