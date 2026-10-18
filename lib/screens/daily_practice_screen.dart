import 'package:flutter/material.dart';

import '../state/playlists.dart';
import '../state/reminders.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';
import 'practice_log_screen.dart';
import 'reminder_config_screen.dart';

/// Daily practice: the user's practice reminders (tap one to edit it, or add another), and a button
/// up top for their practice history (see [PracticeLogScreen]). The practicing itself happens
/// elsewhere -- a reminder linked to a playlist opens it when its notification is tapped.
class DailyPracticeScreen extends StatelessWidget {
  const DailyPracticeScreen({super.key});

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
        listenable: Listenable.merge([reminders, playlists]),
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
