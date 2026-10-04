import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../state/practice_plan.dart';
import '../state/reminders.dart';
import '../state/settings.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/drill_card.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import 'configure_plan_entry_screen.dart';
import 'daily_practice_screen.dart';
import 'practice_log_screen.dart';
import 'reminder_config_screen.dart';
import 'select_drill_for_plan_screen.dart';

/// The user's practice plan: a START! button to run through it (see [DailyPracticeScreen]), the
/// drills in it as cards (drag the handle to reorder, tap to edit -- deleting an entry happens from
/// the edit screen, not here), a button to add another drill, and the user's daily reminders.
class PracticePlanScreen extends StatelessWidget {
  const PracticePlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    return CreamScreen(
      title: 'Daily Practice',
      actions: [
        RoundIconButton(
          icon: Icons.history_rounded,
          tooltip: 'Practice log',
          onPressed: () => push(const PracticeLogScreen()),
        ),
      ],
      child: ListenableBuilder(
        listenable: Listenable.merge([practicePlan, reminders, settings]),
        builder: (context, _) {
          final entries = practicePlan.entries;
          final reminderEntries = reminders.entries;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (entries.isNotEmpty) ...[
                      StartButton(
                        time: formatDrillClock(_totalSeconds(entries)),
                        onPressed: () => push(const DailyPracticeScreen()),
                      ),
                      const SizedBox(height: 22),
                    ],
                    const _Heading('Drills', AppColors.bannerOrange),
                    if (entries.isEmpty)
                      const _EmptyCard('No drills in your plan yet. Add one to get started!')
                    else
                      _PlanList(entries: entries),
                    const SizedBox(height: 14),
                    CandyButton(
                      label: 'ADD DRILL',
                      icon: Icons.add_rounded,
                      colors: AppColors.candyBlue,
                      height: 50,
                      fontSize: 17,
                      onPressed: () => push(const SelectDrillForPlanScreen()),
                    ),
                    const SizedBox(height: 30),
                    const _Heading('Reminders', AppColors.bannerMagenta),
                    if (reminderEntries.isEmpty)
                      const _EmptyCard('No reminders set up yet.')
                    else
                      for (var i = 0; i < reminderEntries.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _ReminderCard(
                          reminder: reminderEntries[i],
                          onTap: () => push(
                            ReminderConfigScreen(initialReminder: reminderEntries[i], editIndex: i),
                          ),
                        ),
                      ],
                    const SizedBox(height: 14),
                    CandyButton(
                      label: 'ADD REMINDER',
                      icon: Icons.add_alarm_rounded,
                      colors: AppColors.candyPink,
                      height: 50,
                      fontSize: 17,
                      onPressed: () => push(const ReminderConfigScreen()),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static double _totalSeconds(List<PracticePlanEntry> entries) {
    var total = 0.0;
    for (final entry in entries) {
      final drill = data.findDrillById(entry.drillId);
      if (drill == null) continue;
      total += computeDrillDuration(
        drill,
        entry.config.bpm,
        entry.config.bpmIncrease,
        entry.config.drillRepeat,
        replayIntroOnBpmIncrease: settings.replayIntroOnBpmIncrease,
      );
    }
    return total;
  }
}

/// The plan's drills as cards, reorderable by dragging their handles.
class _PlanList extends StatelessWidget {
  final List<PracticePlanEntry> entries;

  const _PlanList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // The default drag handle only shows up on desktop platforms -- on iOS/Android there'd be no
      // visible affordance at all (just an undiscoverable long-press-anywhere gesture). An explicit
      // handle works the same, visibly, everywhere.
      buildDefaultDragHandles: false,
      // Keep the card looking like itself (rather than gaining a Material elevation shadow) while
      // it's being dragged.
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        child: ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.03).animate(animation),
          child: child,
        ),
      ),
      itemCount: entries.length,
      onReorderItem: practicePlan.reorder,
      itemBuilder: (context, i) {
        final entry = entries[i];
        final drill = data.findDrillById(entry.drillId);
        final title = drill?.title ?? entry.drillId;
        return Padding(
          key: ObjectKey(entry),
          padding: EdgeInsets.only(bottom: i == entries.length - 1 ? 0 : 12),
          child: drill == null
              ? _EmptyCard('"$title" is no longer available.')
              : SizedBox(
                  height: 146,
                  child: DrillCard(
                    number: i + 1,
                    drill: drill,
                    config: entry.config,
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Tooltip(
                        message: 'Drag to reorder',
                        child: Icon(Icons.drag_indicator_rounded, color: AppColors.inkMuted),
                      ),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ConfigurePlanEntryScreen(
                          drillId: entry.drillId,
                          drillTitle: title,
                          initialConfig: entry.config,
                          editIndex: i,
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// A section heading: a banner on its own.
class _Heading extends StatelessWidget {
  final String label;
  final Color color;

  const _Heading(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        header: true,
        child: Align(
          alignment: Alignment.centerLeft,
          child: HudBanner(
            label: label,
            color: color,
            fontSize: 14,
            borderRadius: BorderRadius.circular(10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      ),
    );
  }
}

/// A white card with a message in it, standing in for an empty list.
class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamShadow, width: 2),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

/// A reminder as a card: its time in digit tiles, which days of the week it's on, and its message.
/// Tapping it edits it.
class _ReminderCard extends StatelessWidget {
  final ReminderConfig reminder;
  final VoidCallback onTap;

  const _ReminderCard({required this.reminder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final formatted = MaterialLocalizations.of(context).formatTimeOfDay(
      reminder.timeOfDay,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    // E.g. "7:30" and "AM", so that just the numbers go in digit tiles.
    final match = RegExp(r'^([\d:]+)\s*(.*)$').firstMatch(formatted);
    final time = match?.group(1) ?? formatted;
    final suffix = match?.group(2) ?? '';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.creamShadow, width: 3)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        DigitTiles(value: time, height: 30),
                        if (suffix.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Text(
                            suffix,
                            style: const TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    _DaysRow(days: reminder.days),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    reminder.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The days of the week, Monday first, as letters in little circles: filled in for the [days] a
/// reminder is on.
class _DaysRow extends StatelessWidget {
  final Set<int> days;

  const _DaysRow({required this.days});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: [
        for (final d in allWeekdays)
          if (days.contains(d)) weekdayAbbreviation(d),
      ].join(', '),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in allWeekdays)
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: days.contains(d) ? AppColors.bannerMagenta : null,
                border: days.contains(d)
                    ? null
                    : Border.all(color: AppColors.creamShadow, width: 1.5),
              ),
              child: Text(
                weekdayAbbreviation(d)[0],
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: days.contains(d) ? Colors.white : AppColors.inkMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
