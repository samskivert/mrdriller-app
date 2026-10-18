import 'package:flutter/material.dart';

import '../state/playlists.dart';
import '../state/practice_log.dart';
import '../state/reminders.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import 'practice_log_screen.dart';
import 'reminder_config_screen.dart';

/// Daily practice: a summary of this week's practice, with a button through to the full practice
/// log (see [PracticeLogScreen]), and the user's practice reminders (tap one to edit it, or add
/// another). The practicing itself happens elsewhere -- a reminder linked to a playlist opens it
/// when its notification is tapped.
class DailyPracticeScreen extends StatelessWidget {
  /// For tests: what counts as "now" (and so today), instead of the real time.
  final DateTime? now;

  const DailyPracticeScreen({super.key, this.now});

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    return CreamScreen(
      title: 'Daily Practice',
      child: ListenableBuilder(
        listenable: Listenable.merge([reminders, playlists, practiceLog]),
        builder: (context, _) {
          final reminderEntries = reminders.entries;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeading('This Week', AppColors.bannerGreen),
                    _ThisWeekCard(today: practiceDay(now ?? DateTime.now())),
                    const SizedBox(height: 14),
                    CandyButton(
                      label: 'PRACTICE LOG',
                      icon: Icons.history_rounded,
                      colors: AppColors.candyGreen,
                      height: 50,
                      fontSize: 17,
                      onPressed: () => push(PracticeLogScreen(now: now)),
                    ),
                    const SizedBox(height: 30),
                    const SectionHeading('Reminders', AppColors.bannerMagenta),
                    if (reminderEntries.isEmpty)
                      const EmptyCard(
                        'No reminders set up yet. Add one to get a nudge to practice, which can '
                        'open one of your playlists.',
                      )
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
}

/// This week's practice (Monday to Sunday): which days had any, and the current streak, how many
/// drills, and how long.
class _ThisWeekCard extends StatelessWidget {
  final DateTime today;

  const _ThisWeekCard({required this.today});

  static const _weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final entries = practiceLog.entries;
    final practiced = {for (final e in entries) practiceDay(e.completedAt)};
    final thisWeek = [
      for (final e in entries)
        if (!practiceDay(e.completedAt).isBefore(monday)) e,
    ];
    final streak = practiceStreak(practiced, today);
    const label = TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 11,
      height: 1,
      fontWeight: FontWeight.w900,
      color: AppColors.inkMuted,
    );
    Widget stat(String name, String value) => Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: DigitTiles(value: value, height: 30),
          ),
          const SizedBox(height: 6),
          Text(name, style: label.copyWith(letterSpacing: 1.2)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 6.0;
              final cell = ((constraints.maxWidth - gap * 6) / 7).clamp(20.0, 44.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var d = 0; d < 7; d++)
                    Padding(
                      padding: EdgeInsets.only(left: d == 0 ? 0 : gap),
                      child: Column(
                        children: [
                          ExcludeSemantics(child: Text(_weekdayInitials[d], style: label)),
                          const SizedBox(height: 6),
                          PracticeDayCell(
                            day: DateTime(monday.year, monday.month, monday.day + d),
                            today: today,
                            practiced: practiced,
                            size: cell,
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('STREAK', '$streak'),
              stat('DRILLS', '${thisWeek.length}'),
              stat('TIME', formatPracticeTotal(thisWeek.fold(0, (sum, e) => sum + e.seconds))),
            ],
          ),
        ],
      ),
    );
  }
}

/// A reminder as a card: its time in digit tiles, which days of the week it's on, its message, and
/// the playlist it opens (if any). Tapping it edits it.
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
    final playlistId = reminder.playlistId;
    final playlist = playlistId == null ? null : playlists.byId(playlistId);
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
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
                      if (playlist != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.queue_music_rounded,
                              size: 16,
                              color: AppColors.bannerOrange,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                playlist.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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
