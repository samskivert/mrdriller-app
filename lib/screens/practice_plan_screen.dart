import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../state/drill_config.dart';
import '../state/practice_plan.dart';
import '../state/reminders.dart';
import '../state/settings.dart';
import '../util/colors.dart';
import '../widgets/components.dart';
import '../widgets/screen_scaffold.dart';
import 'configure_plan_entry_screen.dart';
import 'daily_practice_screen.dart';
import 'practice_log_screen.dart';
import 'reminder_config_screen.dart';
import 'select_drill_for_plan_screen.dart';

/// Lists the drills in the user's practice plan (drag the handle to reorder), each with an Edit
/// action -- deleting an entry happens from the edit screen, not here -- plus a button to add
/// another drill. Creation and editing only for now -- actually running the plan is a follow-up
/// feature.
class PracticePlanScreen extends StatelessWidget {
  const PracticePlanScreen({super.key});

  String _titleFor(String drillId) => data.findDrillById(drillId)?.title ?? drillId;

  String? _durationFor(PracticePlanEntry entry) {
    final drill = data.findDrillById(entry.drillId);
    if (drill == null) return null;
    return formatDrillDuration(
      computeDrillDuration(
        drill,
        entry.config.bpm,
        entry.config.bpmIncrease,
        entry.config.drillRepeat,
        replayIntroOnBpmIncrease: settings.replayIntroOnBpmIncrease,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Daily Practice',
      contentMaxWidth: 512,
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PracticeLogScreen())),
            icon: const Icon(Icons.history),
            tooltip: 'Practice Log',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: practicePlan,
        builder: (context, _) {
          final entries = practicePlan.entries;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (entries.isNotEmpty) ...[
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const DailyPracticeScreen())),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.btnGreen,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Practice'),
                ),
                const SizedBox(height: 16),
              ],
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'No drills in your plan yet. Add one to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  // The default drag handle only shows up on desktop platforms --
                  // on iOS/Android there'd be no visible affordance at all (just an
                  // undiscoverable long-press-anywhere gesture). An explicit handle
                  // works the same, visibly, everywhere.
                  buildDefaultDragHandles: false,
                  itemCount: entries.length,
                  onReorderItem: practicePlan.reorder,
                  itemBuilder: (context, i) {
                    final entry = entries[i];
                    return Padding(
                      key: ObjectKey(entry),
                      padding: EdgeInsets.only(bottom: i == entries.length - 1 ? 0 : 12),
                      child: _PlanEntryTile(
                        title: _titleFor(entry.drillId),
                        config: entry.config,
                        duration: _durationFor(entry),
                        dragHandle: ReorderableDragStartListener(
                          index: i,
                          child: Icon(Icons.drag_handle, color: AppColors.textGray),
                        ),
                        onEdit: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ConfigurePlanEntryScreen(
                              drillId: entry.drillId,
                              drillTitle: _titleFor(entry.drillId),
                              initialConfig: entry.config,
                              editIndex: i,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SelectDrillForPlanScreen())),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.btnBlue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Drill'),
              ),
              const SizedBox(height: 32),
              const Text(
                'Daily Reminders',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: reminders,
                builder: (context, _) {
                  final reminderEntries = reminders.entries;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (reminderEntries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No reminders set up yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black.withValues(alpha: 0.5)),
                          ),
                        )
                      else
                        for (var i = 0; i < reminderEntries.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _ReminderTile(
                            reminder: reminderEntries[i],
                            onEdit: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReminderConfigScreen(
                                  initialReminder: reminderEntries[i],
                                  editIndex: i,
                                ),
                              ),
                            ),
                          ),
                        ],
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const ReminderConfigScreen())),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: AppColors.btnBlue,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_alarm),
                        label: const Text('Add Reminder'),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanEntryTile extends StatelessWidget {
  final String title;
  final DrillConfig config;
  final String? duration;
  final Widget dragHandle;
  final VoidCallback onEdit;

  const _PlanEntryTile({
    required this.title,
    required this.config,
    required this.duration,
    required this.dragHandle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return HighlightedCard(
      isHighlighted: false,
      child: Row(
        children: [
          dragHandle,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  '${formatBpmSummary(config.bpm, config.bpmIncrease)} · x${config.drillRepeat}'
                  '${config.swapHands ? ' · R↔︎L' : ''}'
                  '${duration != null ? ' · $duration' : ''}',
                  style: TextStyle(color: AppColors.textGray, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), tooltip: 'Edit'),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final ReminderConfig reminder;
  final VoidCallback onEdit;

  const _ReminderTile({required this.reminder, required this.onEdit});

  String get _daysSummary {
    final days = reminder.days;
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && days.containsAll(const [1, 2, 3, 4, 5])) return 'Weekdays';
    if (days.length == 2 && days.containsAll(const [6, 7])) return 'Weekends';
    return [
      for (final d in allWeekdays)
        if (days.contains(d)) weekdayAbbreviation(d),
    ].join(', ');
  }

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
                  '${reminder.timeOfDay.format(context)} · $_daysSummary',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  reminder.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textGray, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), tooltip: 'Edit'),
        ],
      ),
    );
  }
}
