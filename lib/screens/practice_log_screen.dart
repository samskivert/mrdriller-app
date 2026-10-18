import 'package:flutter/material.dart';

import '../data/drills.dart' as data;
import '../model/model.dart';
import '../state/practice_log.dart';
import '../util/colors.dart';
import '../widgets/arcade.dart';
import '../widgets/hud_controls.dart';
import '../widgets/hud_layout.dart';

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

const _weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

// A local calendar day (no time of day), for comparing which days drills were practiced on.
DateTime _day(DateTime dateTime) {
  final local = dateTime.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// The user's practice record: a summary (current streak, number of drills completed, total time),
/// a calendar of which days they've practiced over the last few weeks, and the drills completed on
/// each day, most recent first.
class PracticeLogScreen extends StatelessWidget {
  /// For tests: what counts as "now" (and so today), instead of the real time.
  final DateTime? now;

  const PracticeLogScreen({super.key, this.now});

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return CreamScreen(
      title: 'Practice Log',
      showSettings: false,
      child: ListenableBuilder(
        listenable: practiceLog,
        builder: (context, _) {
          final entries = [...practiceLog.entries]
            ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
          final today = _day(now ?? DateTime.now());
          final practiced = {for (final e in entries) _day(e.completedAt)};
          // Each day's drills, in the order completed (most recent day first).
          final days = <DateTime, List<PracticeLogEntry>>{};
          for (final e in entries.reversed) {
            days.putIfAbsent(_day(e.completedAt), () => []).add(e);
          }
          final dayList = days.entries.toList().reversed.toList();
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(safe.left + 16, 8, safe.right + 16, safe.bottom + 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (entries.isEmpty)
                      const _EmptyCard()
                    else ...[
                      _StatsCard(
                        streak: _streak(practiced, today),
                        drills: entries.length,
                        totalSeconds: entries.fold(0, (sum, e) => sum + e.seconds),
                      ),
                      const SizedBox(height: 14),
                      _CalendarCard(practiced: practiced, today: today),
                      const SizedBox(height: 22),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: HudBanner(
                          label: 'History',
                          color: AppColors.bannerOrange,
                          fontSize: 14,
                          borderRadius: BorderRadius.circular(10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (var i = 0; i < dayList.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _DayCard(day: dayList[i].key, entries: dayList[i].value),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // How many days in a row, up to today, have had practice. A streak that's still alive (practice
  // yesterday, but not yet today) counts too.
  static int _streak(Set<DateTime> practiced, DateTime today) {
    var day = practiced.contains(today) ? today : today.subtract(const Duration(days: 1));
    var streak = 0;
    while (practiced.contains(day)) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamShadow, width: 2),
      ),
      child: const Text(
        'No practice logged yet. Every drill you finish, on its own or in a playlist, will show '
        'up here!',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

/// The headline numbers: the current streak, how many drills, and how long, all told.
class _StatsCard extends StatelessWidget {
  final int streak;
  final int drills;
  final int totalSeconds;

  const _StatsCard({required this.streak, required this.drills, required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    final minutes = (totalSeconds / 60).round();
    final total = minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h${minutes % 60}m';
    Widget row(String label, Color color, String value, String unit) => Row(
      children: [
        SizedBox(
          width: 100,
          child: HudBanner(
            label: label,
            color: color,
            fontSize: 13,
            borderRadius: BorderRadius.circular(10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const Spacer(),
        Flexible(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                DigitTiles(value: value, height: 32),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    unit,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          row('Streak', AppColors.bannerRed, '$streak', streak == 1 ? 'day' : 'days'),
          const SizedBox(height: 10),
          row('Drills', AppColors.bannerBlue, '$drills', ''),
          const SizedBox(height: 10),
          row('Total', AppColors.bannerMagenta, total, ''),
        ],
      ),
    );
  }
}

/// The last five weeks, a row per week (Monday first): practiced days in candy green, and today
/// outlined in gold.
class _CalendarCard extends StatelessWidget {
  final Set<DateTime> practiced;
  final DateTime today;

  const _CalendarCard({required this.practiced, required this.today});

  static const _weeks = 5;

  @override
  Widget build(BuildContext context) {
    final thisMonday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final start = DateTime(thisMonday.year, thisMonday.month, thisMonday.day - 7 * (_weeks - 1));
    final green = AppColors.candyGreen;
    const label = TextStyle(
      fontFamily: AppFonts.body,
      fontSize: 11,
      height: 1,
      fontWeight: FontWeight.w900,
      color: AppColors.inkMuted,
    );
    return BannerCard(
      label: 'Last 5 weeks',
      color: AppColors.bannerGreen,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 6.0;
          final cell = ((constraints.maxWidth - gap * 6) / 7).clamp(20.0, 44.0);
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var d = 0; d < 7; d++)
                      Container(
                        width: cell,
                        margin: EdgeInsets.only(left: d == 0 ? 0 : gap),
                        alignment: Alignment.center,
                        child: Text(_weekdayNames[d][0], style: label),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                for (var w = 0; w < _weeks; w++)
                  Padding(
                    padding: EdgeInsets.only(top: w == 0 ? 0 : gap),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var d = 0; d < 7; d++)
                          Builder(
                            builder: (context) {
                              final day = DateTime(start.year, start.month, start.day + w * 7 + d);
                              final done = practiced.contains(day);
                              final isToday = day == today;
                              final future = day.isAfter(today);
                              return Semantics(
                                label:
                                    '${_weekdayNames[d]} ${_monthNames[day.month - 1]} ${day.day}'
                                    '${done ? ', practiced' : ''}${isToday ? ', today' : ''}',
                                excludeSemantics: true,
                                child: Container(
                                  width: cell,
                                  height: cell,
                                  margin: EdgeInsets.only(left: d == 0 ? 0 : gap),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(cell * 0.28),
                                    gradient: done
                                        ? LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [green.hi, green.base, green.lo],
                                          )
                                        : null,
                                    color: done
                                        ? null
                                        : (future ? Colors.transparent : const Color(0xFFF3EEE2)),
                                    border: isToday
                                        ? Border.all(color: AppColors.gold, width: 3)
                                        : null,
                                    boxShadow: done
                                        ? [
                                            BoxShadow(
                                              color: green.outline,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: done
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: cell * 0.6,
                                          color: Colors.white,
                                        )
                                      : Text(
                                          '${day.day}',
                                          style: label.copyWith(
                                            color: AppColors.inkMuted.withValues(
                                              alpha: future ? 0.35 : 0.8,
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One day's practice: a calendar-page badge for its date, how many drills and how long, which
/// weekday, and a chip for each drill completed (in the order they were completed).
class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<PracticeLogEntry> entries;

  const _DayCard({required this.day, required this.entries});

  @override
  Widget build(BuildContext context) {
    final drills = entries.length == 1 ? '1 drill' : '${entries.length} drills';
    final seconds = entries.fold(0, (sum, e) => sum + e.seconds);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.creamShadow, offset: Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A little page off a calendar.
          Container(
            width: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.creamShadow, width: 2),
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.bannerRed,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  alignment: Alignment.center,
                  child: Text(
                    _monthNames[day.month - 1].toUpperCase(),
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 22,
                      height: 1.1,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$drills · ${formatDrillDuration(seconds.toDouble())}',
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_weekdayNames[day.weekday - 1]}, ${day.year}',
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in entries)
                      _DrillChip(
                        title: data.findDrillById(e.drillId)?.title ?? e.drillId,
                        bpm: e.config.bpm,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A completed drill: its title and the bpm it started at.
class _DrillChip extends StatelessWidget {
  final String title;
  final int bpm;

  const _DrillChip({required this.title, required this.bpm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.creamShadow, width: 1.5),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: title),
            TextSpan(
              text: ' · $bpm BPM',
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
